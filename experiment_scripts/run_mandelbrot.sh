#!/usr/bin/env bash
#
# Script for automating Mandelbrot benchmark runs
# Usage: sudo run_mandelbrot.sh <size> <num invocations/>
# num_invocations correspond to the number of iterations that a
# single EnergiBridge call measures. These are processed and 
# averaged by the Python scripts.
#
# Fou our tests we adjusted so that each param size would have at least
# 30s of execution time reuslting in minimum 150 samples per configurarion.
#
# Run from experiment_script folder: 
# sudo ./run_mandelbrot.sh 50 500
# sudo ./run_mandelbrot.sh 100 400
# sudo ./run_mandelbrot.sh 200 250
# sudo ./run_mandelbrot.sh 400 90
# sudo ./run_mandelbrot.sh 800 30
#
# Results are written tp results/mandelbrot_<size>/
#
set -u

SIZE=$1
N=$2
MAX_ITERS=10000

BENCH=mandelbrot_${SIZE}
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

ARGS="$SIZE $MAX_ITERS"

ALL_ARMS="p1-aot p2-jit runc p2-aot p1-jit"

mkdir -p "$RAW" "$PROCESSED" "$FINAL"

# Make sure there are no actively running contianers.
leftover=$(ctr containers ls -q | wc -l)
if [ "$leftover" -ne 0 ]; then
  echo "error: $leftover containers already running. Remove them and try again."
  ctr containers ls
  exit 1
fi


# Measure idle, to be accounted for by the Python scripts for the final results.
printf "  %-8s " "idle:"
"$EB" --summary -o "$RAW/idle.csv" -- sleep $IDLE_SECS > "$RAW/idle.txt" 2>&1
grep "Energy consumption" "$RAW/idle.txt" || echo "FAILED"

for arm in $ALL_ARMS; do
  case $arm in
    p1-aot) RT=$WASMTIME; IMG=bench/mandelbrot-p1-aot:latest; ENTRY=mandelbrot.wasm ;;
    p2-aot) RT=$WASMTIME; IMG=bench/mandelbrot-p2-aot:latest; ENTRY=mandelbrot.wasm ;;
    p1-jit) RT=$WASMTIME; IMG=docker.io/bench/mandelbrot-p1:latest; ENTRY=/mandelbrot.wasm ;;
    p2-jit) RT=$WASMTIME; IMG=docker.io/bench/mandelbrot-p2:latest; ENTRY=/mandelbrot.wasm ;;
    runc)   RT=$RUNC;     IMG=docker.io/bench/mandelbrot-distroless:latest; ENTRY=/mandelbrot ;;
  esac

# Run all arms/configurations, wrapped in EnergiBridge.
  printf "  %-8s " "$arm:"
  "$EB" --summary -o "$RAW/$arm.csv" -- \
    taskset -c $CPUS bash -c "
      for i in \$(seq 1 $N); do
        ctr run --rm --runtime=$RT --cpuset-cpus $CPUS $IMG m${SIZE}_\$i $ENTRY $ARGS \
          >/dev/null 2>&1
      done" </dev/null > "$RAW/$arm.txt" 2>&1

# Chek for measurmeents.
  if grep -q "Energy consumption" "$RAW/$arm.txt"; then
    grep "Energy consumption" "$RAW/$arm.txt"
  else
    echo "FAILED to measure. Check: $RAW/$arm.txt"
  fi

  # --rm deletes successfull contianer runs
  # if any fail they are not deleted
  # This check for failed runs this way. 
  leftover=$(ctr containers ls -q | wc -l)
  if [ "$leftover" -ne 0 ]; then
    echo
    echo "error: $leftover continaer leftover after $arm."
    ctr containers ls
    echo "Possibly failed run. Clean up leftovers and try again."
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
