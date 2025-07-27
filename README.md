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
- **Zsh shell** with modern configuration from [y37y/zsh](https://github.com/y37y/zsh)
- **Terminal utilities:**
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
- **Terminal multiplexers:**
  - tmux
  - zellij
- **WezTerm** terminal emulator

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
- **System Monitoring:**
  - bottom (btm - system monitor)
  - htop (process viewer)
  - btop (resource monitor)
  - procs (modern ps)
  - fastfetch (system info)
  - dust (disk usage visualization)
  - duf (disk usage utility)

- **Development Utilities:**
  - jq (JSON processor)
  - yq (YAML processor)
  - httpie (modern curl)
  - tldr (simplified man pages)
  - hyperfine (benchmarking)
  - tokei (code statistics)
  - tree-sitter-cli
  - selene (Lua linter)

### Development Environment
- Docker & Docker Compose
- SSH tools with askpass support
- Miniconda3 with Zsh integration

### NVIDIA Support (Optional)
- NVIDIA drivers
- CUDA Toolkit 12.6.3
- nvitop (GPU monitoring)

### Additional Features
- Nerd Fonts collection
- Direct Git-based configuration management
- GRUB configuration (optional)

## 🔧 Requirements

- Ubuntu 22.04/24.04
- Internet connection
- Sudo privileges
- At least 1GB free disk space
- NVIDIA GPU (for NVIDIA/CUDA installation)

## 📦 Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/y37y/ubuntu-setup.git
   cd ubuntu-setup
   ```

2. **Make scripts executable:**
   ```bash
   chmod +x *.sh
   ```

3. **Run the main setup script:**
   ```bash
   ./setup.sh
   ```

4. **Optional: Run individual components:**
   ```bash
   ./setup.sh base     # Base development tools
   ./setup.sh shell    # Zsh and shell tools
   ./setup.sh neovim   # Neovim setup
   ./setup.sh grub     # GRUB configuration
   ```

5. **Optional: Run NVIDIA setup separately:**
   ```bash
   ./nvidia.sh
   ```

## 🎯 Script Structure

- `setup.sh`: Main installation script
- `common.sh`: Shared functions and utilities
- `node.sh`: Node.js environment setup (fnm, npm packages)
- `rust.sh`: Rust environment setup (rustup, cargo tools)
- `go.sh`: Go environment setup
- `nvidia.sh`: NVIDIA drivers and CUDA installation
- `virtualbox.sh`: VirtualBox installation

## 🛠 Installation Options

The script provides an interactive menu to select components:

1. **Base Development Tools** - Essential build tools and utilities
2. **Shell Tools (Zsh)** - Zsh shell with modern terminal utilities
3. **Version Control Tools** - Git, Lazygit, GitHub CLI
4. **Neovim Setup** - Neovim with custom configuration
5. **Node.js Environment** - fnm and Node.js ecosystem
6. **Rust Tools** - Rust toolchain and cargo utilities
7. **Go Environment** - Go compiler and tools
8. **Browsers** - Chrome, Edge, Brave
9. **SSH Tools** - SSH client and utilities (no keys required)
10. **Network Tools** - Tailscale, ZeroTier
11. **Nerd Fonts** - Programming fonts collection
12. **Remote Access Tools** - NoMachine, OpenSSH server
13. **VirtualBox** - Virtualization platform
14. **Update GRUB Configuration** - Kernel parameter optimization

## ⚙️ Configuration

- **Zsh configuration** is automatically cloned from [y37y/zsh](https://github.com/y37y/zsh)
- **Neovim configuration** is cloned from your git repository
- **Direct file management** - no complex dotfile managers required
- **Homebrew integration** for latest tool versions

## 🔍 Verification

After installation, verify components:

```bash
# Shell and Tools
zsh --version
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

## 🚀 Quick Start Commands

```bash
# Install everything
./setup.sh all

# Install only essential tools
./setup.sh base shell

# Install development environment
./setup.sh base shell neovim node rust go

# Install with browsers and fonts
./setup.sh all
```

## ⚠️ Notes

- **Run script WITHOUT sudo** (script will ask for sudo when needed)
- **No SSH keys required** for basic installation
- **Homebrew is installed without sudo** as recommended
- **NVIDIA installation requires system restart**
- **Zsh becomes default shell** after installation
- **Browser installation is optional**
- **Some tools require logging out and back in** to take effect
- **Missing scripts are skipped gracefully** - won't break installation

## 🔄 Updates

To update your configuration:

```bash
# Update the setup scripts
cd ubuntu-setup
git pull

# Update Zsh configuration
cd ~/.config/zsh
git pull
```
