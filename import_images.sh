#!/usr/bin/env bash
set -eu

BENCHES="coldstart mandelbrot matmul fileio image_processing fuzzysearch"
WASMTIME=io.containerd.wasmtime.v1
MOUNT="type=bind,src=$PWD/diskbench,dst=/data,options=rbind:rw"

cd benchmarks

for b in $BENCHES; do
  sudo ctr images rm docker.io/bench/$b-p1:latest 2>/dev/null || true
  sudo ctr image import --all-platforms images/jit/docker-$b-p1.tar
  sudo ctr images rm docker.io/bench/$b-p2:latest 2>/dev/null || true
  sudo ctr image import --all-platforms images/jit/docker-$b-p2.tar
  sudo ctr images rm docker.io/bench/$b-distroless:latest 2>/dev/null || true
  sudo ctr image import --all-platforms images/runc/docker-$b-distroless.tar
  sudo ctr images rm bench/$b-p1-aot:latest 2>/dev/null || true
  sudo ctr image import --all-platforms images/aot/$b-p1-aot.tar
  sudo ctr images rm bench/$b-p2-aot:latest 2>/dev/null || true
  sudo ctr image import --all-platforms images/aot/$b-p2-aot.tar
done

# Do a dry run to trigger pre-compilation of cwasm files for AOT images
for p in 1 2; do
  sudo ctr run --rm --runtime=$WASMTIME \
    bench/coldstart-p$p-aot:latest warmcold$p coldstart.wasm
  sudo ctr run --rm --runtime=$WASMTIME \
    bench/mandelbrot-p$p-aot:latest warmmandel$p mandelbrot.wasm 64 100
  sudo ctr run --rm --runtime=$WASMTIME \
    bench/matmul-p$p-aot:latest warmmatmul$p matmul.wasm 128
  sudo ctr run --rm --runtime=$WASMTIME --mount $MOUNT \
    bench/fileio-p$p-aot:latest warmfileio$p fileio.wasm 1000 /data
  sudo ctr run --rm --runtime=$WASMTIME --mount $MOUNT \
    bench/image_processing-p$p-aot:latest warmimg$p image_processing.wasm /data/input.png 256 /data
  sudo ctr run --rm --runtime=$WASMTIME --mount $MOUNT \
    bench/fuzzysearch-p$p-aot:latest warmfuzzy$p fuzzysearch.wasm /data/hamlet.txt Hamlet > /dev/null
done

sudo ctr images ls | grep bench/
sudo ctr content ls | grep -c "runwasi.io/precompiled/wasmtime.*=true"
sudo ctr containers ls
