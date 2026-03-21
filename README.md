# Ubuntu Development Environment Setup

Comprehensive setup scripts for Ubuntu-based systems, focusing on development tools, programming languages, system configurations, AI agent tooling, and **optional NVIDIA/CUDA** for local LLMs.

---

## Features

### Core Development Tools
- Build Essential & GCC
- Python development tools
- Node.js (latest LTS via fnm)
- Go (latest version)
- Rust (with rustup)
- Docker & Docker Compose

### Shell & Terminal
- **Zsh shell** with modern configuration from [y37y/zsh](https://github.com/y37y/zsh)
- **Terminal utilities:** fzf, eza, atuin, zoxide, ripgrep, fd, starship, bat/batcat, gdu, trash-cli
- **Terminal multiplexers:** tmux, zellij
- **Terminal emulators:** WezTerm (nightly), Kitty, Ghostty

### Version Control
- Git & Git LFS
- Lazygit, Lazydocker
- ghq (repository manager)
- GitHub CLI (gh)
- difftastic (modern diff)

### Code Editors
- Neovim with custom configuration

### Browsers
- Google Chrome, Microsoft Edge, Brave Browser

### AI Agent Tools (`agent.sh`)
- **Claude Code** (CLI, official npm package)
- **Claude Desktop** (unofficial Linux build via [claude-desktop-debian](https://github.com/aaddrick/claude-desktop-debian))
- **OpenCode**, **Qwen Code**, **OpenClaw**, **Eigent**
- Browser automation deps (Playwright, ChromeDriver, xvfb)
- Python agent venv (selenium, anthropic, openai, litellm, etc.)

### System Tools & Utilities
- **Monitoring:** bottom (btm), htop, btop, procs, fastfetch, dust, duf
- **Dev utils:** jq, yq, httpie, tldr, hyperfine, tokei, tree-sitter-cli, selene (Lua linter)
- **Network:** Tailscale, ZeroTier
- **Remote access:** NoMachine (pinned version), OpenSSH
- **File sharing:** LocalSend (via Flatpak)

### NVIDIA / CUDA (Optional)
- NVIDIA proprietary drivers (e.g., 535 / 550)
- CUDA Toolkit 12.x
- NVIDIA Container Toolkit
- Driver/kernel pinning to avoid breakage

### Extras
- Nerd Fonts (JetBrainsMono, Meslo, FiraCode, UbuntuMono)
- GRUB configuration helper
- Dotfiles management for wezterm, kitty, tmux, zsh, nvim
- Solaar (Logitech device manager, optional)
- Touchscreen disable (udev rule, X11/Wayland compatible)

---

## Requirements

- Ubuntu **22.04** or **24.04**
- Internet connection
- Sudo privileges
- At least 1 GB free disk space
- NVIDIA GPU (only if using nvidia.sh)

---

## Installation

1. **Clone the repository**

```bash
git clone https://github.com/y37y/ubuntu-setup.git
cd ubuntu-setup
```

2. **Make scripts executable**

```bash
chmod +x *.sh
```

3. **Run the main setup script**

```bash
./setup.sh          # Interactive menu
./setup.sh all      # Install everything
```

4. **Run individual components**

```bash
./setup.sh base      # Base development tools
./setup.sh shell     # Zsh + shell tools
./setup.sh neovim    # Neovim + providers
./setup.sh node      # Node.js via fnm
./setup.sh docker    # Docker
./setup.sh ghostty   # Ghostty terminal
./setup.sh dotfiles  # Dotfiles configuration
./setup.sh grub      # GRUB configuration
```

5. **AI agent tools**

```bash
./agent.sh           # Interactive menu
./agent.sh all       # Install all agent tools
./agent.sh deps      # System + browser automation deps only
./agent.sh claude-code
./agent.sh opencode
./agent.sh qwen
./agent.sh openclaw
./agent.sh eigent
./agent.sh verify    # Check what's installed
```

6. **NVIDIA/CUDA (optional)**

```bash
./nvidia.sh
```

---

## Script Structure

| Script | Purpose |
|---|---|
| `setup.sh` | Main installer with interactive menu |
| `common.sh` | Shared helper functions |
| `agent.sh` | AI agent tools (Claude Code, OpenCode, Qwen, etc.) |
| `node.sh` | Node.js (fnm, npm/pnpm/yarn globals) |
| `rust.sh` | Rust toolchain + cargo tools |
| `go.sh` | Go environment |
| `docker.sh` | Docker & Docker Compose |
| `kitty.sh` | Kitty terminal emulator |
| `dotfiles.sh` | Dotfiles management (wezterm, kitty, tmux, zsh) |
| `nvidia.sh` | NVIDIA driver, CUDA toolkit, container runtime |
| `nvidia-upgrade.md` | Safe upgrade checklist (driver/kernel/CUDA) |
| `solaar.sh` | Logitech device manager (optional) |
| `adguard.sh` | AdGuard VPN (optional) |
| `disable_touchscreen.sh` | Disable broken touchscreen via udev rule |

---

## Interactive Menu Options

The installer shows a checklist when run without arguments:

1. Install All Components
2. Base Development Tools
3. Shell Tools (Zsh)
4. Version Control Tools
5. Miniconda
6. Neovim Setup
7. Node.js Environment
8. Rust Tools
9. Go Environment
10. Docker
11. Browsers
12. Kitty Terminal
13. Ghostty Terminal
14. Dotfiles Configuration
15. SSH Tools
16. Network Tools (Tailscale, ZeroTier, LocalSend)
17. Nerd Fonts
18. Remote Access Tools (NoMachine + SSH)
19. Update GRUB Configuration

AI agent tools are installed separately via `./agent.sh`.

---

## NVIDIA & CUDA (LLM-friendly guide)

This repo ships a **safe, flag-driven** `nvidia.sh` so you can install just what you need (driver, CUDA, container runtime) and **freeze** versions to avoid `apt upgrade` surprises.

### Quick install

```bash
# Driver + freeze
./nvidia.sh --driver 535 --hold-driver

# CUDA toolkit (without touching driver)
./nvidia.sh --cuda 12.0

# Container toolkit (for Docker GPU passthrough)
./nvidia.sh --container
```

### Build llama.cpp with CUDA

```bash
cd ~/Projects
git clone https://github.com/ggml-org/llama.cpp.git
cd llama.cpp

cmake -B build -S . \
  -DGGML_CUDA=ON \
  -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"
```

### Upgrading (the safe workflow)

See **`nvidia-upgrade.md`** for the full checklist.

### Troubleshooting

- **Black screen / login loop (GNOME):** choose GNOME on Xorg at login (gear icon)
- **"Failed to initialize NVML":** reboot after installing/removing drivers
- **llama.cpp not using GPU:** rebuild with `-DGGML_CUDA=ON` and confirm `nvcc --version` exists

---

## Configuration Notes

- **Zsh config** auto-cloned from [y37y/zsh](https://github.com/y37y/zsh)
- **Neovim config** cloned from your repo and bootstrapped
- **Homebrew** used for many tools (latest versions)
- **Run scripts WITHOUT sudo** (they ask for sudo when needed)
- **NoMachine** uses a pinned version (8.14.2) with download validation

---

## Verification

```bash
# Shell & tools
zsh --version && bat --version && gdu --version

# Dev tools
node --version && go version && rustc --version

# Package managers
brew --version && fnm --version

# Docker
docker --version && docker compose version

# Agent tools
claude --version && opencode --version

# NVIDIA (if used)
nvidia-smi
```

---

## Notes

- Do **not** run `setup.sh` with `sudo`
- Some changes require logout/login (default shell, PATH updates)
- NVIDIA install requires a **reboot**
- The `disable_touchscreen.sh` script uses a udev rule that works on both X11 and Wayland
- Scripts are idempotent — safe to re-run without re-downloading/recompiling already-installed tools
