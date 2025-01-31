#!/bin/bash
set -e
# Source common functions
source ./common.sh

# Initialize Homebrew if not already in PATH
if ! command -v brew &>/dev/null; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
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
  
  # Get latest LTS version
  print_status "Getting latest Node.js LTS version..."
  NODE_LTS_VERSION=$(curl -s https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)][0].version')
  
  # Initialize fnm in current shell
  print_status "Initializing fnm environment..."
  eval "$(fnm env --shell=bash)"
  
  # Install Node.js LTS
  print_status "Installing Node.js $NODE_LTS_VERSION..."
  if ! fnm install --lts; then
    print_error "Failed to install Node.js LTS"
    exit 1
  fi
  fnm default lts-latest
  fnm use lts-latest
  
  # Configure npm
  print_status "Configuring npm..."
  npm config set prefix "$HOME/.local/share/npm"
  
  # Install global packages
  print_status "Installing global NPM packages..."
  npm install -g typescript yarn pnpm neovim
  
  # Add npm global bin to PATH temporarily
  export PATH="$HOME/.local/share/npm/bin:$PATH"
  
  # Configure pnpm
  print_status "Configuring pnpm..."
  pnpm config set store-dir "$HOME/.local/share/pnpm/store"
  
  # Run pnpm setup but don't try to source its output
  pnpm setup > /dev/null 2>&1 || true
  print_warning "Please run 'source ~/.bashrc' after installation to enable pnpm"
  
  print_success "Node.js environment setup complete"
  print_status "Node version: $(node --version)"
  print_status "NPM version: $(npm --version)"
  print_status "Yarn version: $(yarn --version)"
  print_status "PNPM version: $(pnpm --version)"
  print_status "fnm version: $(fnm --version)"
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_node_environment
fi
