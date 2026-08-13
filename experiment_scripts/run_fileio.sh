#!/usr/bin/env bash
#
# From ttheexperiment_scirpts direcotry:
# sudo /run_fileio.sh <num_blocks> <num_invocations>
# sudo ./run_fileio.sh 500000 40
# Note that this may take a while to run, be patient.
#
set -u

BLOCKS=$1
N=$2

BENCH=fileio_${BLOCKS}
COOLDOWN=60
IDLE_SECS=40

ROOT=..
EB=$ROOT/EnergiBridge/target/release/energibridge
PROC=process_run.py
RES=$ROOT/results/$BENCH
CPUS=0,1,2,3,12,13,14,15

RAW=$RES/raw_data
PROCESSED=$RES/processed
FINAL=$RES/final

WASMTIME=io.containerd.wasmtime.v1
RUNC=io.containerd.runc.v2

# ctr needs an absoulte path for the direcotry source
# so we assume the foloder to write to is in the parent direcotry
# and already exists.
DISKBENCH=$(cd "$ROOT/diskbench" && pwd)
MOUNT="type=bind,src=$DISKBENCH,dst=/data,options=rbind:rw"
ARGS="$BLOCKS /data"

ALL_ARMS="p1-aot p2-jit runc p2-aot p1-jit"

mkdir -p "$RAW" "$PROCESSED" "$FINAL"

# Make sure there is no containers already rynning
leftover=$(ctr containers ls -q | wc -l)
if [ "$leftover" -ne 0 ]; then
  echo "error: $leftover container running. Remove these and try again"
  ctr containers ls
  exit 1
fi

# Measure idle
printf "  %-8s " "idle:"
"$EB" --summary -o "$RAW/idle.csv" -- sleep $IDLE_SECS > "$RAW/idle.txt" 2>&1
grep "Energy consumption" "$RAW/idle.txt" || echo "FAILED"

for arm in $ALL_ARMS; do
  case $arm in
    p1-aot) RT=$WASMTIME; IMG=bench/fileio-p1-aot:latest; ENTRY=fileio.wasm ;;
    p2-aot) RT=$WASMTIME; IMG=bench/fileio-p2-aot:latest; ENTRY=fileio.wasm ;;
    p1-jit) RT=$WASMTIME; IMG=docker.io/bench/fileio-p1:latest; ENTRY=/fileio.wasm ;;
    p2-jit) RT=$WASMTIME; IMG=docker.io/bench/fileio-p2:latest; ENTRY=/fileio.wasm ;;
    runc)   RT=$RUNC;     IMG=docker.io/bench/fileio-distroless:latest; ENTRY=/fileio ;;
  esac

  # run each arm
  printf "  %-8s " "$arm:"
  "$EB" --summary -o "$RAW/$arm.csv" -- \
    taskset -c $CPUS bash -c "
      for i in \$(seq 1 $N); do
        ctr run --rm --runtime=$RT --cpuset-cpus $CPUS --mount $MOUNT \
          $IMG f${BLOCKS}_\$i $ENTRY $ARGS >/dev/null 2>&1
      done" </dev/null > "$RAW/$arm.txt" 2>&1
  
  # Check that data has been written.
  if grep -q "Energy consumption" "$RAW/$arm.txt"; then
    grep "Energy consumption" "$RAW/$arm.txt"
  else
    echo "FAILED to measure. Check:  $RAW/$arm.txt"
  fi

  # --rm deletes successfull contianer runs
  # if any fail they are not deleted
  # This check for failed runs this way. 
  leftover=$(ctr containers ls -q | wc -l)
  if [ "$leftover" -ne 0 ]; then
    echo
    echo "error: $leftover continaers leftover after $arm."
    ctr containers ls
    echo "There may habe been a failure. Remove leftovers and try again."
    exit 1
  fi

  echo "  $arm complete, cooling down for ${COOLDOWN}s, please wait"
  sleep $COOLDOWN
done

echo
echo "processing data..."
FINALS=""
for arm in $ALL_ARMS; do
  arm_tag=$(echo "$arm" | tr '-' '_')
  python3 "$PROC" "${BENCH}_${arm_tag}" $N \
    "$RAW/idle.csv" "$RAW/idle.txt" \
    "$RAW/$arm.csv" "$RAW/$arm.txt" \
    "$PROCESSED/${BENCH}_${arm_tag}.csv"
  FINALS="$FINALS $PROCESSED/${BENCH}_${arm_tag}.csv"
done

echo
echo "RESULTS"
python3 combine_arms.py "$FINAL/${BENCH}_all_final.csv" $FINALS
