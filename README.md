# Ubuntu Development Environment Setup

Comprehensive setup scripts for Ubuntu-based systems, focusing on development tools, programming languages, and system configurations.

## 🚀 Features

### Core Development Tools
- Build Essential & GCC
- Python development tools
- Node.js (latest LTS via fnm)
- Go (latest version)
- Rust (with rustup)

### Shell & Terminal
- Fish shell with Fisher plugin manager
- Nushell
- Terminal utilities:
  - fzf (fuzzy finder)
  - eza (modern ls)
  - atuin (shell history)
  - zoxide (smart cd)
  - ripgrep (modern grep)
  - fd (find alternative)
  - starship (shell prompt)
  - bat/batcat (cat alternative)
  - gdu (disk usage analyzer, installed from GitHub)
  - trash-cli (trash management)
  - yazi (terminal file manager)
- Terminal multiplexers:
  - tmux
  - zellij
- WezTerm terminal emulator

### Version Control
- Git & Git LFS
- Lazygit
- Lazydocker
- ghq (repository manager)
- GitHub CLI (gh)
- difftastic (modern diff)

### Code Editors
- Neovim with custom configuration
- Git-managed Neovim config

### Browsers
- Google Chrome
- Microsoft Edge
- Brave Browser

### System Tools & Utilities
- System Monitoring:
  - bottom (btm - system monitor)
  - htop (process viewer)
  - btop (resource monitor)
  - procs (modern ps)
  - fastfetch (system info)
  - dust (disk usage visualization)
  - duf (disk usage utility)

- Development Utilities:
  - jq (JSON processor)
  - yq (YAML processor)
  - httpie (modern curl)
  - tldr (simplified man pages)
  - hyperfine (benchmarking)
  - tokei (code statistics)
  - tree-sitter-cli (installed via cargo)
  - selene (Lua linter)

### Development Environment
- Docker & Docker Compose
- SSH tools with askpass support
- Miniconda3 (with chezmoi-managed config)

### NVIDIA Support (Optional)
- NVIDIA drivers
- CUDA Toolkit 12.6.3
- nvitop (GPU monitoring)

### Additional Features
- Nerd Fonts collection
- Chezmoi dotfiles management
- GRUB configuration (optional)

## 🔧 Requirements

- Ubuntu 22.04/24.04
- Internet connection
- Sudo privileges
- SSH key for GitHub access
- At least 10GB free disk space
- NVIDIA GPU (for NVIDIA/CUDA installation)

## 📦 Installation

1. Clone the repository:
```bash
git clone git@github.com:busyleo/ubuntu-script.git
cd ubuntu-script
```

2. Make scripts executable:
```bash
chmod +x *.sh
```

3. Run the main setup script:
```bash
./setup.sh
```

4. Optional: Run NVIDIA setup separately:
```bash
./nvidia-setup.sh
```

## 🎯 Script Structure

- `setup.sh`: Main installation script
- `common.sh`: Shared functions and utilities
- `node-setup.sh`: Node.js environment setup (fnm, npm packages)
- `rust-setup.sh`: Rust environment setup (rustup, cargo tools)
- `go-setup.sh`: Go environment setup
- `nvidia-setup.sh`: NVIDIA drivers and CUDA installation

## 🛠 Installation Options

The script provides an interactive menu to select components:

1. Base Development Tools
2. Shell Tools (Fish, Terminal Utils)
3. Version Control Tools
4. Neovim Setup
5. Node.js Environment
6. Rust Tools
7. Go Environment
8. Browsers
9. Chezmoi Dotfiles
10. SSH Tools

## ⚙️ Configuration

- Fish shell configuration is managed through chezmoi
- Neovim configuration is cloned from your git repository
- All tools configurations are managed via chezmoi dotfiles
- SSH agent and keys are automatically configured

## 🔍 Verification

After installation, verify components:
```bash
# Shell and Tools
fish --version
bat --version
gdu --version
yazi --version

# Development Tools
node --version   # Should show LTS version
go version
rustc --version
cargo --version

# Package Managers
brew --version
fnm --version

# Version Control
git --version
lazygit --version

# Docker
docker --version
docker compose version

# NVIDIA (if installed)
nvidia-smi
nvitop
```

## ⚠️ Notes

- Run script WITHOUT sudo (script will ask for sudo when needed)
- Script checks for SSH keys and GitHub access before starting
- Homebrew is installed without sudo as recommended
- NVIDIA installation requires system restart
- Fish shell becomes default after installation
- All configurations are managed through chezmoi
- Browser installation is optional
- Some tools require logging out and back in to take effect
