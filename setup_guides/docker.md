# Docker Setup
## Install
```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl stop docker docker.socket
sudo usermod -aG docker $USER
docker --version
```

## Prevent auto start up
```bash
sudo systemctl disable --now docker docker.socket
sudo systemctl is-enabled docker docker.socket
```

## Activate before use
```bash
sudo systemctl start containerd
sudo systemctl start docker
```

## Deactivate after
```bash
sudo systemctl stop docker docker.socket
sudo systemctl stop containerd
```

