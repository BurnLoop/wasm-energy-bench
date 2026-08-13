#!/usr/bin/env bash
#
# Automation script for the fuzzybench benchmark
# As this bnechmark is very short lived it is susceptible to noise.
# So we repeat this same bencmark 3 times (with 500 incovations per configuratoin)
# The python scripts handle the averaging over the repeats. 
#
# For the repeated benchmarks we alternate the cofigurations (e.g. runc, P2 JIT)
# so that each configuration is not repeatedly hot or cold across the 3 rounds
#
# Normally fuzzysearch print it's ouput to stdout, we redirect it to null
# to make the script output clearer.
#
# Run from the experiment_scripts folder:  
# sudo ./run_fuzzysearch.sh
#

set -u

BENCH=fuzzysearch
N=500
COOLDOWN=60
IDLE_SECS=40

ROOT=..
EB=$ROOT/EnergiBridge/target/release/energibridge
PROC=process_run.py
RES=$ROOT/results/$BENCH
CPUS=0,1,2,3,12,13,14,15

RAW=$RES/raw_data_rounds
PROCESSED=$RES/processed_rounds
FINAL=$RES/final

WASMTIME=io.containerd.wasmtime.v1
RUNC=io.containerd.runc.v2

# ctr needs an absolute path so we assume diskbench exists and is 
# in the parent folder/directory.
DISKBENCH=$(cd "$ROOT/diskbench" && pwd)
MOUNT="type=bind,src=$DISKBENCH,dst=/data,options=rbind:rw"
ARGS="/data/hamlet.txt Hamlet"

ALL_ARMS="p1-aot p2-jit runc p2-aot p1-jit"

mkdir -p "$RAW/idle" "$FINAL"
for arm in $ALL_ARMS; do
  mkdir -p "$RAW/$arm" "$PROCESSED/$arm"
done

# Make sure there are no actively running contianers.
leftover=$(ctr containers ls -q | wc -l)
if [ "$leftover" -ne 0 ]; then
  echo "error: $leftover containers currenlty running. Stop them and try again."
  ctr containers ls
  exit 1
fi

for round in 1 2 3; do
  echo "ROUND $round "

  case $round in
    1) ORDER="p1-aot p2-jit runc   p2-aot p1-jit" ;;
    2) ORDER="runc   p2-aot p1-jit p2-jit p1-aot" ;;
    3) ORDER="p1-jit p1-aot p2-jit runc   p2-aot" ;;
  esac

# Measure idle, to be accounted for by the Python scripts for the final results.
  printf "  %-8s " "idle:"
  "$EB" --summary -o "$RAW/idle/round$round.csv" -- sleep $IDLE_SECS \
    > "$RAW/idle/round$round.txt" 2>&1
  grep "Energy consumption" "$RAW/idle/round$round.txt" || echo "FAILED"

  for arm in $ORDER; do
    case $arm in
      p1-aot) RT=$WASMTIME; IMG=bench/fuzzysearch-p1-aot:latest; ENTRY=fuzzysearch.wasm ;;
      p2-aot) RT=$WASMTIME; IMG=bench/fuzzysearch-p2-aot:latest; ENTRY=fuzzysearch.wasm ;;
      p1-jit) RT=$WASMTIME; IMG=docker.io/bench/fuzzysearch-p1:latest;ENTRY=/fuzzysearch.wasm ;;
      p2-jit) RT=$WASMTIME; IMG=docker.io/bench/fuzzysearch-p2:latest; ENTRY=/fuzzysearch.wasm ;;
      runc)   RT=$RUNC;     IMG=docker.io/bench/fuzzysearch-distroless:latest; ENTRY=/fuzzysearch ;;
    esac

# Execute with each configuration.
    printf "  %-8s " "$arm:"
    "$EB" --summary -o "$RAW/$arm/round$round.csv" -- \
      taskset -c $CPUS bash -c "
        for i in \$(seq 1 $N); do
          ctr run --rm --runtime=$RT --cpuset-cpus $CPUS --mount $MOUNT \
            $IMG f\$(date +%s%N) $ENTRY $ARGS >/dev/null 2>&1
        done" </dev/null > "$RAW/$arm/round$round.txt" 2>&1

# Chek for measurmeents.
    if grep -q "Energy consumption" "$RAW/$arm/round$round.txt"; then
      grep "Energy consumption" "$RAW/$arm/round$round.txt"
    else
      echo "FAILED to measure: check: $RAW/$arm/round$round.txt"
    fi

  # --rm deletes successfull contianer runs
  # if any fail they are not deleted
  # This check for failed runs this way. 
    leftover=$(ctr containers ls -q | wc -l)
    if [ "$leftover" -ne 0 ]; then
      echo
      echo "error: $leftover containers alive after $arm round $round."
      ctr containers ls
      echo "Possibly failed run. Remove leftovers and try again."
      exit 1
    fi

    echo "  $arm complete, cooling down for ${COOLDOWN}s, please wait"
    sleep $COOLDOWN
  done
  echo
done

echo "processing data..."
for arm in $ALL_ARMS; do
  arm_tag=$(echo "$arm" | tr '-' '_')
  for round in 1 2 3; do
    python3 "$PROC" "${BENCH}_${arm_tag}_round${round}" $N \
      "$RAW/idle/round$round.csv" "$RAW/idle/round$round.txt" \
      "$RAW/$arm/round$round.csv" "$RAW/$arm/round$round.txt" \
      "$PROCESSED/$arm/${BENCH}_${arm_tag}_round${round}.csv"
  done
done

FINALS=""
for arm in $ALL_ARMS; do
  arm_tag=$(echo "$arm" | tr '-' '_')
  python3 average_rounds.py "${BENCH}_${arm_tag}" \
    "$FINAL/${BENCH}_${arm_tag}_final.csv" \
    "$PROCESSED/$arm/${BENCH}_${arm_tag}_round1.csv" \
    "$PROCESSED/$arm/${BENCH}_${arm_tag}_round2.csv" \
    "$PROCESSED/$arm/${BENCH}_${arm_tag}_round3.csv"
  FINALS="$FINALS $FINAL/${BENCH}_${arm_tag}_final.csv"
done

echo
echo "RESULTS"
python3 combine_arms.py "$FINAL/${BENCH}_all_final.csv" $FINALS
