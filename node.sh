#!/bin/bash
set -e

# --- Resolve script dir & source common functions robustly ---
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

# --- Initialize Homebrew in this shell if needed ---
if ! command -v brew &>/dev/null; then
  if [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
fi

install_node_environment() {
  # Full skip if Node + fnm + pnpm are already present
  if command -v node &>/dev/null && command -v fnm &>/dev/null && command -v pnpm &>/dev/null; then
    print_status "Node.js environment already installed: $(node --version)"
    return 0
  fi

  print_status "Installing Node.js environment"

  # Install fnm via Homebrew if missing
  if ! command -v fnm &>/dev/null; then
    print_status "Installing fnm..."
    brew install fnm
  else
    print_status "fnm is already installed"
  fi

  # Ensure expected directories exist
  mkdir -p "$HOME/.local/share/fnm" \
           "$HOME/.local/share/npm" \
           "$HOME/.local/share/pnpm"

  # Initialize fnm in current shell and persist for future shells
  print_status "Initializing fnm environment..."
  eval "$(fnm env --shell=bash)"
  grep -q 'fnm env --shell=bash' "$HOME/.bashrc" || echo 'eval "$(fnm env --shell=bash)"' >> "$HOME/.bashrc"
  if [ -f "$HOME/.zshrc" ] || command -v zsh >/dev/null 2>&1; then
    grep -q 'fnm env --shell=zsh'  "$HOME/.zshrc" 2>/dev/null || echo 'eval "$(fnm env --shell=zsh)"'  >> "$HOME/.zshrc"
  fi

  # Get latest LTS (optional, just for logging)
  print_status "Getting latest Node.js LTS version..."
  if command -v jq &>/dev/null; then
    NODE_LTS_VERSION=$(curl -s https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)][0].version' 2>/dev/null || echo "")
  else
    NODE_LTS_VERSION=""
  fi
  if [ -n "$NODE_LTS_VERSION" ]; then
    print_status "Installing Node.js $NODE_LTS_VERSION (LTS)"
  else
    print_status "Installing latest Node.js LTS..."
  fi

  # Install and activate Node LTS
  if ! fnm install --lts; then
    print_error "Failed to install Node.js LTS"
    exit 1
  fi
  fnm default lts-latest
  fnm use lts-latest

  # Verify Node is available
  if ! command -v node &>/dev/null; then
    print_error "Node.js installation failed"
    exit 1
  fi

  # Configure npm prefix to user space and expose bin in PATH for this run
  print_status "Configuring npm..."
  npm config set prefix "$HOME/.local/share/npm"
  export PATH="$HOME/.local/share/npm/bin:$PATH"

  # Catch-up: ensure Neovim's Node providers are installed now that Node exists
  if command -v npm >/dev/null 2>&1; then
    print_status "Installing Neovim Node providers..."
    npm install -g neovim tree-sitter-cli @styled/typescript-styled-plugin || print_warning "Provider install had non-fatal errors"
  fi

  # Global NPM tools
  print_status "Installing global NPM packages..."
  local npm_packages=( "typescript" "yarn" "pnpm" "neovim" )
  for package in "${npm_packages[@]}"; do
    print_status "Installing $package..."
    if npm install -g "$package"; then
      print_success "$package installed successfully"
    else
      print_warning "Failed to install $package"
    fi
  done

  # Configure pnpm store
  if command -v pnpm &>/dev/null; then
    print_status "Configuring pnpm..."
    pnpm config set store-dir "$HOME/.local/share/pnpm/store"
    pnpm setup > /dev/null 2>&1 || true
    print_warning "If pnpm isn't available in new shells, run: source ~/.bashrc (or ~/.zshrc)"
  fi

  # Final versions
  print_success "Node.js environment setup complete"
  print_status "Node version: $(node --version)"
  print_status "NPM version: $(npm --version)"
  command -v yarn  >/dev/null 2>&1 && print_status "Yarn version: $(yarn --version)"
  command -v pnpm  >/dev/null 2>&1 && print_status "PNPM version: $(pnpm --version)"
  print_status "fnm version: $(fnm --version)"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_node_environment
fi
