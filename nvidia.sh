#!/usr/bin/env bash
set -euo pipefail

# --- boilerplate messages ---
blue()  { echo -e "\033[1;34m>>>\033[0m $*"; }
green() { echo -e "\033[1;32m✓\033[0m $*"; }
red()   { echo -e "\033[1;31m✗\033[0m $*"; }
yellow(){ echo -e "\033[1;33m!\033[0m $*"; }

trap 'red "Error on line $LINENO"; exit 1' ERR

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
  source "$SCRIPT_DIR/common.sh"
fi

usage() {
cat <<'EOF'
Usage: nvidia.sh [options]

Options:
  --auto               Auto-detect and install recommended NVIDIA driver.
  --driver <ver>       Install a specific NVIDIA driver (e.g. 535, 550, 570).
  --hold-driver        Mark the installed driver on hold (prevents apt upgrades).
  --cuda [ver]         Install CUDA Toolkit. Version is optional; if omitted,
                       the highest compatible version for the installed driver
                       is chosen automatically (e.g. driver 570+ → 12.8).
  --container          Install NVIDIA Container Toolkit (for Docker).
  --no-confirm         Non-interactive (assume "yes" where safe).
  -h, --help           Show this help.

Notes:
- --auto uses ubuntu-drivers to find and install the recommended driver.
- CUDA install uses NVIDIA's network repository (no large local .deb download).
- Script refuses CUDA install if your driver is too old for that CUDA version.

Compatibility (rule of thumb):
  Driver 535  -> up to CUDA 12.2
  Driver 550  -> up to CUDA 12.4
  Driver 560  -> up to CUDA 12.6
  Driver 570+ -> up to CUDA 12.8

Recommended for RTX 4090: --auto --cuda --container
EOF
}

# --- args ---
DRIVER_VER=""
CUDA_VER=""        # empty = not requested; "auto" = requested, version TBD
INSTALL_CONTAINER="no"
HOLD_DRIVER="no"
ASSUME_YES="no"
AUTO_DRIVER="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto)         AUTO_DRIVER="yes"; shift ;;
    --driver)       DRIVER_VER="$2"; shift 2 ;;
    --cuda)
      # Optional version argument: consume next token only if it looks like a
      # version number (digits and dots), not another flag.
      if [[ -n "${2:-}" && "${2}" =~ ^[0-9]+\.[0-9]+ ]]; then
        CUDA_VER="$2"; shift 2
      else
        CUDA_VER="auto"; shift   # version will be resolved from driver later
      fi ;;
    --container)    INSTALL_CONTAINER="yes"; shift ;;
    --hold-driver)  HOLD_DRIVER="yes"; shift ;;
    --no-confirm)   ASSUME_YES="yes"; shift ;;
    -h|--help)      usage; exit 0 ;;
    *) red "Unknown option: $1"; usage; exit 1 ;;
  esac
done

apt_y() { [[ "$ASSUME_YES" == "yes" ]] && echo "-y" || echo ""; }

ensure_apt_ready() {
  sudo bash -c 'while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 1; done'
  sudo apt-get update
}

get_installed_driver_major() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null \
      | head -n1 | cut -d. -f1
  else
    echo ""
  fi
}

# Detect recommended driver version from ubuntu-drivers
detect_recommended_driver() {
  if ! command -v ubuntu-drivers >/dev/null 2>&1; then
    blue "Installing ubuntu-drivers-common..."
    sudo apt-get install -y ubuntu-drivers-common
  fi

  blue "Detecting recommended NVIDIA driver..."
  local recommended
  # ubuntu-drivers devices output has a "recommended" line like:
  # driver   : nvidia-driver-570 - third-party free recommended
  recommended=$(ubuntu-drivers devices 2>/dev/null \
    | grep -i "recommended" \
    | grep -oP 'nvidia-driver-\K[0-9]+' \
    | head -n1)

  if [[ -z "$recommended" ]]; then
    # Fallback: pick the highest available nvidia-driver-* package
    recommended=$(apt-cache search '^nvidia-driver-[0-9]+$' 2>/dev/null \
      | grep -oP 'nvidia-driver-\K[0-9]+' \
      | sort -n | tail -n1)
  fi

  if [[ -z "$recommended" ]]; then
    red "Could not detect a recommended NVIDIA driver. Use --driver <ver> to specify one."
    exit 1
  fi

  echo "$recommended"
}

# Return the highest CUDA version compatible with a given driver major.
best_cuda_for_driver() {
  local drv_major="$1"
  case "$drv_major" in
    530|531|532|533|534|535) echo "12.2" ;;
    540|541|542|543|544|545|546|547|548|549|550) echo "12.4" ;;
    560|561|562|563|564|565|566|567|568|569) echo "12.6" ;;
    *) echo "12.8" ;;   # 570+ and any future drivers
  esac
}

check_cuda_compat() {
  local drv_major="$1" cuda="$2"
  case "$drv_major" in
    "")
      yellow "No NVIDIA driver detected; install a driver first with --driver or --auto."
      return 1 ;;
    530|531|532|533|534|535)
      [[ "$cuda" == 12.0 || "$cuda" == 12.1 || "$cuda" == 12.2 ]] && return 0 || return 1 ;;
    550)
      [[ "$cuda" == 12.0 || "$cuda" == 12.1 || "$cuda" == 12.2 || \
         "$cuda" == 12.3 || "$cuda" == 12.4 ]] && return 0 || return 1 ;;
    560|561|562|563|564|565|566|567|568|569)
      [[ "$cuda" == 12.0 || "$cuda" == 12.1 || "$cuda" == 12.2 || \
         "$cuda" == 12.3 || "$cuda" == 12.4 || "$cuda" == 12.5 || \
         "$cuda" == 12.6 ]] && return 0 || return 1 ;;
    570|571|572|573|574|575|576|577|578|579|58*)
      # Driver 570+ supports CUDA up to 12.8
      [[ "$cuda" == 12.* ]] && return 0 || return 1 ;;
    *)
      yellow "Unknown driver major '$drv_major', proceeding cautiously"
      return 0 ;;
  esac
}

