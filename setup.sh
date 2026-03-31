#!/bin/bash
set -e

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script with sudo or as root."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Homebrew (used by several subscripts for latest tool versions)
# ---------------------------------------------------------------------------
ensure_brew_env() {
    command -v brew &>/dev/null && return 0
    [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ] && \
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && return 0
    print_error "Homebrew not found. Run option 1 (Essential packages) first."
    exit 1
}

install_homebrew() {
    if command -v brew &>/dev/null; then
        print_status "Homebrew already installed"
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null || true
        return 0
    fi

    print_status "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        for rc in ~/.bashrc ~/.profile ~/.zshrc; do
            [ -f "$rc" ] || touch "$rc"
            grep -q 'linuxbrew' "$rc" || \
                echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$rc"
        done
        print_success "Homebrew installed"
    else
        print_error "Homebrew installation failed"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# 1. Essential packages
# ---------------------------------------------------------------------------
install_essential() {
    print_status "Installing essential system packages..."
    sudo apt-get update
    sudo apt-get install -y \
        build-essential curl git wget ca-certificates unzip jq \
        pkg-config libssl-dev libgit2-dev libcurl4-openssl-dev \
        python3-full python3-pip python3-venv \
        lua5.1 liblua5.1-0-dev luarocks \
        fuse libfuse2 shellcheck htop btop iotop \
        net-tools dnsutils lsof pciutils usbutils \
        tmux zsh

    install_homebrew
    ensure_brew_env

    brew install \
        gcc fzf eza zoxide ripgrep fd starship \
        jq yq bat duf bottom procs dust \
        git git-lfs lazygit lazydocker gh difftastic \
        ghq tree wget httpie tldr tokei hyperfine \
        neovim tree-sitter luajit \
        atuin

    mkdir -p ~/.local/bin
    ln -sf "$(brew --prefix)/bin/bat" ~/.local/bin/batcat 2>/dev/null || true

    git lfs install

    print_success "Essential packages installed"
}

# ---------------------------------------------------------------------------
# 2. Zsh setup
# ---------------------------------------------------------------------------
setup_zsh() {
    ensure_brew_env
    print_status "Setting up Zsh environment"

    if ! dpkg -l zsh &>/dev/null 2>/dev/null | grep -q '^ii'; then
        sudo apt install -y zsh
    fi

    # Add apt zsh to /etc/shells and change default shell
    local zsh_path
    zsh_path=$(which zsh)
    grep -q "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells
    if [[ "$SHELL" != "$zsh_path" ]]; then
        chsh -s "$zsh_path"
        print_warning "Default shell changed to zsh — log out and back in to apply"
    else
        print_status "Zsh is already the default shell"
    fi

    # Install Atuin for shell history if missing
    if ! command -v atuin &>/dev/null; then
        print_status "Installing Atuin..."
        curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
    fi

    print_success "Zsh environment setup complete"
}

# ---------------------------------------------------------------------------
# 3. Docker
# ---------------------------------------------------------------------------
install_docker() {
    bash "$SCRIPT_DIR/docker.sh"
}

# ---------------------------------------------------------------------------
# 4. NVIDIA drivers + CUDA
# ---------------------------------------------------------------------------
install_nvidia() {
    if command -v whiptail >/dev/null 2>&1; then
        local cuda_ver
        cuda_ver=$(whiptail --title "NVIDIA / CUDA Setup" \
            --inputbox "CUDA version to install (e.g. 12.8, 12.6, or leave blank to skip CUDA):" \
            10 60 "12.8" 3>&1 1>&2 2>&3) || cuda_ver=""

        local extra_flags=""
        if whiptail --title "NVIDIA Container Toolkit" --yesno \
            "Install NVIDIA Container Toolkit for Docker GPU support?" 8 60; then
            extra_flags="--container"
        fi

        local cuda_flag=""
        [ -n "$cuda_ver" ] && cuda_flag="--cuda $cuda_ver"

        bash "$SCRIPT_DIR/nvidia.sh" --auto $cuda_flag $extra_flags --no-confirm
    else
        bash "$SCRIPT_DIR/nvidia.sh" --auto --cuda 12.8 --container --no-confirm
    fi
}

# ---------------------------------------------------------------------------
# 5. LLM Inference
# ---------------------------------------------------------------------------
install_inference() {
    if command -v whiptail >/dev/null 2>&1; then
        local choices
        choices=$(whiptail --title "LLM Inference Tools" --checklist \
            "Select inference tools to install:" 16 60 3 \
            "ollama"    "Ollama (easiest, GPU auto-detected)" ON \
            "llama-cpp" "llama.cpp (CUDA build)"              OFF \
            "vllm"      "vLLM (requires CUDA)"                OFF \
            3>&1 1>&2 2>&3) || return 0

        local flags=""
        echo "$choices" | grep -q "ollama"    && flags="$flags --ollama"
        echo "$choices" | grep -q "llama-cpp" && flags="$flags --llama-cpp"
        echo "$choices" | grep -q "vllm"      && flags="$flags --vllm"
        [ -z "$flags" ] && return 0
        bash "$SCRIPT_DIR/inference.sh" $flags
    else
        bash "$SCRIPT_DIR/inference.sh" --ollama
    fi
}

# ---------------------------------------------------------------------------
# 6. Network (Tailscale + SSH hardening)
# ---------------------------------------------------------------------------
install_network() {
    if command -v whiptail >/dev/null 2>&1; then
        local choices
        choices=$(whiptail --title "Network Setup" --checklist \
            "Select network tools to configure:" 14 60 2 \
            "tailscale"  "Tailscale VPN"                         ON \
            "ssh-harden" "SSH hardening (disables password auth)" OFF \
            3>&1 1>&2 2>&3) || return 0

        local flags=""
        echo "$choices" | grep -q "tailscale"  && flags="$flags --tailscale"
        echo "$choices" | grep -q "ssh-harden" && flags="$flags --ssh-harden"
        [ -z "$flags" ] && return 0
        bash "$SCRIPT_DIR/network.sh" $flags
    else
        bash "$SCRIPT_DIR/network.sh" --tailscale
    fi
}

# ---------------------------------------------------------------------------
# 7. Dotfiles (zsh, tmux, nvim)
# ---------------------------------------------------------------------------
install_dotfiles() {
    bash "$SCRIPT_DIR/dotfiles.sh"
}

# ---------------------------------------------------------------------------
# 8. Node.js
# ---------------------------------------------------------------------------
install_node() {
    bash "$SCRIPT_DIR/node.sh"
}

# ---------------------------------------------------------------------------
# 9. Rust
# ---------------------------------------------------------------------------
install_rust() {
    bash "$SCRIPT_DIR/rust.sh"
}

# ---------------------------------------------------------------------------
# 10. Go
# ---------------------------------------------------------------------------
install_go() {
    bash "$SCRIPT_DIR/go.sh"
}

# ---------------------------------------------------------------------------
# 11. AI Agent tools (Claude Code etc.)
# ---------------------------------------------------------------------------
install_agent_tools() {
    bash "$SCRIPT_DIR/agent.sh"
}

# ---------------------------------------------------------------------------
# Interactive menu
# ---------------------------------------------------------------------------
show_menu() {
    if ! command -v whiptail >/dev/null 2>&1; then
        sudo apt-get install -y whiptail
    fi

    local choices
    choices=$(whiptail --title "Ubuntu Server Setup — LLM Inference" \
        --checklist "Select components to install:\n(Space to toggle, Enter to confirm)" \
        28 70 11 \
        "1" "Essential packages + Homebrew + base tools" ON  \
        "2" "Zsh (default shell + Atuin history)"        ON  \
        "3" "Docker Engine"                              ON  \
        "4" "NVIDIA drivers + CUDA"                     ON  \
        "5" "LLM Inference (Ollama / llama.cpp / vLLM)" ON  \
        "6" "Network (Tailscale, SSH hardening)"        OFF \
        "7" "Dotfiles (zsh, tmux, nvim)"                OFF \
        "8" "Node.js (fnm + LTS)"                       OFF \
        "9" "Rust (rustup)"                             OFF \
        "10" "Go"                                       OFF \
        "11" "AI Agent tools (Claude Code)"             OFF \
        3>&1 1>&2 2>&3) || exit 0

    maintain_sudo

    echo "$choices" | grep -q '"1"'  && install_essential
    echo "$choices" | grep -q '"2"'  && setup_zsh
    echo "$choices" | grep -q '"3"'  && install_docker
    echo "$choices" | grep -q '"4"'  && install_nvidia
    echo "$choices" | grep -q '"5"'  && install_inference
    echo "$choices" | grep -q '"6"'  && install_network
    echo "$choices" | grep -q '"7"'  && install_dotfiles
    echo "$choices" | grep -q '"8"'  && install_node
    echo "$choices" | grep -q '"9"'  && install_rust
    echo "$choices" | grep -q '"10"' && install_go
    echo "$choices" | grep -q '"11"' && install_agent_tools

    print_success "Setup complete!"
    print_warning "Reboot recommended after installing NVIDIA drivers."
}

# ---------------------------------------------------------------------------
# CLI argument mode (non-interactive)
# ---------------------------------------------------------------------------
run_from_args() {
    maintain_sudo
    for arg in "$@"; do
        case "$arg" in
            --essential)   install_essential ;;
            --zsh)         setup_zsh ;;
            --docker)      install_docker ;;
            --nvidia)      install_nvidia ;;
            --inference)   install_inference ;;
            --network)     install_network ;;
            --dotfiles)    install_dotfiles ;;
            --node)        install_node ;;
            --rust)        install_rust ;;
            --go)          install_go ;;
            --agent)       install_agent_tools ;;
            --all-server)
                install_essential
                setup_zsh
                install_docker
                install_nvidia
                install_inference
                ;;
            -h|--help)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options (combine as needed):"
                echo "  --essential    Essential packages + Homebrew"
                echo "  --zsh          Zsh + Atuin"
                echo "  --docker       Docker Engine"
                echo "  --nvidia       NVIDIA drivers + CUDA (interactive)"
                echo "  --inference    LLM Inference tools (interactive)"
                echo "  --network      Tailscale + SSH hardening (interactive)"
                echo "  --dotfiles     Dotfiles (zsh, tmux, nvim)"
                echo "  --node         Node.js"
                echo "  --rust         Rust"
                echo "  --go           Go"
                echo "  --agent        AI agent tools"
                echo "  --all-server   Essential + Zsh + Docker + NVIDIA + Inference"
                echo ""
                echo "No arguments: interactive whiptail menu"
                exit 0
                ;;
            *) print_error "Unknown option: $arg. Use --help for usage." ;;
        esac
    done
    print_success "Setup complete!"
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
check_system

if [ $# -eq 0 ]; then
    show_menu
else
    run_from_args "$@"
fi
