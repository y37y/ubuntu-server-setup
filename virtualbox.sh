#!/bin/bash

# Source common functions
source ./common.sh

install_virtualbox() {
    print_status "Installing VirtualBox"

    # Import VirtualBox's repository GPG key
    print_status "Importing VirtualBox repository GPG key..."
    wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --dearmor --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg

    # Add VirtualBox repository
    print_status "Adding VirtualBox repository..."
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] http://download.virtualbox.org/virtualbox/debian $(. /etc/os-release && echo "$VERSION_CODENAME") contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list

    # Update package list
    sudo apt update

    # Install VirtualBox
    print_status "Installing VirtualBox 7.1..."
    sudo apt install -y virtualbox-7.1

    # Get VirtualBox version
    local vbox_version
    vbox_version=$(vboxmanage -v | cut -dr -f1)
    print_status "VirtualBox version: $vbox_version"

    # Install Extension Pack
    print_status "Installing VirtualBox Extension Pack..."
    local extpack_url="https://download.virtualbox.org/virtualbox/${vbox_version}/Oracle_VirtualBox_Extension_Pack-${vbox_version}.vbox-extpack"
    local extpack_file="Oracle_VirtualBox_Extension_Pack-${vbox_version}.vbox-extpack"
    
    if wget "$extpack_url"; then
        yes | sudo vboxmanage extpack install "$extpack_file"
        rm "$extpack_file"
    else
        print_warning "Failed to download Extension Pack. You may need to install it manually."
    fi

    # Add user to vboxusers group
    print_status "Adding user to vboxusers group..."
    sudo usermod -aG vboxusers "$USER"

    # Verify installation
    if command -v virtualbox >/dev/null; then
        print_success "VirtualBox installed successfully"
        print_status "Installed extensions:"
        vboxmanage list extpacks
    else
        print_error "VirtualBox installation failed"
        return 1
    fi

    print_warning "Please log out and log back in for group changes to take effect"
    print_warning "You may need to reboot your system for VirtualBox to work properly"
}

# Run the installation if the script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_virtualbox
fi