install_driver() {
  local ver="$1"
  blue "Installing NVIDIA driver $ver..."
  ensure_apt_ready
  sudo apt-get install $(apt_y) "nvidia-driver-$ver"
  green "Driver $ver installed."

  if [[ "$HOLD_DRIVER" == "yes" ]]; then
    blue "Holding nvidia-driver-$ver to prevent automatic upgrades..."
    sudo apt-mark hold "nvidia-driver-$ver"
    green "Driver is on hold."
  fi
}

install_cuda_network_repo() {
  blue "Adding NVIDIA CUDA network repository for Ubuntu 24.04..."
  # Network installer: small keyring + repo file, no giant local .deb
  local keyring_url="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb"
  wget -q "$keyring_url" -O /tmp/cuda-keyring.deb
  sudo dpkg -i /tmp/cuda-keyring.deb
  rm -f /tmp/cuda-keyring.deb
  sudo apt-get update
}

install_cuda_toolkit() {
  local cuda_ver="$1"   # e.g. 12.4, 12.6, 12.8
  local drv_major
  drv_major="$(get_installed_driver_major)"
  blue "Detected driver major: ${drv_major:-none}"

  if ! check_cuda_compat "$drv_major" "$cuda_ver"; then
    red "Refusing to install CUDA $cuda_ver: driver $drv_major is too old."
    red "Install a newer driver with --driver or --auto, then retry."
    exit 1
  fi

  # Add CUDA network repo if nvcc not yet available
  if ! dpkg -l cuda-keyring &>/dev/null 2>&1; then
    install_cuda_network_repo
  fi

  blue "Installing CUDA Toolkit $cuda_ver..."
  local pkg="cuda-toolkit-${cuda_ver//./-}"
  sudo apt-get install $(apt_y) "$pkg"

  # Add CUDA paths idempotently to both bashrc and zshrc
  local cudabase="/usr/local/cuda-${cuda_ver}"
  local line_path="export PATH=${cudabase}/bin:\$PATH"
  local line_lib="export LD_LIBRARY_PATH=${cudabase}/lib64:\${LD_LIBRARY_PATH:-}"

  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -f "$rc" ]] || continue
    grep -qxF "$line_path" "$rc" || echo "$line_path" >> "$rc"
    grep -qxF "$line_lib"  "$rc" || echo "$line_lib"  >> "$rc"
  done

  green "CUDA $cuda_ver installed."
  yellow "Open a new shell or run: source ~/.bashrc  (or ~/.zshrc) to get nvcc in PATH."
  blue "Verify: nvcc --version   |   nvidia-smi"
}

install_container_toolkit() {
  blue "Installing NVIDIA Container Toolkit..."
  ensure_apt_ready

  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

  curl -sL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null

  sudo apt-get update
  sudo apt-get install $(apt_y) nvidia-container-toolkit

  # Configure Docker runtime if Docker is installed
  if command -v docker >/dev/null 2>&1; then
    blue "Configuring Docker to use NVIDIA runtime..."
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    green "Docker configured with NVIDIA runtime."
    blue "Test: docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu24.04 nvidia-smi"
  else
    yellow "Docker not found. After installing Docker, run:"
    yellow "  sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker"
  fi

  green "NVIDIA Container Toolkit installed."
}

# --- main ---
blue "NVIDIA setup helper"

if [[ "$AUTO_DRIVER" == "yes" ]]; then
  if command -v nvidia-smi >/dev/null 2>&1; then
    local_drv=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1)
    blue "Driver already present: $local_drv — skipping auto-install."
  else
    recommended=$(detect_recommended_driver)
    blue "Recommended driver: nvidia-driver-$recommended"
    install_driver "$recommended"
    yellow "A reboot is required before the driver is active."
    yellow "After rebooting, re-run with --cuda and --container flags."
  fi
elif [[ -n "$DRIVER_VER" ]]; then
  install_driver "$DRIVER_VER"
else
  if command -v nvidia-smi >/dev/null 2>&1; then
    blue "Driver already present: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1)"
  else
    yellow "No driver requested and none detected. Use --auto or --driver <ver>."
  fi
fi

if [[ -n "$CUDA_VER" ]]; then
  if [[ "$CUDA_VER" == "auto" ]]; then
    drv_major="$(get_installed_driver_major)"
    if [[ -z "$drv_major" ]]; then
      red "Cannot auto-select CUDA version: no NVIDIA driver detected."
      red "Install a driver first with --auto or --driver <ver>, then retry."
      exit 1
    fi
    CUDA_VER="$(best_cuda_for_driver "$drv_major")"
    blue "Auto-selected CUDA $CUDA_VER for driver $drv_major.x"
  fi
  install_cuda_toolkit "$CUDA_VER"
else
  blue "CUDA not requested. Skipping."
fi

if [[ "$INSTALL_CONTAINER" == "yes" ]]; then
  install_container_toolkit
fi

green "Done."
