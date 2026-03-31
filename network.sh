#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
source "$SCRIPT_DIR/common.sh"

usage() {
cat <<'EOF'
Usage: network.sh [options]

Options:
  --tailscale       Install Tailscale VPN
  --ssh-harden      Harden SSH (disable password auth, keep key auth, fail2ban)
  --all             Run all of the above
  -h, --help        Show this help

WARNING: --ssh-harden disables SSH password authentication.
Ensure your SSH public key is installed BEFORE running this option,
or you may lock yourself out.
EOF
}

DO_TAILSCALE="no"
DO_SSH="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tailscale)   DO_TAILSCALE="yes"; shift ;;
    --ssh-harden)  DO_SSH="yes"; shift ;;
    --all)         DO_TAILSCALE="yes"; DO_SSH="yes"; shift ;;
    -h|--help)     usage; exit 0 ;;
    *) print_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ "$DO_TAILSCALE" == "no" && "$DO_SSH" == "no" ]]; then
  usage
  exit 0
fi

# ---------------------------------------------------------------------------
# Tailscale
# ---------------------------------------------------------------------------
install_tailscale() {
  if command -v tailscale >/dev/null 2>&1; then
    print_status "Tailscale already installed: $(tailscale version | head -n1)"
    return 0
  fi

  print_status "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh

  sudo systemctl enable tailscaled
  sudo systemctl start tailscaled

  print_success "Tailscale installed and daemon started."
  print_warning "Run 'sudo tailscale up' to authenticate and join your network."
  print_status "For subnet routing (access LAN from Tailscale):"
  echo "  sudo tailscale up --advertise-routes=192.168.1.0/24"
  echo "  sudo tailscale up --advertise-exit-node"
}

# ---------------------------------------------------------------------------
# SSH hardening
# ---------------------------------------------------------------------------
harden_ssh() {
  print_status "Hardening SSH configuration..."

  # Verify at least one authorized key exists before locking password auth
  local auth_keys="$HOME/.ssh/authorized_keys"
  if [[ ! -f "$auth_keys" ]] || [[ ! -s "$auth_keys" ]]; then
    print_error "No SSH authorized_keys found at $auth_keys"
    print_error "Add your public key first: ssh-copy-id user@host"
    print_error "Refusing to disable password auth to avoid lockout."
    exit 1
  fi

  local key_count
  key_count=$(grep -c "^ssh-" "$auth_keys" 2>/dev/null || echo 0)
  print_success "Found $key_count authorized key(s) — safe to disable password auth."

  # Ensure openssh-server is installed
  if ! dpkg -l openssh-server &>/dev/null 2>&1; then
    print_status "Installing OpenSSH server..."
    sudo apt-get update
    sudo apt-get install -y openssh-server
  fi

  sudo systemctl enable ssh
  sudo systemctl start ssh

  local sshd_cfg="/etc/ssh/sshd_config"
  local backup="/etc/ssh/sshd_config.bak.$(date +%Y%m%d_%H%M%S)"
  sudo cp "$sshd_cfg" "$backup"
  print_status "Backed up sshd_config to $backup"

  # Apply hardening settings
  apply_sshd_option() {
    local key="$1" val="$2"
    if sudo grep -qP "^\s*#?\s*${key}\s" "$sshd_cfg"; then
      sudo sed -i "s|^\s*#\?\s*${key}\s.*|${key} ${val}|" "$sshd_cfg"
    else
      echo "${key} ${val}" | sudo tee -a "$sshd_cfg" >/dev/null
    fi
  }

  apply_sshd_option "PasswordAuthentication"        "no"
  apply_sshd_option "PubkeyAuthentication"          "yes"
  apply_sshd_option "PermitRootLogin"               "no"
  apply_sshd_option "AuthorizedKeysFile"            ".ssh/authorized_keys"
  apply_sshd_option "ChallengeResponseAuthentication" "no"
  apply_sshd_option "UsePAM"                        "yes"
  apply_sshd_option "X11Forwarding"                 "no"
  apply_sshd_option "PrintMotd"                     "no"
  apply_sshd_option "MaxAuthTries"                  "3"
  apply_sshd_option "LoginGraceTime"                "30"
  apply_sshd_option "ClientAliveInterval"           "300"
  apply_sshd_option "ClientAliveCountMax"           "2"

  # Validate config before restarting
  if sudo sshd -t; then
    sudo systemctl restart ssh
    print_success "SSH hardening applied and service restarted."
  else
    print_error "sshd config validation failed! Restoring backup..."
    sudo cp "$backup" "$sshd_cfg"
    sudo systemctl restart ssh
    exit 1
  fi

  # Install fail2ban
  print_status "Installing fail2ban..."
  sudo apt-get install -y fail2ban

  # Create jail.local with SSH protection
  if [[ ! -f /etc/fail2ban/jail.local ]]; then
    sudo tee /etc/fail2ban/jail.local >/dev/null <<'JAIL'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
backend  = systemd

[sshd]
enabled  = true
port     = ssh
filter   = sshd
maxretry = 3
bantime  = 24h
JAIL
  fi

  sudo systemctl enable fail2ban
  sudo systemctl restart fail2ban
  print_success "fail2ban configured for SSH protection."

  echo ""
  print_success "SSH hardening complete."
  print_status "Summary of changes:"
  echo "  - Password authentication: DISABLED"
  echo "  - Public key authentication: enabled"
  echo "  - Root login: disabled"
  echo "  - Max auth tries: 3"
  echo "  - fail2ban: active (bans after 3 failed attempts for 24h)"
  print_warning "Test SSH access in a NEW terminal before closing this session!"
}

# ---------------------------------------------------------------------------
# Run selected steps
# ---------------------------------------------------------------------------
[[ "$DO_TAILSCALE" == "yes" ]] && install_tailscale
[[ "$DO_SSH"       == "yes" ]] && harden_ssh

print_success "Network setup complete."
