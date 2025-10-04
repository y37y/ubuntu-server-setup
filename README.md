# Ubuntu Development Environment Setup

Comprehensive setup scripts for Ubuntu-based systems, focusing on development tools, programming languages, system configurations, and **optional NVIDIA/CUDA** for local LLMs.

---

## 🚀 Features

### Core Development Tools
- Build Essential & GCC
- Python development tools
- Node.js (latest LTS via fnm)
- Go (latest version)
- Rust (with rustup)

### Shell & Terminal
- **Zsh shell** with modern configuration from [y37y/zsh](https://github.com/y37y/zsh)
- **Terminal utilities:** fzf, eza, atuin, zoxide, ripgrep, fd, starship, bat/batcat, gdu, trash-cli, yazi
- **Terminal multiplexers:** tmux, zellij
- **Terminal emulator:** WezTerm (kitty optional)

### Version Control
- Git & Git LFS
- Lazygit
- Lazydocker
- ghq (repository manager)
- GitHub CLI (gh)
- difftastic (modern diff)

### Code Editors
- Neovim with custom configuration (your repo)

### Browsers
- Google Chrome, Microsoft Edge, Brave Browser

### System Tools & Utilities
- **Monitoring:** bottom (btm), htop, btop, procs, fastfetch, dust, duf
- **Dev utils:** jq, yq, httpie, tldr, hyperfine, tokei, tree-sitter-cli, selene (Lua linter)

### Development Environment
- Docker & Docker Compose
- SSH tools with askpass support
- Miniconda3 with Zsh integration

### NVIDIA / CUDA (Optional; LLM-friendly)
- NVIDIA proprietary drivers (e.g., 535 / 550)
- CUDA Toolkit 12.x (for `nvcc`)
- NVIDIA Container Toolkit (optional)
- Notes for **pinning** driver/kernel to avoid breakage

### Extras
- Nerd Fonts (via `getnf` or curated set)
- GRUB configuration helper (optional)

---

## 🔧 Requirements

- Ubuntu **22.04** or **24.04**
- Internet connection
- Sudo privileges
- ≥1 GB free disk space
- NVIDIA GPU (only if using NVIDIA/CUDA)

---

## 📦 Installation

1) **Clone the repository**
```bash
git clone https://github.com/y37y/ubuntu-setup.git
cd ubuntu-setup
````

2. **Make scripts executable**

```bash
chmod +x *.sh
```

3. **Run the main setup script**

```bash
./setup.sh
```

4. **Optional: Run individual components**

```bash
./setup.sh base      # Base development tools
./setup.sh shell     # Zsh + shell tools
./setup.sh neovim    # Neovim + providers
./setup.sh grub      # GRUB configuration
```

5. **Optional: NVIDIA/CUDA setup**

```bash
./nvidia.sh
```

---

## 🧭 Script Structure

* `setup.sh` — Main installer
* `common.sh` — Shared helpers
* `node.sh` — Node.js (fnm, npm/pnpm/yarn globals)
* `rust.sh` — Rust toolchain
* `go.sh` — Go environment
* `nvidia.sh` — NVIDIA driver, CUDA toolkit, container runtime (optional)
* `nvidia-upgrade.md` — Safe upgrade checklist (driver/kernel/CUDA)
* `virtualbox.sh` — (Manual install recommended now)

---

## 🛠 Installation Options (Interactive)

The installer shows a checklist. Highlights:

1. Base Development Tools
2. Shell Tools (Zsh)
3. Version Control Tools
4. Miniconda
5. Neovim Setup
6. Node.js Environment
7. Rust Tools
8. Go Environment
9. Browsers
10. Dotfiles Configuration
11. SSH Tools
12. Network Tools (Tailscale, ZeroTier)
13. Nerd Fonts
14. Remote Access Tools (NoMachine + SSH)
15. VirtualBox (Removed here; install manually)
16. Update GRUB Configuration

---

## 🟩 NVIDIA & CUDA (LLM-friendly guide)

This repo ships a **safe, flag-driven** `nvidia.sh` so you can install just what you need (driver, CUDA, container runtime) and **freeze** versions to avoid `apt upgrade` surprises.

### Quick picks (RTX 4090 + llama.cpp / SillyTavern)

* **Driver:** `nvidia-driver-535` (very stable on 24.04)
  Use `nvidia-driver-550` only if you need something newer.
* **CUDA:** any **CUDA 12.x** works for building `llama.cpp` with GPU.
* **Display server:** If GNOME/Wayland misbehaves with NVIDIA, switch to **Xorg** or use **KDE/SDDM**.

### 1) Install the NVIDIA driver (and freeze it)

**Scripted (recommended):**

```bash
# Stable:
./nvidia.sh --driver 535 --hold-driver

