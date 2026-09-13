# EnergiBridge Setup 

EnergiBridge: https://github.com/tdurieux/EnergiBridge

Tested on Ubuntu 26.04 LTS with an AMD Ryzen AI 9 HX370 CPU.

Folder structure:
```
~/wasm-energy-bench/
├── EnergiBridge/ # cloned from GitHub
│   └── target/release/energibridge # binary
```
## 1. Build EnergiBridge
Install dependencies:
```bash
sudo apt update
sudo apt install -y build-essential git
```
```bash
# Skip if you laready have Rust installed
# Rust compiler and  tooling
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"
```

Build and setup EnergiBridge:
```bash
# Build EnergiBridge
cd ~/wasm-energy-bench
git clone https://github.com/tdurieux/EnergiBridge.git
cd EnergiBridge && cargo build -r && cd ..
```

Grant permissions for EnergiBridge to read RAPL
(**NOTE: re-run this if you recompile or move the binary**)
```bash 
sudo setcap cap_sys_rawio=ep ~/wasm-energy-bench/EnergiBridge/target/release/energibridge
```

**NEEDS TO BE REPEATED ONCE  EVERY SESSION/REBOOT**
Load the required msr kernel module.
```bash
sudo modprobe msr
sudo chmod o+r /dev/cpu/*/msr
```

Unload msr when finished use:
```bash
sudo modprobe -r msr
```
