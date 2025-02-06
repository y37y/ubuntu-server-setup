#!/bin/bash

set -e

# Source common functions
source ./common.sh

install_rust_environment() {
  print_status "Installing Rust environment"

  if ! command -v rustc &>/dev/null; then
    print_status "Installing Rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
  else
    print_status "Rust is already installed, updating..."
    rustup update
  fi

  # Add commonly used components
  print_status "Installing Rust components..."
  rustup component add rust-analyzer rustfmt clippy

  # Install common Rust tools
  print_status "Installing Rust tools..."
  # Install tree-sitter-cli with --locked for reproducible builds
  cargo install --locked tree-sitter-cli
  # Install other tools
  cargo install cargo-update cargo-edit cargo-watch cargo-audit selene

  print_success "Rust environment setup complete"
  print_status "Rust version: $(rustc --version)"
  print_status "Cargo version: $(cargo --version)"
  print_status "Tree-sitter CLI version: $(tree-sitter --version)"
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_rust_environment
fi
