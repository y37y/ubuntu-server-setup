#!/usr/bin/env bash
set -euo pipefail

# --- boilerplate messages ---
blue() { echo -e "\033[1;34m>>>\033[0m $*"; }
green() { echo -e "\033[1;32m✓\033[0m $*"; }
red()   { echo -e "\033[1;31m✗\033[0m $*"; }
yellow(){ echo -e "\033[1;33m!\033[0m $*"; }

trap 'red "Error on line $LINENO"; exit 1' ERR

# --- resolve repo dir + optional common.sh ---
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/common.sh"
fi

usage() {
cat <<'EOF'
Usage: nvidia.sh [options]

Options:
  --driver <ver>       Install a specific NVIDIA driver (e.g. 535, 550, 560).
  --hold-driver        Mark the installed driver on hold (prevents apt upgrades).
  --cuda <ver>         Install CUDA Toolkit (adds nvcc) for a specific version (e.g. 12.0, 12.4, 12.6).
  --container          Install NVIDIA Container Toolkit (for Docker/Podman).
  --no-confirm         Non-interactive (assume "yes" where safe).
  -h, --help           Show this help.

Notes:
- Driver install uses Ubuntu packages: nvidia-driver-<ver>.
- CUDA install uses NVIDIA's repo and installs cuda-toolkit-<ver>.
- Script will refuse CUDA install if your driver is too old for that CUDA version.
Compatibility (rule of thumb):
  Driver 535  -> up to CUDA 12.2
  Driver 550  -> up to CUDA 12.4
  Driver 560+ -> up to CUDA 12.6
EOF
}

# --- args ---
DRIVER_VER=""
CUDA_VER=""
INSTALL_CONTAINER="no"
HOLD_DRIVER="no"
ASSUME_YES="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --driver) DRIVER_VER="$2"; shift 2 ;;
    --cuda) CUDA_VER="$2"; shift 2 ;;
    --container) INSTALL_CONTAINER="yes"; shift ;;
    --hold-driver) HOLD_DRIVER="yes"; shift ;;
    --no-confirm) ASSUME_YES="yes"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) red "Unknown option: $1"; usage; exit 1 ;;
  esac
done

apt_y() { if [[ "$ASSUME_YES" == "yes" ]]; then echo "-y"; else echo ""; fi; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    red "This action requires sudo/root."
    exit 1
  fi
}

ensure_apt_ready() {
  sudo bash -c 'while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 1; done'
  sudo apt update
}

get_installed_driver_major() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1 | cut -d. -f1
  else
    echo ""
  fi
}

check_cuda_compat() {
  local drv_major="$1" cuda="$2"
  # crude guardrails
  case "$drv_major" in
    "" ) yellow "No NVIDIA driver detected yet; CUDA will likely pull a newer driver. This script avoids that."; return 1;;
    530|531|532|533|534|535)  # 535 ~ CUDA ≤ 12.2
      [[ "$cuda" == 12.0 || "$cuda" == 12.1 || "$cuda" == 12.2 ]] && return 0 || return 1 ;;
    550) # 550 ~ CUDA ≤ 12.4
      [[ "$cuda" == 12.0 || "$cuda" == 12.1 || "$cuda" == 12.2 || "$cuda" == 12.3 || "$cuda" == 12.4 ]] && return 0 || return 1 ;;
    560|561|562|563|564|565|566|567|568|569) # 560+ ~ CUDA ≤ 12.6
      [[ "$cuda" == 12.0 || "$cuda" == 12.1 || "$cuda" == 12.2 || "$cuda" == 12.3 || "$cuda" == 12.4 || "$cuda" == 12.5 || "$cuda" == 12.6 ]] && return 0 || return 1 ;;
    *) yellow "Unknown driver major '$drv_major', proceeding cautiously"; return 0 ;;
  esac
}

install_driver() {
  local ver="$1"
  require_root
  ensure_apt_ready
  blue "Installing NVIDIA driver $ver ..."
  sudo apt install $(apt_y) "nvidia-driver-$ver"
  green "Driver install done."
  if [[ "$HOLD_DRIVER" == "yes" ]]; then
    blue "Holding nvidia-driver-$ver to prevent upgrades ..."
    sudo apt-mark hold "nvidia-driver-$ver"
    green "Driver is on hold."
  fi
}

