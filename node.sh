#!/bin/bash

set -e

# Source common functions
source ./common.sh

# Initialize Homebrew if not already in PATH
if ! command -v brew &>/dev/null; then
    if [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

install_node_environment() {
    print_status "Installing Node.js environment"
    
    # Install fnm using Homebrew
    if ! command -v fnm &>/dev/null; then
        print_status "Installing fnm..."
        brew install fnm
    else
        print_status "fnm is already installed"
    fi
    
    # Create required directories
    mkdir -p "$HOME/.local/share/fnm"
    mkdir -p "$HOME/.local/share/npm"
    mkdir -p "$HOME/.local/share/pnpm"
    
    # Initialize fnm in current shell
    print_status "Initializing fnm environment..."
    eval "$(fnm env --shell=bash)"
    
    # Get latest LTS version with fallback
    print_status "Getting latest Node.js LTS version..."
    if command -v jq &>/dev/null; then
        NODE_LTS_VERSION=$(curl -s https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)][0].version' 2>/dev/null || echo "")
    else
        NODE_LTS_VERSION=""
    fi
    
    # Install Node.js LTS
    if [ -n "$NODE_LTS_VERSION" ]; then
        print_status "Installing Node.js $NODE_LTS_VERSION..."
    else
        print_status "Installing latest Node.js LTS..."
    fi
    
    if ! fnm install --lts; then
        print_error "Failed to install Node.js LTS"
        exit 1
    fi
    
    fnm default lts-latest
    fnm use lts-latest
    
    # Verify Node.js installation
    if ! command -v node &>/dev/null; then
        print_error "Node.js installation failed"
        exit 1
    fi
    
    # Configure npm
    print_status "Configuring npm..."
    npm config set prefix "$HOME/.local/share/npm"
    
    # Add npm global bin to PATH temporarily
    export PATH="$HOME/.local/share/npm/bin:$PATH"
    
    # Install global packages with error handling
    print_status "Installing global NPM packages..."
    local npm_packages=("typescript" "yarn" "pnpm" "neovim")
    
    for package in "${npm_packages[@]}"; do
        print_status "Installing $package..."
        if npm install -g "$package"; then
            print_success "$package installed successfully"
        else
            print_warning "Failed to install $package"
        fi
    done
    
    # Configure pnpm
    if command -v pnpm &>/dev/null; then
        print_status "Configuring pnpm..."
        pnpm config set store-dir "$HOME/.local/share/pnpm/store"
        
        # Run pnpm setup but don't try to source its output
        pnpm setup > /dev/null 2>&1 || true
        print_warning "Please run 'source ~/.bashrc' after installation to enable pnpm"
    fi
    
    print_success "Node.js environment setup complete"
    print_status "Node version: $(node --version)"
    print_status "NPM version: $(npm --version)"
    
    if command -v yarn &>/dev/null; then
        print_status "Yarn version: $(yarn --version)"
    fi
    
    if command -v pnpm &>/dev/null; then
        print_status "PNPM version: $(pnpm --version)"
    fi
    
    print_status "fnm version: $(fnm --version)"
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_node_environment
fi
