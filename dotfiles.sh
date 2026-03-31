#!/bin/bash
set -e

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
source "$SCRIPT_DIR/common.sh"

install_dotfiles_environment() {
    print_status "Installing server dotfiles (zsh, tmux, nvim)"

    mkdir -p ~/Projects

    backup_existing_configs
    setup_zsh_dotfiles
    setup_tmux_dotfiles
    setup_nvim_dotfiles

    print_success "Dotfiles environment setup complete"
    print_warning "Restart your shell or run 'exec zsh' to apply changes"
}

backup_existing_configs() {
    print_status "Backing up existing configurations..."

    local timestamp backup_dir
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_dir="$HOME/.config_backup_$timestamp"
    mkdir -p "$backup_dir"

    [ -f "$HOME/.zshrc" ]         && cp "$HOME/.zshrc"         "$backup_dir/"
    [ -f "$HOME/.tmux.conf" ]     && cp "$HOME/.tmux.conf"     "$backup_dir/"
    [ -d "$HOME/.config/nvim" ]   && cp -r "$HOME/.config/nvim" "$backup_dir/"

    if [ "$(ls -A "$backup_dir" 2>/dev/null)" ]; then
        print_success "Existing configs backed up to $backup_dir"
    else
        rmdir "$backup_dir"
        print_status "No existing configs found to back up"
    fi
}

setup_zsh_dotfiles() {
    local repo_dir="$HOME/Projects/zsh"

    print_status "Setting up Zsh dotfiles..."

    if ! command -v zsh &>/dev/null; then
        print_status "Installing Zsh..."
        sudo apt install -y zsh
    fi

    if [ ! -d "$repo_dir" ]; then
        print_status "Cloning Zsh dotfiles..."
        git clone https://github.com/y37y/zsh.git "$repo_dir"
    else
        print_status "Updating Zsh dotfiles..."
        git -C "$repo_dir" pull origin main || git -C "$repo_dir" pull origin master
    fi

    [ -L "$HOME/.zshrc" ] && rm "$HOME/.zshrc"

    if [ -f "$repo_dir/install.sh" ]; then
        chmod +x "$repo_dir/install.sh"
        (cd "$repo_dir" && ./install.sh)
    else
        ln -sf "$repo_dir/.zshrc" "$HOME/.zshrc"
        if [ -f "$repo_dir/starship.toml" ]; then
            mkdir -p ~/.config
            ln -sf "$repo_dir/starship.toml" "$HOME/.config/starship.toml"
        fi
    fi

    print_success "Zsh dotfiles setup complete"
}

setup_tmux_dotfiles() {
    local repo_dir="$HOME/Projects/tmux"

    print_status "Setting up Tmux dotfiles..."

    if [ ! -d "$repo_dir" ]; then
        print_status "Cloning Tmux dotfiles..."
        git clone https://github.com/y37y/tmux.git "$repo_dir"
    else
        print_status "Updating Tmux dotfiles..."
        git -C "$repo_dir" pull origin main || git -C "$repo_dir" pull origin master
    fi

    ln -sfn "$repo_dir" "$HOME/.config/tmux"

    [ -L "$HOME/.tmux.conf" ] && rm "$HOME/.tmux.conf"
    ln -sf "$HOME/.config/tmux/tmux.conf" "$HOME/.tmux.conf"
    print_success "Tmux configuration linked"

    if [ ! -d "$HOME/.config/tmux/plugins/tpm" ]; then
        print_status "Installing Tmux Plugin Manager..."
        git clone https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm"
        print_success "TPM installed. Run 'prefix + I' inside tmux to install plugins."
    else
        print_status "TPM already installed"
    fi
}

setup_nvim_dotfiles() {
    print_status "Setting up Neovim configuration..."

    # Install Neovim via Homebrew for latest version
    if ! command -v nvim &>/dev/null; then
        if command -v brew &>/dev/null; then
            print_status "Installing Neovim via Homebrew..."
            brew install neovim
        else
            print_warning "Homebrew not found. Install Neovim manually or run setup.sh first."
            return 0
        fi
    fi

    # Python provider
    if ! command -v python3 &>/dev/null; then
        sudo apt install -y python3-full python3-pip python3-venv
    fi

    if [ ! -d "$HOME/.neovim-venv" ]; then
        python3 -m venv "$HOME/.neovim-venv"
    fi
    "$HOME/.neovim-venv/bin/pip" install --quiet pynvim

    # Clone config
    if [ ! -d "$HOME/.config/nvim" ]; then
        print_status "Cloning Neovim configuration..."
        git clone --recursive https://github.com/y37y/nvim.git "$HOME/.config/nvim"
        (
            cd "$HOME/.config/nvim"
            git remote add upstream https://github.com/chaozwn/astronvim_user 2>/dev/null || true
            git fetch upstream
            git submodule update --init --recursive --force
        )
    else
        print_status "Neovim config already exists"
    fi

    print_success "Neovim dotfiles setup complete"
    print_warning "Run :checkhealth in Neovim to verify the installation"
}

update_all_dotfiles() {
    print_status "Updating all dotfiles repositories..."
    for repo in zsh tmux; do
        local repo_dir="$HOME/Projects/$repo"
        if [ -d "$repo_dir" ]; then
            print_status "Updating $repo..."
            git -C "$repo_dir" pull origin main || git -C "$repo_dir" pull origin master
            print_success "$repo updated"
        else
            print_warning "$repo not found at $repo_dir"
        fi
    done

    if [ -d "$HOME/.config/nvim" ]; then
        print_status "Updating nvim config..."
        git -C "$HOME/.config/nvim" pull origin main || git -C "$HOME/.config/nvim" pull origin master
        git -C "$HOME/.config/nvim" submodule update --init --recursive
        print_success "nvim config updated"
    fi

    print_success "All dotfiles updated"
}

show_dotfiles_status() {
    print_status "Dotfiles status:"

    for repo in zsh tmux; do
        [ -d "$HOME/Projects/$repo" ] \
            && print_success "$repo repo: cloned" \
            || print_error  "$repo repo: missing"
    done

    [ -d "$HOME/.config/nvim" ] \
        && print_success "nvim config: present" \
        || print_error  "nvim config: missing"

    echo ""
    print_status "Config file symlinks:"
    [ -f "$HOME/.zshrc" ]     && print_success ".zshrc linked"     || print_error ".zshrc missing"
    [ -f "$HOME/.tmux.conf" ] && print_success ".tmux.conf linked" || print_error ".tmux.conf missing"
}

case "${1:-}" in
    update) update_all_dotfiles ;;
    status) show_dotfiles_status ;;
    help|-h|--help)
        echo "Usage: $0 [update|status|help]"
        echo "  (none)  Install zsh, tmux, and nvim dotfiles"
        echo "  update  Pull latest from all repos"
        echo "  status  Show installation status"
        ;;
    *) install_dotfiles_environment ;;
esac
