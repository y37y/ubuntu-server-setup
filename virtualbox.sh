#!/bin/bash
set -e

# --- Resolve script dir & source common functions robustly ---
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

# Install or verify VirtualBox (latest available from Oracle repo)
install_virtualbox() {
  print_status "Checking for existing VirtualBox..."
  if command -v vboxmanage >/dev/null 2>&1; then
    local vnow
    vnow="$(vboxmanage -v || true)"
    print_success "VirtualBox already installed: ${vnow}"
    return 0
  fi

  print_status "Importing Oracle VirtualBox repo key..."
  wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc \
    | sudo gpg --dearmor --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg

  print_status "Adding Oracle VirtualBox repo..."
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] \
http://download.virtualbox.org/virtualbox/debian $(. /etc/os-release && echo "$VERSION_CODENAME") contrib" \
  | sudo tee /etc/apt/sources.list.d/virtualbox.list >/dev/null

  sudo apt update

  print_status "Installing VirtualBox (latest available)..."
  if sudo apt install -y virtualbox; then
    :
  else
    print_warning "'virtualbox' meta package not available; resolving highest version..."
    local candidate
    candidate="$(apt-cache search '^virtualbox-[0-9]+\.[0-9]+$' | awk '{print $1}' | sort -V | tail -n1)"
    if [ -z "$candidate" ]; then
      print_error "No VirtualBox packages found in repo"
      exit 1
    fi
    print_status "Installing ${candidate} ..."
    sudo apt install -y "$candidate"
  fi

  if ! command -v vboxmanage >/dev/null 2>&1; then
    print_error "VirtualBox installation failed"
    exit 1
  fi

  print_success "VirtualBox installed: $(vboxmanage -v)"
  print_status "Adding '$USER' to vboxusers group..."
  sudo usermod -aG vboxusers "$USER" || true
  print_warning "Log out/in for group membership to take effect."
}

# Install the matching Extension Pack for the installed VirtualBox
install_extpack() {
  if ! command -v vboxmanage >/dev/null 2>&1; then
    print_warning "VirtualBox not found; skipping Extension Pack."
    return 0
  fi

  # Already installed?
  if vboxmanage list extpacks | grep -q "Usable:\s*true"; then
    print_status "An Extension Pack is already installed and usable:"
    vboxmanage list extpacks
    return 0
  fi

  local vbox_version build url basefile altfile
  vbox_version="$(vboxmanage -v | cut -d'r' -f1)"      # e.g. 7.2.2
  build="$(vboxmanage -v | sed 's/.*r\([0-9]\+\).*/\1/')" # e.g. 170484

  basefile="Oracle_VirtualBox_Extension_Pack-${vbox_version}.vbox-extpack"
  altfile="Oracle_VirtualBox_Extension_Pack-${vbox_version}-${build}.vbox-extpack"

  print_status "Fetching Extension Pack for VirtualBox ${vbox_version} (build r${build})"
  url="https://download.virtualbox.org/virtualbox/${vbox_version}/${basefile}"
  if ! wget -q --show-progress -O "${basefile}" "${url}"; then
    print_warning "Base file not found, trying build-specific extpack..."
    url="https://download.virtualbox.org/virtualbox/${vbox_version}/${altfile}"
    wget -q --show-progress -O "${altfile}" "${url}"
  fi

  local extpack
  if [ -f "${basefile}" ]; then
    extpack="${basefile}"
  elif [ -f "${altfile}" ]; then
    extpack="${altfile}"
  else
    print_error "Failed to download Extension Pack for ${vbox_version}"
    return 1
  fi

  print_status "Installing Extension Pack (${extpack})..."
  # Interactive license acceptance (prompts 'y/n')
  # For non-interactive CI installs, pass a pre-approved hash:
  #   sudo vboxmanage extpack install --replace --accept-license=<HASH> "${extpack}"
  sudo vboxmanage extpack install --replace "${extpack}"

  rm -f "${extpack}"

  print_success "Extension Pack installed"
  vboxmanage list extpacks || true
}

main() {
  install_virtualbox
  install_extpack
  print_success "VirtualBox setup complete."
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