# Or newer:
./nvidia.sh --driver 550 --hold-driver
```

**Manual via apt:**

```bash
sudo apt update
sudo apt install -y ubuntu-drivers-common
ubuntu-drivers list     # optional
sudo apt install -y nvidia-driver-535
sudo apt-mark hold nvidia-driver-535   # optional: freeze this version
sudo reboot
```

> **Unfreeze later:** `sudo apt-mark unhold nvidia-driver-535`
> **Extra cautious?** Also hold the current kernel:
>
> ```bash
> KVER="$(uname -r)"
> sudo apt-mark hold "linux-image-$KVER" "linux-headers-$KVER" "linux-modules-$KVER" "linux-modules-extra-$KVER" || true
> ```

### 2) Add CUDA Toolkit (to get `nvcc`)

If you need to **compile** llama.cpp with CUDA:

**Ubuntu-packaged toolkit (simple & works):**

```bash
sudo apt update
sudo apt install -y nvidia-cuda-toolkit
nvcc --version
```

**Or via script (choose CUDA without touching driver):**

```bash
./nvidia.sh --cuda 12.0
```

### 3) Build llama.cpp with CUDA

```bash
# deps
sudo apt install -y cmake ninja-build build-essential

# clone
cd ~/Projects
git clone https://github.com/ggml-org/llama.cpp.git
cd llama.cpp

# configure + build (Ada / RTX 4090 is SM_89)
cmake -B build -S . \
  -DGGML_CUDA=ON \
  -DGGML_CUDA_ARCH_LIST="89" \
  -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"

# run server (example)
~/Projects/llama.cpp/build/bin/llama-server \
  --model ~/models/YOUR_MODEL.gguf \
  --alias qwen3-coder-30b \
  --host 127.0.0.1 --port 8080 --api-key KingKong555 \
  --threads "$(nproc)" --n-gpu-layers 99 --ctx-size 33136
```

### 4) (Optional) NVIDIA Container Toolkit

```bash
# via script
./nvidia.sh --container
```

**Manual (Docker):**

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt update
sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### 5) Verify

```bash
nvidia-smi
nvcc --version       # if toolkit installed
curl -s -H "Authorization: Bearer KingKong555" http://127.0.0.1:8080/v1/models | jq .
```

### 6) Troubleshooting

* **Black screen / login loop (GNOME):** choose **GNOME on Xorg** at login (gear icon) or switch to **KDE/SDDM**.
* **Stuck at `plymouth-quit.service` / `session-cX.scope`:** `Ctrl+Alt+F2` → login TTY → `sudo systemctl restart gdm` (or `sddm`). Consider disabling Wayland on GDM or using KDE.
* **“Failed to initialize NVML: Driver/library version mismatch”:** reboot after installing/removing drivers; ensure only one version is installed.
* **llama.cpp not using GPU:** rebuild with `-DGGML_CUDA=ON` and confirm `nvcc --version` exists.

### 7) Upgrading later (the safe workflow)

See **`nvidia-upgrade.md`** for a full checklist. TL;DR:

```bash
# Unfreeze (only what you plan to upgrade)
sudo apt-mark unhold nvidia-driver-535

# Upgrade
sudo apt update
sudo apt --with-new-pkgs upgrade

# Reboot & verify
nvidia-smi

# Re-freeze
sudo apt-mark hold nvidia-driver-535

# If CUDA changed, rebuild llama.cpp
```

---

## 🔤 Nerd Fonts

Use **getnf** interactively (recommended) or install a curated set.

**Interactive (fzf if present):**

```bash
./setup.sh
# choose “Nerd Fonts” → uses getnf by default
```

**Manual curated set:**

```bash
./setup.sh  # choose “Nerd Fonts” (non-getnf path)
```

---

## ⚙️ Configuration Notes

* **Zsh config** auto-cloned from [y37y/zsh](https://github.com/y37y/zsh)
* **Neovim config** cloned from your repo and bootstrapped
* **Homebrew** used for many tools (latest versions)
* **Run scripts WITHOUT sudo** (they ask for sudo when needed)

---

## 🔍 Verification

```bash
# Shell & tools
zsh --version
bat --version
gdu --version
yazi --version

# Dev tools
node --version
go version
rustc --version
cargo --version

# Package managers
brew --version
fnm --version

# VCS
git --version
lazygit --version

# Docker
docker --version
docker compose version

# NVIDIA (if used)
nvidia-smi
nvitop
```

---

## 🔄 Updates

```bash
# Update this repo
cd ~/ubuntu-setup
git pull

# Update Zsh config
cd ~/.config/zsh
git pull
```

---

## ❗ Notes

* Do **not** run `setup.sh` with `sudo`
* Some changes require logout/login (default shell, PATH updates)
* NVIDIA install requires a **reboot**
* VirtualBox: install **manually** from Oracle’s site (script provided previously for reference only)

---
