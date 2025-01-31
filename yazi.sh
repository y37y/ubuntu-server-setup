#!/bin/bash

# Source common functions if available
if [ -f "./common.sh" ]; then
    source ./common.sh
else
    # Minimal implementation of required functions
    print_status() {
        echo -e "\033[1;34m>>>\033[0m $1"
    }

    print_success() {
        echo -e "\033[1;32m✓\033[0m $1"
    }

    print_error() {
        echo -e "\033[1;31m✗\033[0m $1"
    }

    print_warning() {
        echo -e "\033[1;33m!\033[0m $1"
    }
fi

# Check if script is run with sudo
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script with sudo or as root."
    exit 1
fi

# Check if Homebrew is installed
check_homebrew() {
    if ! command -v brew &>/dev/null; then
        print_error "Homebrew is not installed. Please install it first."
        print_status "You can install Homebrew using:"
        echo "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
}

install_yazi_dependencies() {
    print_status "Installing Yazi dependencies..."

    # Install all dependencies via Homebrew
    brew install file yazi ffmpegthumbnailer unar jq poppler fd ripgrep fzf zoxide exiftool \
        bat lazygit lazydocker sevenzip imagemagick font-symbols-only-nerd-font \
        ripgrep-all mediainfo glow eza

    # Add file-formula to PATH
    if ! grep -q "file-formula" ~/.zshrc; then
        echo 'export PATH="/opt/homebrew/opt/file-formula/bin:$PATH"' >> ~/.zshrc
    fi

    print_success "Dependencies installed successfully"
}

configure_yazi() {
    print_status "Configuring Yazi..."

    # Backup existing configuration
    if [ -d ~/.config/yazi ]; then
        mv ~/.config/yazi ~/.config/yazi.bak
    fi

    # Clone Yazi configuration
    git clone --depth 1 https://github.com/y37y/yazi.git ~/.config/yazi

    print_success "Yazi configuration complete"
}

setup_shell_integration() {
    print_status "Setting up shell integration..."

    # Setup for bash
    if [ -f ~/.bashrc ]; then
        if ! grep -q "function ff()" ~/.bashrc; then
            cat >> ~/.bashrc << 'EOL'

# Yazi integration
function ff() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}
EOL
        fi
    fi

    # Setup for zsh
    if [ -f ~/.zshrc ]; then
        if ! grep -q "function ff()" ~/.zshrc; then
            cat >> ~/.zshrc << 'EOL'

# Yazi integration
function ff() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# FZF configuration
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS \
    --highlight-line \
    --info=inline-right \
    --ansi \
    --layout=reverse \
    --border=none \
    --color=bg+:#2d3f76 \
    --color=bg:#1e2030 \
    --color=border:#589ed7 \
    --color=fg:#c8d3f5 \
    --color=gutter:#1e2030 \
    --color=header:#ff966c \
    --color=hl+:#65bcff \
    --color=hl:#65bcff \
    --color=info:#545c7e \
    --color=marker:#ff007c \
    --color=pointer:#ff007c \
    --color=prompt:#65bcff \
    --color=query:#c8d3f5:regular \
    --color=scrollbar:#589ed7 \
    --color=separator:#ff966c \
    --color=spinner:#ff007c"

# Eza aliases
alias ls="eza --icons"
alias ll="eza --icons --long --header"
alias la="eza --icons --long --header --all"
alias lg="eza --icons --long --header --all --git"
alias lt="eza --tree -L 2 --icons"

# Zoxide initialization
eval "$(zoxide init zsh)"
EOL
        fi
    fi

    print_success "Shell integration complete"
}

verify_installation() {
    print_status "Verifying installation..."

    local tools=(
        "file" "ffmpegthumbnailer" "unar" "jq" "pdfinfo" "fd" "rg" 
        "fzf" "zoxide" "exiftool" "bat" "lazygit" "lazydocker" 
        "7z" "convert" "mediainfo" "glow" "eza" "yazi"
    )

    local missing=0

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            print_error "$tool not found"
            missing=1
        else
            print_success "$tool installed"
        fi
    done

    if [ $missing -eq 1 ]; then
        print_warning "Some components are missing. Please check the error messages above."
    else
        print_success "All components are installed correctly"
    fi
}

main() {
    print_status "Starting Yazi setup..."
    
    # Check for Homebrew
    check_homebrew
    
    # Install components
    install_yazi_dependencies
    configure_yazi
    setup_shell_integration
    verify_installation

    print_success "Yazi setup complete!"
    print_status "To upgrade Yazi plugins use:"
    echo "ya pack -a lpnh/fg  # Add plugin"
    echo "ya pack -i          # Install plugin"
    echo "ya pack -u          # Upgrade plugin"
    print_warning "Please restart your shell or source your shell's configuration file to use the new configuration"
    print_warning "You can start Yazi by using the 'ff' command"
}

main "$@"
