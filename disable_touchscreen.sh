#!/bin/bash

# Disable touchscreen for laptops with broken/unwanted touchscreens
# Works on both X11 and Wayland (Ubuntu 22.04+ / 24.04+)

# Source common functions if they exist
if [ -f ./common.sh ]; then
    source ./common.sh
else
    print_status() { echo ">>> $1"; }
    print_success() { echo "✓ $1"; }
    print_error() { echo "✗ $1" >&2; }
    print_warning() { echo "! $1"; }
fi

disable_touchscreen() {
    print_status "Setting up touchscreen disable (udev rule — works on X11 and Wayland)"

    # Find touchscreen device(s) to get vendor/product info for udev rule
    local touchscreen_found=false

    # Look for touchscreen devices in /sys
    for device in /sys/class/input/event*/device/name; do
        if [ -f "$device" ]; then
            local name
            name=$(cat "$device")
            # Common touchscreen identifiers
            if echo "$name" | grep -iqE "touch ?screen|ELAN.*touch|eGalax|Atmel|goodix|FTS"; then
                local event_path
                event_path=$(dirname "$(dirname "$device")")
                local event_name
                event_name=$(basename "$event_path")
                print_status "Found touchscreen: $name ($event_name)"
                touchscreen_found=true
            fi
        fi
    done

    if ! $touchscreen_found; then
        print_warning "No touchscreen device detected. The udev rule will still be created"
        print_warning "and will apply if a touchscreen is connected in the future."
    fi

    # Create a udev rule that disables any touchscreen device
    # This works on both X11 and Wayland by preventing the kernel input device
    # from being picked up by libinput
    print_status "Creating udev rule to disable touchscreen..."

    sudo tee /etc/udev/rules.d/99-disable-touchscreen.rules > /dev/null << 'EOF'
# Disable touchscreen input devices
# Matches devices with the touchscreen property set by libinput
ACTION=="add|change", KERNEL=="event[0-9]*", \
  ATTRS{name}=="*[Tt]ouch[Ss]creen*|*ELAN*[Tt]ouch*|*eGalax*|*Atmel*|*goodix*|*FTS*", \
  ENV{LIBINPUT_IGNORE_DEVICE}="1"
EOF

    # Reload udev rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger

    print_success "Touchscreen disable rule created at /etc/udev/rules.d/99-disable-touchscreen.rules"
    print_warning "You may need to reboot for the change to take full effect"
    print_status "To re-enable: sudo rm /etc/udev/rules.d/99-disable-touchscreen.rules && sudo udevadm control --reload-rules"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    disable_touchscreen
fi