install_cuda_repo_2404() {
  local cuda_ver="$1"  # e.g. 12.0 / 12.4 / 12.6
  require_root
  ensure_apt_ready
  blue "Adding NVIDIA CUDA repository for Ubuntu 24.04 ..."
  # Pin and repo package for specific CUDA branch:
  # Use the "local repo" installer to avoid surprise driver bumps.
  local base="https://developer.download.nvidia.com/compute/cuda"
  local branch="${cuda_ver//./-}"                # 12.6 -> 12-6
  # try to fetch the "local" repo deb name that matches Ubuntu 24.04
  local deb="cuda-repo-ubuntu2404-${branch}-local_*.deb"

  # Fallback to known filenames if wildcard fails:
  # You can update these as needed when you bump versions.
  case "$cuda_ver" in
    12.0) deb="cuda-repo-ubuntu2404-12-0-local_12.0.0-1_amd64.deb" ;;
    12.4) deb="cuda-repo-ubuntu2404-12-4-local_12.4.0-1_amd64.deb" ;;
    12.6) deb="cuda-repo-ubuntu2404-12-6-local_12.6.0-1_amd64.deb" ;;
  esac

  local url="$base/${cuda_ver}/local_installers/${deb}"
  blue "Downloading $url"
  wget -q "$url" -O "/tmp/${deb}" || { red "Failed to download CUDA repo package"; exit 1; }
  sudo dpkg -i "/tmp/${deb}" || true
  # add keyring if present
  if compgen -G "/var/cuda-repo-ubuntu2404-*/cuda-*-keyring.gpg" > /dev/null; then
    sudo cp /var/cuda-repo-ubuntu2404-*/cuda-*-keyring.gpg /usr/share/keyrings/ || true
  fi
  sudo apt update
}

install_cuda_toolkit() {
  local cuda_ver="$1" # 12.0 / 12.4 / 12.6
  local drv_major
  drv_major="$(get_installed_driver_major)"
  blue "Detected driver major: ${drv_major:-none}"

  if ! check_cuda_compat "$drv_major" "$cuda_ver"; then
    red "Refusing to install CUDA $cuda_ver because it likely requires a newer driver than $drv_major."
    red "Either install a newer driver with --driver, or choose an older CUDA (e.g. 12.0/12.2 for driver 535)."
    exit 1
  fi

  require_root
  install_cuda_repo_2404 "$cuda_ver"

  blue "Installing CUDA Toolkit $cuda_ver (nvcc, libraries) …"
  sudo apt install $(apt_y) "cuda-toolkit-${cuda_ver//./-}"

  # Add PATH and LD_LIBRARY_PATH (idempotent)
  local cudabase="/usr/local/cuda-${cuda_ver}"
  local line1="export PATH=${cudabase}/bin:\$PATH"
  local line2="export LD_LIBRARY_PATH=${cudabase}/lib64:\$LD_LIBRARY_PATH"

  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    grep -qxF "$line1" "$rc" 2>/dev/null || echo "$line1" >> "$rc"
    grep -qxF "$line2" "$rc" 2>/dev/null || echo "$line2" >> "$rc"
  done

  green "CUDA $cuda_ver installed."
  yellow "Open a new shell or: source ~/.bashrc (or ~/.zshrc) to pick up nvcc in PATH."
}

install_container_toolkit() {
  require_root
  ensure_apt_ready
  blue "Installing NVIDIA Container Toolkit …"
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
  sudo apt update
  sudo apt install $(apt_y) nvidia-container-toolkit
  green "Container Toolkit installed. Configure Docker with: sudo nvidia-ctk runtime configure && sudo systemctl restart docker"
}

# --- main flow ---

blue "NVIDIA setup helper"

if [[ -n "$DRIVER_VER" ]]; then
  blue "Requested driver: $DRIVER_VER"
  install_driver "$DRIVER_VER"
else
  if command -v nvidia-smi >/dev/null 2>&1; then
    blue "Driver already present: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1)"
  else
    yellow "No driver requested and none detected. Skipping driver install."
  fi
fi

if [[ -n "$CUDA_VER" ]]; then
  install_cuda_toolkit "$CUDA_VER"
else
  blue "CUDA not requested. Skipping nvcc/Toolkit install."
fi

if [[ "$INSTALL_CONTAINER" == "yes" ]]; then
  install_container_toolkit
fi

green "Done."

