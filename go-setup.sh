#!/bin/bash

set -e

# Source common functions
source ./common.sh

install_go_environment() {
  print_status "Installing Go environment"

  # Fetch latest Go version
  print_status "Checking latest Go version..."
  GO_LATEST=$(curl -s https://go.dev/dl/?mode=json | jq -r '.[0].version')
  GO_VERSION=${GO_LATEST#go} # Remove 'go' prefix

  # Check if Go is already installed
  if command -v go &>/dev/null; then
    CURRENT_VERSION=$(go version | awk '{print $3}')
    if [ "$CURRENT_VERSION" = "$GO_LATEST" ]; then
      print_status "Latest Go version $GO_LATEST is already installed"
      return 0
    fi
  fi

  # Download and install Go
  print_status "Downloading Go $GO_VERSION..."
  wget "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"

  print_status "Installing Go..."
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
  rm "go${GO_VERSION}.linux-amd64.tar.gz"

  # Set up Go environment if not already set
  if ! grep -q "GOPATH" "$HOME/.profile"; then
    echo 'export PATH=$PATH:/usr/local/go/bin' >>"$HOME/.profile"
    echo 'export GOPATH=$HOME/go' >>"$HOME/.profile"
    echo 'export PATH=$PATH:$GOPATH/bin' >>"$HOME/.profile"
  fi

  # Source the profile
  source "$HOME/.profile"

  # Install common Go tools
  print_status "Installing Go tools..."
  go install golang.org/x/tools/gopls@latest
  go install github.com/go-delve/delve/cmd/dlv@latest
  go install golang.org/x/tools/cmd/goimports@latest
  go install golang.org/x/tools/cmd/godoc@latest
  go install github.com/fatih/gomodifytags@latest
  go install github.com/cweill/gotests/gotests@latest
  go install github.com/x-motemen/gore/cmd/gore@latest

  print_success "Go environment setup complete"
  print_status "Go version: $(go version)"
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  maintain_sudo
  install_go_environment
fi
