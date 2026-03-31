# Ubuntu Server Setup — LLM Inference

Automated setup scripts for Ubuntu 24.04 Server optimized for LLM inference workloads.
Target hardware: **RTX 4090** (or any NVIDIA GPU with 8GB+ VRAM).

## Quick Start

```bash
git clone https://github.com/y37y/ubuntu-server-setup.git
cd ubuntu-server-setup
chmod +x setup.sh
./setup.sh          # interactive whiptail menu
```

Or non-interactive:

```bash
# Full server stack (essential + docker + nvidia + ollama)
./setup.sh --all-server

# Individual components
./setup.sh --essential --docker --nvidia --inference
```

## Components

### Core Scripts

| Script | Description |
|--------|-------------|
| `setup.sh` | Interactive menu or CLI installer |
| `common.sh` | Shared helper functions |
| `docker.sh` | Docker Engine + Docker Compose |
| `nvidia.sh` | NVIDIA drivers + CUDA + container toolkit |
| `inference.sh` | Ollama, llama.cpp, vLLM |
| `network.sh` | Tailscale VPN + SSH hardening |
| `dotfiles.sh` | Zsh + tmux + Neovim configs |
| `node.sh` | Node.js via fnm |
| `rust.sh` | Rust toolchain via rustup |
| `go.sh` | Go (latest from go.dev) |
| `agent.sh` | Claude Code and other AI agent tools |

---

## nvidia.sh

Handles driver, CUDA, and container toolkit installation safely.

```bash
# Auto-detect driver + auto-select best CUDA version + Docker GPU support
./nvidia.sh --auto --cuda --container

# Pin a specific CUDA version
./nvidia.sh --auto --cuda 12.6 --container

# Specific driver + auto CUDA
./nvidia.sh --driver 570 --cuda --container

# CUDA only (driver already installed, version auto-selected)
./nvidia.sh --cuda

# Hold driver version to prevent apt upgrades
./nvidia.sh --auto --hold-driver
```

**Driver/CUDA compatibility:**

| Driver | Max CUDA |
|--------|----------|
| 535    | 12.2     |
| 550    | 12.4     |
| 560    | 12.6     |
| 570+   | 12.8     |

**Verify:**
```bash
nvidia-smi
nvcc --version
docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu24.04 nvidia-smi
```

---

## inference.sh

```bash
# Install all inference tools
./inference.sh --all

# Ollama only (easiest — GPU auto-detected)
./inference.sh --ollama

# llama.cpp compiled with CUDA
./inference.sh --llama-cpp

# vLLM in a Python venv (requires CUDA)
./inference.sh --vllm
```

### Ollama

```bash
# Start (or use systemd service installed automatically)
ollama serve

# Pull and run models
ollama run llama3.2
ollama run qwen2.5-coder:7b
ollama run deepseek-r1:7b

# OpenAI-compatible API
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3.2","messages":[{"role":"user","content":"hi"}]}'
```

### llama.cpp

Binaries installed to `~/.local/bin/`:

```bash
# Run inference
llama-cli -m /path/to/model.gguf -p "Hello" -n 256 --gpu-layers 99

# OpenAI-compatible server
llama-server -m /path/to/model.gguf --port 8080 --gpu-layers 99
```

### vLLM

```bash
source ~/venvs/vllm/bin/activate
# Or use the alias: vllm-activate

# Serve a HuggingFace model (OpenAI-compatible API on port 8000)
vllm serve Qwen/Qwen2.5-7B-Instruct --gpu-memory-utilization 0.9

# Use the API
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen/Qwen2.5-7B-Instruct","messages":[{"role":"user","content":"hi"}]}'
```

---

## network.sh

```bash
# Tailscale only
./network.sh --tailscale

# SSH hardening only (ensure SSH keys are set up first!)
./network.sh --ssh-harden

# Both
./network.sh --all
```

**SSH hardening applies:**
- Password authentication disabled
- Root login disabled
- Max auth tries: 3
- fail2ban: bans IPs after 3 failed SSH attempts for 24h

> **Warning:** Set up your SSH public key (`~/.ssh/authorized_keys`) **before** running `--ssh-harden`.

---

## dotfiles.sh

Clones and symlinks configs for zsh, tmux, and Neovim from [github.com/y37y](https://github.com/y37y):

```bash
./dotfiles.sh           # install
./dotfiles.sh update    # pull latest from all repos
./dotfiles.sh status    # check what's installed
```

---

## docker.sh

Installs Docker Engine from the official Docker repo.

```bash
./docker.sh
```

After install, log out and back in for the `docker` group to take effect.

---

## Requirements

- Ubuntu 24.04 Server (minimal or standard)
- Internet access
- At least 20GB free disk space (more for large models)
- NVIDIA GPU with CUDA-capable driver (for GPU inference)

## Upgrading NVIDIA Drivers Safely

```bash
# Hold the driver to prevent accidental upgrades
sudo apt-mark hold nvidia-driver-570

# To upgrade: unhold, upgrade, rehold
sudo apt-mark unhold nvidia-driver-570
sudo apt-get install nvidia-driver-575
sudo apt-mark hold nvidia-driver-575
sudo reboot
```

## Troubleshooting

**GPU not detected by Docker:**
```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu24.04 nvidia-smi
```

**Ollama not using GPU:**
```bash
nvidia-smi           # verify driver is loaded
ollama run llama3.2 --verbose  # check GPU layers
```

**llama.cpp built without CUDA:**
```bash
# Ensure nvcc is in PATH first
source ~/.bashrc
which nvcc
# Then rebuild
cd ~/Projects/llama.cpp
rm -rf build
cmake -B build -DGGML_CUDA=ON && cmake --build build -j$(nproc)
```
