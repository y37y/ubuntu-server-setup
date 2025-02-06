#!/bin/bash
set -e

# Function to print status messages
print_status() {
    echo -e "\033[1;34m>>>\033[0m $1"
}

# Function to print success messages
print_success() {
    echo -e "\033[1;32m✓\033[0m $1"
}

# Function to print error messages
print_error() {
    echo -e "\033[1;31m✗\033[0m $1"
}

# Function to handle errors
handle_error() {
    print_error "Error occurred in script at line $1"
    exit 1
}

trap 'handle_error $LINENO' ERR

blacklist_nouveau() {
    print_status "Blacklisting nouveau driver..."
    
    # Create blacklist file
    echo 'blacklist nouveau
options nouveau modeset=0' | sudo tee /etc/modprobe.d/blacklist-nouveau.conf

    # Update initramfs
    sudo update-initramfs -u

    print_success "Nouveau driver blacklisted"
}

setup_nvidia_container_toolkit() {
    print_status "Setting up NVIDIA Container Toolkit repository..."

    # Install prerequisites
    sudo apt-get install -y curl

    # Add NVIDIA Container Toolkit repository
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    sudo apt-get update
}

install_cuda() {
    print_status "Installing CUDA Toolkit"
    
    # Check if NVIDIA hardware is available
    if ! lspci | grep -i nvidia > /dev/null; then
        print_error "No NVIDIA hardware detected. Skipping CUDA Toolkit installation."
        exit 1
    fi

    # First blacklist nouveau
    blacklist_nouveau

    # Download and install CUDA Toolkit 12.6 Update 3
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-ubuntu2404.pin
    sudo mv cuda-ubuntu2404.pin /etc/apt/preferences.d/cuda-repository-pin-600
    wget https://developer.download.nvidia.com/compute/cuda/12.6.3/local_installers/cuda-repo-ubuntu2404-12-6-local_12.6.3-560.35.05-1_amd64.deb
    sudo dpkg -i cuda-repo-ubuntu2404-12-6-local_12.6.3-560.35.05-1_amd64.deb
    sudo cp /var/cuda-repo-ubuntu2404-12-6-local/cuda-*-keyring.gpg /usr/share/keyrings/
    sudo apt update
    sudo apt install -y cuda-toolkit-12-6

    # Install NVIDIA drivers (open kernel module flavor)
    sudo apt install -y cuda-drivers nvitop

    # Setup and install NVIDIA Container Toolkit
    setup_nvidia_container_toolkit
    sudo apt install -y nvidia-container-toolkit

    print_success "CUDA Toolkit and NVIDIA drivers installed successfully"
    print_status "A system reboot is required to complete the installation"
    print_status "After reboot, verify installation with: nvidia-smi"
}

# Run CUDA/NVIDIA installation
install_cuda

# Prompt for reboot
read -p "Would you like to reboot now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo reboot
else
    print_status "Remember to reboot your system to complete the installation"
fi
