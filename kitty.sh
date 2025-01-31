#!/bin/bash

# Source common functions if they exist
if [ -f ./common.sh ]; then
    source ./common.sh
else
    # Define basic print functions if common.sh is not available
    print_status() { echo "[-] $1"; }
    print_success() { echo "[+] $1"; }
    print_error() { echo "[!] $1" >&2; }
    print_warning() { echo "[*] $1"; }
fi

install_kitty() {
    print_status "Installing Kitty Terminal (Latest Version)"
    # Install the latest Kitty Terminal binary
    if ! command -v kitty &>/dev/null; then
        print_status "Downloading and installing the latest Kitty binary"
        
        # Download and run the Kitty installer script
        curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n

        # Add Kitty to PATH (symlink)
        sudo ln -s ~/.local/kitty.app/bin/kitty /usr/local/bin/

        # Create application and desktop shortcuts
        print_status "Creating Kitty Desktop and Application Shortcuts"

        # Create necessary directories
        mkdir -p ~/.local/share/applications

        # Application Launcher (for GUI application menu)
        cp ~/.local/kitty.app/share/applications/kitty.desktop ~/.local/share/applications/
        sed -i "s|Icon=kitty|Icon=/home/$USER/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" ~/.local/share/applications/kitty*.desktop
        sed -i "s|Exec=kitty|Exec=/home/$USER/.local/kitty.app/bin/kitty|g" ~/.local/share/applications/kitty*.desktop

        # Desktop Shortcut
        cp ~/.local/kitty.app/share/applications/kitty.desktop ~/Desktop
        sed -i "s|Icon=kitty|Icon=/home/$USER/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" ~/Desktop/kitty*.desktop
        sed -i "s|Exec=kitty|Exec=/home/$USER/.local/kitty.app/bin/kitty|g" ~/Desktop/kitty*.desktop
        chmod a+x ~/Desktop/kitty*.desktop

        # Trust the desktop shortcut to allow launching
        gio set ~/Desktop/kitty*.desktop metadata::trusted true
    else
        print_status "Kitty is already installed (binary version)."
    fi

    print_success "Kitty installation and basic configuration complete."
}

# Run the installation function if the script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_kitty
fi
