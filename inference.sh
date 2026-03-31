#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
source "$SCRIPT_DIR/common.sh"

LLAMA_CPP_DIR="$HOME/Projects/llama.cpp"
VLLM_VENV="$HOME/venvs/vllm"

usage() {
cat <<'EOF'
Usage: inference.sh [options]

Options:
  --ollama          Install Ollama (recommended, GPU auto-detected)
  --llama-cpp       Build llama.cpp with CUDA support
  --vllm            Install vLLM in a Python venv (requires CUDA)
  --all             Install all of the above
  -h, --help        Show this help

Examples:
  # Typical RTX 4090 server setup:
  ./inference.sh --ollama --llama-cpp --vllm

  # Ollama only (easiest to get started):
  ./inference.sh --ollama
EOF
}

DO_OLLAMA="no"
DO_LLAMA_CPP="no"
DO_VLLM="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ollama)     DO_OLLAMA="yes"; shift ;;
    --llama-cpp)  DO_LLAMA_CPP="yes"; shift ;;
    --vllm)       DO_VLLM="yes"; shift ;;
    --all)        DO_OLLAMA="yes"; DO_LLAMA_CPP="yes"; DO_VLLM="yes"; shift ;;
    -h|--help)    usage; exit 0 ;;
    *) print_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ "$DO_OLLAMA" == "no" && "$DO_LLAMA_CPP" == "no" && "$DO_VLLM" == "no" ]]; then
  usage
  exit 0
fi

check_nvidia() {
  if ! command -v nvidia-smi >/dev/null 2>&1; then
    print_warning "nvidia-smi not found. GPU acceleration will not be available."
    print_warning "Run nvidia.sh first to install drivers and CUDA."
    return 1
  fi
  print_success "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)"
  return 0
}

# ---------------------------------------------------------------------------
# Ollama
# ---------------------------------------------------------------------------
install_ollama() {
  if command -v ollama >/dev/null 2>&1; then
    print_status "Ollama already installed: $(ollama --version 2>/dev/null || true)"
    return 0
  fi

  print_status "Installing Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh

  # Enable and start the systemd service
  if systemctl list-unit-files ollama.service &>/dev/null; then
    sudo systemctl enable ollama
    sudo systemctl start ollama
    print_success "Ollama service enabled and started."
  fi

  print_success "Ollama installed."
  echo ""
  print_status "Quick start:"
  echo "  ollama serve                  # start API server (if not using systemd)"
  echo "  ollama run llama3.2           # run a model"
  echo "  ollama run qwen2.5-coder:7b   # coding model"
  echo "  ollama list                   # list downloaded models"
  echo "  curl http://localhost:11434/api/generate -d '{\"model\":\"llama3.2\",\"prompt\":\"hi\"}'"
}

