#!/bin/bash

# Source common functions if available
if [ -f "./common.sh" ]; then
    source ./common.sh
else
    # Define minimal print functions if common.sh is not available
    print_status() { echo "==> $1"; }
    print_error() { echo "ERROR: $1" >&2; }
    print_success() { echo "SUCCESS: $1"; }
    print_warning() { echo "WARNING: $1"; }
fi

# Check if script is run with sudo
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script with sudo or as root."
    exit 1
fi

install_adguard_vpn() {
    print_status "Installing AdGuard VPN CLI..."
    
    # Install AdGuard VPN
    if ! curl -fsSL https://raw.githubusercontent.com/AdguardTeam/AdGuardVPNCLI/master/scripts/release/install.sh | sh -s -- -v; then
        print_error "Failed to install AdGuard VPN CLI"
        exit 1
    fi
    
    print_success "AdGuard VPN CLI installed successfully"
}

check_adguard_installation() {
    if ! command -v adguardvpn-cli &>/dev/null; then
        print_error "AdGuard VPN CLI not found. Installation may have failed."
        exit 1
    fi
}

check_tailscale() {
    if command -v tailscale >/dev/null 2>&1; then
        if tailscale status >/dev/null 2>&1; then
            print_status "Tailscale is active, will preserve Tailscale DNS settings"
            return 0
        fi
    fi
    return 1
}

setup_adguard() {
    local location="${1:-Las Vegas}"
    
    print_status "Setting up AdGuard VPN..."
    
    # Login prompt
    print_status "Please log in to your AdGuard account..."
    if ! adguardvpn-cli login; then
        print_error "Login failed"
        exit 1
    fi
    
    # List available locations
    print_status "Available VPN locations:"
    adguardvpn-cli list-locations
    
    # Connect to specified location using expect-like behavior
    print_status "Connecting to $location..."
    print_status "Note: Answering 'yes' to TUN mode, 'no' to DNS changes (preserving Tailscale), and 'no' to crash reports"
    
    # Use script command to handle interactive prompts
    (
        echo "connect -l \"$location\""
        sleep 1
        echo "yes"  # Answer yes to TUN mode
        sleep 1
        echo "no"   # Answer no to DNS changes to preserve Tailscale DNS
        sleep 1
        echo "no"   # Answer no to crash reports
    ) | adguardvpn-cli
    
    # Check if connection was successful
    if ! adguardvpn-cli status | grep -q "Connected"; then
        print_warning "Failed to connect to $location. Trying quick connect..."
        (
            echo "connect"
            sleep 1
            echo "yes"  # Answer yes to TUN mode
            sleep 1
            echo "no"   # Answer no to DNS changes
            sleep 1
            echo "no"   # Answer no to crash reports
        ) | adguardvpn-cli
    fi
    
    print_success "AdGuard VPN setup complete"
}

print_usage() {
    echo "Usage: $0 [location]"
    echo "       If no location is specified, 'Las Vegas' will be used"
    echo
    echo "Note: This script will:"
    echo "  - Preserve Tailscale DNS settings if Tailscale is detected"
    echo "  - Enable TUN mode"
    echo "  - Disable crash reports"
    echo
    echo "Commands available after installation:"
    echo "  adguardvpn-cli list-locations   - Show available locations"
    echo "  adguardvpn-cli connect -l CITY  - Connect to specific location"
    echo "  adguardvpn-cli connect         - Quick connect to fastest server"
    echo "  adguardvpn-cli disconnect      - Disconnect from VPN"
    echo "  adguardvpn-cli status          - Show connection status"
    echo "  adguardvpn-cli --help-all      - Show all available commands"
}

main() {
    local location="${1:-Las Vegas}"
    
    case "$1" in
        "help"|"-h"|"--help")
            print_usage
            exit 0
            ;;
    esac
    
    # Check for Tailscale
    check_tailscale
    
    # Install and setup AdGuard VPN
    install_adguard_vpn
    check_adguard_installation
    setup_adguard "$location"
    
    # Print final status
    print_status "Current VPN status:"
    adguardvpn-cli status
    
    print_success "Installation and setup complete!"
    print_warning "You can view all available commands with: adguardvpn-cli --help-all"
}

main "$@"
