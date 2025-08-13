#!/bin/bash

set -e

# Source common functions
source ./common.sh

install_rust_environment() {
    print_status "Installing Rust environment"
    
    # Install system dependencies for Rust compilation
    print_status "Installing system dependencies for Rust..."
    sudo apt update
    sudo apt install -y libssl-dev pkg-config build-essential libgit2-dev libcurl4-openssl-dev
    
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
    
    # Install common Rust tools with better error handling
    print_status "Installing Rust tools..."
    
    # Array of tools to install with their specific requirements
    local rust_tools=(
        "tree-sitter-cli"
        "cargo-edit"
        "cargo-watch" 
        "cargo-audit"
        "selene"
    )
    
    # Install each tool individually with error handling
    for tool in "${rust_tools[@]}"; do
        print_status "Installing $tool..."
        if cargo install --locked "$tool"; then
            print_success "$tool installed successfully"
        else
            print_warning "Failed to install $tool, skipping..."
        fi
    done
    
    # Try cargo-update with specific handling for OpenSSL issues
    print_status "Installing cargo-update..."
    
    # Set environment variables to help find OpenSSL
    export PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig:$PKG_CONFIG_PATH"
    export OPENSSL_DIR="/usr"
    export OPENSSL_LIB_DIR="/usr/lib/x86_64-linux-gnu"
    export OPENSSL_INCLUDE_DIR="/usr/include/openssl"
    
    if cargo install cargo-update; then
        print_success "cargo-update installed successfully"
    else
        print_warning "cargo-update failed with standard method, trying with system OpenSSL..."
        if OPENSSL_STATIC=0 cargo install cargo-update; then
            print_success "cargo-update installed with system OpenSSL"
        else
            print_warning "cargo-update installation failed completely, skipping..."
            print_status "You can try installing it later with: sudo apt install cargo-update"
        fi
    fi
    
    print_success "Rust environment setup complete"
    print_status "Rust version: $(rustc --version)"
    print_status "Cargo version: $(cargo --version)"
    
    # Check if tree-sitter was installed successfully
    if command -v tree-sitter &>/dev/null; then
        print_status "Tree-sitter CLI version: $(tree-sitter --version)"
    else
        print_warning "Tree-sitter CLI not available"
    fi
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_rust_environment
fi
