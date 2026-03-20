#!/bin/bash

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

# Function to print warning messages
print_warning() {
    echo -e "\033[1;33m!\033[0m $1"
}

# Function to maintain sudo privileges
# Refreshes every 30s and tracks parent PID so it dies when setup.sh exits
maintain_sudo() {
    sudo -v
    local parent_pid=$$
    (
        while true; do
            sudo -n true 2>/dev/null
            sleep 30
            kill -0 "$parent_pid" 2>/dev/null || exit 0
        done
    ) &
    SUDO_KEEPER_PID=$!
    export SUDO_KEEPER_PID
}

# Function to check system requirements
check_system() {
    # Check Ubuntu version
    if ! lsb_release -rs | grep -E "^(22.04|24.04)$" > /dev/null; then
        print_error "This script requires Ubuntu 22.04 or 24.04"
        exit 1
    fi

    # Check for internet connectivity
    if ! ping -c 1 github.com &> /dev/null; then
        print_error "No internet connection available"
        exit 1
    fi

    # Check for minimum disk space (1GB)
    local required_space=1000000
    local available_space=$(df /home --output=avail | tail -1)
    if [ "$available_space" -lt "$required_space" ]; then
        print_error "Insufficient disk space. Need at least 1GB free."
        exit 1
    fi
}

# Function to handle errors
handle_error() {
    print_error "Error occurred in script at line $1"
    exit 1
}

# Export functions
export -f print_status print_success print_error print_warning handle_error check_system maintain_sudo