# ---------------------------------------------------------------------------
# llama.cpp
# ---------------------------------------------------------------------------
install_llama_cpp() {
  print_status "Building llama.cpp with CUDA support..."

  # Dependencies
  sudo apt-get update
  sudo apt-get install -y cmake build-essential libcurl4-openssl-dev

  # Check for CUDA
  local cuda_flags=""
  if command -v nvcc >/dev/null 2>&1; then
    print_status "CUDA detected: $(nvcc --version | grep release | awk '{print $5}' | tr -d ',')"
    local cuda_arch
    cuda_arch=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -n1 | tr -d '.')
    if [[ -n "$cuda_arch" ]]; then
      print_status "GPU compute capability: $cuda_arch"
    else
      print_warning "Could not query compute capability, defaulting to 89 (Ada Lovelace)"
      cuda_arch="89"
    fi
    cuda_flags="-DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=$cuda_arch -DGGML_CUDA_FORCE_MMQ=ON"
  else
    print_warning "nvcc not found — building llama.cpp without CUDA."
    print_warning "For GPU support, install CUDA first: ./nvidia.sh --cuda"
  fi

  # Clone or update
  if [[ ! -d "$LLAMA_CPP_DIR" ]]; then
    print_status "Cloning llama.cpp..."
    git clone https://github.com/ggml-org/llama.cpp "$LLAMA_CPP_DIR"
  else
    print_status "Updating llama.cpp..."
    git -C "$LLAMA_CPP_DIR" pull
  fi

  # Build
  print_status "Building (this may take a few minutes)..."
  cmake -S "$LLAMA_CPP_DIR" -B "$LLAMA_CPP_DIR/build" \
    -DCMAKE_BUILD_TYPE=Release \
    $cuda_flags \
    -DLLAMA_CURL=ON

  cmake --build "$LLAMA_CPP_DIR/build" --config Release -j"$(nproc)"

  # Install binaries to ~/.local/bin
  mkdir -p "$HOME/.local/bin"
  for bin in llama-cli llama-server llama-bench llama-quantize; do
    local src="$LLAMA_CPP_DIR/build/bin/$bin"
    if [[ -f "$src" ]]; then
      ln -sf "$src" "$HOME/.local/bin/$bin"
    fi
  done

  # Ensure ~/.local/bin is in PATH
  if ! grep -q 'HOME/.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  fi

  print_success "llama.cpp built and linked to ~/.local/bin/"
  echo ""
  print_status "Quick start:"
  echo "  # Download a GGUF model (example):"
  echo "  ollama pull llama3.2  # use Ollama to pull, or download directly:"
  echo "  # llama-cli -m /path/to/model.gguf -p 'Hello' -n 128 --gpu-layers 99"
  echo "  # llama-server -m /path/to/model.gguf --port 8080 --gpu-layers 99"
}

# ---------------------------------------------------------------------------
# vLLM
# ---------------------------------------------------------------------------
install_vllm() {
  print_status "Installing vLLM..."

  if ! check_nvidia; then
    print_error "vLLM requires a CUDA-capable GPU with drivers installed."
    exit 1
  fi

  if ! command -v nvcc >/dev/null 2>&1; then
    print_error "nvcc not found. Install CUDA first: ./nvidia.sh --cuda 12.8"
    exit 1
  fi

  # Python venv
  sudo apt-get update
  sudo apt-get install -y python3-full python3-pip python3-venv

  if [[ -d "$VLLM_VENV" ]]; then
    print_status "vLLM venv already exists at $VLLM_VENV, updating..."
  else
    print_status "Creating Python venv at $VLLM_VENV..."
    mkdir -p "$(dirname "$VLLM_VENV")"
    python3 -m venv "$VLLM_VENV"
  fi

  print_status "Installing vLLM (this takes several minutes on first install)..."
  "$VLLM_VENV/bin/pip" install --upgrade pip
  "$VLLM_VENV/bin/pip" install vllm

  # Shell helper to activate the venv
  local activate_line="alias vllm-activate='source $VLLM_VENV/bin/activate'"
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -f "$rc" ]] || continue
    grep -qF "vllm-activate" "$rc" || echo "$activate_line" >> "$rc"
  done

  print_success "vLLM installed in $VLLM_VENV"
  echo ""
  print_status "Quick start:"
  echo "  source $VLLM_VENV/bin/activate"
  echo "  vllm serve Qwen/Qwen2.5-7B-Instruct --gpu-memory-utilization 0.9"
  echo "  # OpenAI-compatible API at http://localhost:8000"
  echo ""
  print_status "Or use the alias (after restarting shell):"
  echo "  vllm-activate && vllm serve <model>"
}

# ---------------------------------------------------------------------------
# Run selected installs
# ---------------------------------------------------------------------------
print_status "LLM Inference setup"
check_nvidia || true

[[ "$DO_OLLAMA"    == "yes" ]] && install_ollama
[[ "$DO_LLAMA_CPP" == "yes" ]] && install_llama_cpp
[[ "$DO_VLLM"      == "yes" ]] && install_vllm

print_success "Inference setup complete."
