# Containerd & runc & RunWASI setup
containerd GitHub repository: https://github.com/containerd/containerd

runc GitHub repository: https://github.com/opencontainers/runc/

runwasi GitHub repository: https://github.com/containerd/runwasi

runwasi website and documentation: https://runwasi.dev/index.html

Tested on Ubuntu 26.04 LTS. with an AMD Ryzen AI 9 HX370 CPU.

Folder structure:
```
~/wasm-energy-bench/
├── runwasi/ # GitHub clone                             
└── EnergiBridge/ # GitHub clone
```
## 1. Install containerd + runc
containerd:
```bash
cd ~/wasm-energy-bench
CONTAINERD_VERSION=2.3.2
wget https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
containerd --version
```

**runc:**:
```bash
cd ~/wasm-energy-bench
RUNC_VERSION=1.5.0
wget https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64
sudo install -m 755 runc.amd64 /usr/local/sbin/runc
runc --version
```
## 2. Setup runwasi with WasmTime
```bash
cd ~/wasm-energy-bench
git clone https://github.com/containerd/runwasi.git
cd runwasi
./scripts/setup-linux.sh                             

make build-wasmtime OPT_PROFILE=release
sudo env "PATH=$PATH" make install-wasmtime OPT_PROFILE=release
which containerd-shim-wasmtime-v1
```
##  3. Build oci-tar-builder tool
```bash
cd ~/wasm-energy-bench/runwasi
cargo build --release --bin oci-tar-builder
ls -lh target/release/oci-tar-builder
./target/release/oci-tar-builder --help
```
## 4. Per-session startup 
For EnergiBridge
```bash
sudo modprobe msr
sudo chmod o+r /dev/cpu/*/msr
```

Start containerd deamon in a separate terminal.
```bash
sudo containerd
```
## 5. Check with demo app 
```bash
sudo ctr version
sudo ctr images pull ghcr.io/containerd/runwasi/wasi-demo-app:latest
sudo ctr run --rm --runtime=io.containerd.wasmtime.v1 \
  ghcr.io/containerd/runwasi/wasi-demo-app:latest testwasm \
  /wasi-demo-app.wasm echo 'hello'
```
