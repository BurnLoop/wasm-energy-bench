#!/usr/bin/env bash
set -eu

BENCHES="coldstart mandelbrot matmul fileio image_processing fuzzysearch"

cd benchmarks
rustup target add wasm32-wasip1
rustup target add wasm32-wasip2
cargo build --release
cargo build --release --target wasm32-wasip1
cargo build --release --target wasm32-wasip2

mkdir -p images/jit images/aot images/runc comp

sudo systemctl start containerd docker

for b in $BENCHES; do
  sudo docker build -f docker/Dockerfile.$b-p1 -t bench/$b-p1:latest .
  sudo docker save bench/$b-p1:latest -o images/jit/docker-$b-p1.tar
  sudo docker build -f docker/Dockerfile.$b-p2 -t bench/$b-p2:latest .
  sudo docker save bench/$b-p2:latest -o images/jit/docker-$b-p2.tar
  sudo docker build -f docker/Dockerfile.$b-distroless -t bench/$b-distroless:latest .
  sudo docker save bench/$b-distroless:latest -o images/runc/docker-$b-distroless.tar
done

sudo systemctl stop docker docker.socket containerd

for b in $BENCHES; do
  mkdir -p comp/$b
  rm -f comp/$b/*.wasm
  cp target/wasm32-wasip2/release/$b.wasm comp/$b/
done

cd ../runwasi
for b in $BENCHES; do
  ./target/release/oci-tar-builder \
    --name $b-p1-aot --repo bench --tag latest \
    --module ../benchmarks/target/wasm32-wasip1/release/$b.wasm \
    -o ../benchmarks/images/aot/$b-p1-aot.tar
  ./target/release/oci-tar-builder \
    --name $b-p2-aot --repo bench --tag latest \
    --components ../benchmarks/comp/$b \
    -o ../benchmarks/images/aot/$b-p2-aot.tar
done

cd ../benchmarks
ls -lh images/jit images/aot images/runc
pgrep -x containerd || echo "containerd not running"
