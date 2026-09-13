# WebAssembly Energy Benchmarking
Tested on Ubuntu 26.04 LTS with an AMD Ryzen AI 9 HX370 CPU.
## Pre-requisites
You will need the following software installed/built:
- Rust compiler toolchain
- EnergiBridge
- contianerd
- runc
- runwasi with Wasmtime shim
- runwsi oci-tar-builder
- Docker
- Python3

The `setup_guides` directory contains files that describe the steps I followed to setup EnergiBridge, containerd, runc, runwasi shim, oci-tar-builder and Docker. Please note that these steps may change with newer versions of the software so refer to official installation guidance for these tools first.
## Build
Step 1: Build the images
```bash
./build_images.sh
```

Step 2: Open a separate terminal window and run cotnainerd deamon
```bash
sudo containerd
```

Step 3: Import the images to containerd's local store and do a dry run of the AOT images to trigger pre-compilation and caching of cwasm files.
```bash
./import_images.sh
```

## Run
Before running make sure EnergiBridge has access to the msr module and that contianerd is running in the background. In a separate terminal window run:
```bash
sudo modprobe msr
sudo chmod o+r /dev/cpu/*/msr
sudo containerd
```

To run a benchmark, run one of the automation scripts in the `experiment_scirpts` directory. Each script has a comment that describes how to use it and what parameters it requires
For example:
```bash
cd experiment_scripts
sudo ./run_matmul.sh 1024 100
```

NOTE: The automation scripts contain instructions specific to our hybrid CPU setup including things like pinning to specific cores using the taskset utility. You will need to remove such commands before running. We have left them in as proof of our strategy for our hardware setup.
