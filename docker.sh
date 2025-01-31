#!/bin/bash
set -e

# Source common functions
source ./common.sh

install_docker_environment() {
    print_status "Installing Docker environment"

    # Remove old versions if they exist
    print_status "Removing old Docker versions if present..."
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true

    # Install prerequisites
    print_status "Installing prerequisites..."
    sudo apt-get update
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg

    # Add Docker's official GPG key
    print_status "Adding Docker GPG key..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    print_status "Adding Docker repository..."
    echo \
        "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    print_status "Installing Docker Engine..."
    sudo apt-get update
    sudo apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    # Add current user to docker group
    print_status "Adding user to docker group..."
    sudo usermod -aG docker "$USER"

    # Start and enable Docker service
    print_status "Starting Docker service..."
    sudo systemctl enable docker
    sudo systemctl start docker

    # Create Docker config directory and set default configuration
    print_status "Configuring Docker defaults..."
    mkdir -p "$HOME/.docker"
    if [ ! -f "$HOME/.docker/config.json" ]; then
        cat > "$HOME/.docker/config.json" << EOL
{
    "experimental": true,
    "features": {
        "buildkit": true
    }
}
EOL
    fi

    print_success "Docker environment setup complete"
    print_status "Docker version: $(docker --version 2>/dev/null || echo 'Not available until restart')"
    print_status "Docker Compose version: $(docker compose version 2>/dev/null || echo 'Not available until restart')"
    
    print_warning "Please log out and log back in for the docker group changes to take effect"
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_system
    maintain_sudo
    install_docker_environment
fi
