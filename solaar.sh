#!/bin/bash

# Source common functions if they exist
if [ -f ./common.sh ]; then
    source ./common.sh
else
    # Define basic print functions if common.sh is not available
    print_status() { echo ">>> $1"; }
    print_success() { echo "✓ $1"; }
    print_error() { echo "✗ $1" >&2; }
    print_warning() { echo "! $1"; }
fi

install_solaar() {
    print_status "Installing Solaar (Logitech device manager)"

    # Install Solaar and required packages
    sudo apt install -y solaar 

    # Add current user to plugdev group for device access
    sudo usermod -aG plugdev "$USER"

    # Create udev rules directory if it doesn't exist
    sudo mkdir -p /etc/udev/rules.d

    # Add udev rules for Logitech receivers if not already present
    if [ ! -f "/etc/udev/rules.d/42-logitech-unify-permissions.rules" ]; then
        print_status "Adding udev rules for Logitech devices..."
        echo 'SUBSYSTEM=="hidraw", ATTRS{idVendor}=="046d", MODE="0666"
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="046d", RUN+="/usr/bin/solaar-cli config"' | \
        sudo tee /etc/udev/rules.d/42-logitech-unify-permissions.rules > /dev/null
    fi

    # Reload udev rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger

    # Create systemd user service directory if it doesn't exist
    mkdir -p ~/.config/systemd/user/

    # Create systemd user service file for Solaar
    cat > ~/.config/systemd/user/solaar.service << 'EOL'
[Unit]
Description=Solaar Logitech Device Manager
After=graphical-session.target
PartOf=graphical-session.target

[Service]
ExecStart=/usr/bin/solaar --window=hide
Restart=on-failure

[Install]
WantedBy=graphical-session.target
EOL

    # Reload systemd user daemon
    systemctl --user daemon-reload

    # Enable and start Solaar service for current user
    systemctl --user enable solaar.service
    systemctl --user start solaar.service

    print_success "Solaar installation complete"
    print_warning "You may need to log out and back in for group changes to take effect"
    print_status "Solaar will now start automatically when you log in"
}

# Run the installation function if the script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_solaar
fi
