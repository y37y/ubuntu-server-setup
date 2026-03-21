#!/bin/bash

set -e

# Source common functions
source ./common.sh

# Check if script is run with sudo
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script with sudo or as root."
    exit 1
fi

# Improved ensure_brew_env function
ensure_brew_env() {
    # First check if brew is already available
    if command -v brew &>/dev/null; then
        return 0
    fi

    # Try to source Homebrew environment
    if [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

        # Verify it worked
        if command -v brew &>/dev/null; then
            return 0
        fi
    fi

    # If we get here, Homebrew is not properly installed
    print_error "Homebrew is not properly installed or configured"
    print_status "Please run the full installation first or install Homebrew manually"
    exit 1
}

# Install essential dependencies first
install_essential_dependencies() {
    print_status "Installing essential dependencies..."
    sudo apt update
    sudo apt install -y build-essential curl git wget ca-certificates unzip jq \
        pkg-config libssl-dev libgit2-dev libcurl4-openssl-dev
    print_success "Essential dependencies installed"
}

# Install Homebrew with improved error handling
install_homebrew() {
    if command -v brew &>/dev/null; then
        print_status "Homebrew already installed"
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null || true
        return 0
    fi

    print_status "Installing Homebrew..."

    # Install Homebrew
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        print_success "Homebrew installation completed"
    else
        print_error "Homebrew installation failed"
        exit 1
    fi

    # Set up Homebrew environment
    if [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

        # Add to shell profiles for persistence
        {
            echo ""
            echo "# Homebrew"
            echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
        } >> ~/.bashrc

        {
            echo ""
            echo "# Homebrew"
            echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
        } >> ~/.profile

        # Create .zshrc if it doesn't exist and add Homebrew
        if [ ! -f ~/.zshrc ]; then
            touch ~/.zshrc
        fi
        {
            echo ""
            echo "# Homebrew"
            echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
        } >> ~/.zshrc

        # Verify installation
        if command -v brew &>/dev/null; then
            print_success "Homebrew installed and configured successfully"
            print_status "Homebrew version: $(brew --version | head -1)"
        else
            print_error "Homebrew installation verification failed"
            exit 1
        fi
    else
        print_error "Homebrew installation failed - binary not found"
        exit 1
    fi
}

setup_neovim() {
    # Full skip if nvim + config + venv all exist
    if command -v nvim &>/dev/null && [ -d "$HOME/.config/nvim" ] && [ -d "$HOME/.neovim-venv" ]; then
        print_status "Neovim already set up: $(nvim --version | head -1)"
        return 0
    fi

    ensure_brew_env
    sudo -v  # refresh sudo

    print_status "Setting up Neovim"

    # Install Lua 5.1 and dependencies first via apt
    print_status "Installing Lua 5.1 and dependencies..."
    sudo apt install -y lua5.1 liblua5.1-0-dev luarocks python3-full python3-pip python3-venv

    # Verify Lua installation
    print_status "Verifying Lua installation..."
    if ! command -v lua5.1 &>/dev/null; then
        print_error "Lua 5.1 installation failed"
        exit 1
    fi
    print_success "Lua 5.1 version: $(lua5.1 -v)"
    print_success "LuaRocks version: $(luarocks --version)"

    # Install Neovim and dependencies using Homebrew for latest versions
    print_status "Installing Neovim and core dependencies..."
    brew install neovim tree-sitter luajit

    # Create a Python virtual environment for Neovim
    print_status "Setting up Python environment for Neovim..."
    if [ ! -d "$HOME/.neovim-venv" ]; then
        python3 -m venv "$HOME/.neovim-venv"
    fi

    # Activate virtual environment and install dependencies
    source "$HOME/.neovim-venv/bin/activate"
    pip install pynvim pylatexenc pillow notebook nbclassic jupyter-console
    deactivate

    # Install Node.js provider and dependencies (no sudo — fnm npm uses user prefix)
    if command -v npm &>/dev/null; then
        print_status "Installing Node.js provider and dependencies..."
        npm install -g neovim tree-sitter-cli @styled/typescript-styled-plugin
    else
        print_warning "Node.js not found. Skipping Node.js provider installation."
    fi

    # Clone Neovim configuration (only if not already present)
    if [ ! -d ~/.config/nvim ]; then
        print_status "Installing your Neovim configuration..."
        git clone --recursive https://github.com/y37y/nvim.git ~/.config/nvim

        (
            cd ~/.config/nvim

            # Set up upstream remote
            git remote add upstream https://github.com/chaozwn/astronvim_user
            git fetch upstream

            # Initialize and update submodules
            git submodule update --init --recursive --force
            git submodule foreach git pull origin master
        )
    else
        print_status "Neovim configuration already exists"
    fi

    # Install additional tools using Homebrew
    print_status "Installing additional tools..."
    brew install fzf fd lazygit ripgrep gdu bottom protobuf gnu-sed ast-grep \
        lazydocker imagemagick chafa delta

    print_success "Neovim setup complete"
    print_warning "Please run :checkhealth in Neovim to verify the installation"
    print_warning "If you need custom fonts, make sure to run the Nerd Fonts installation option"
}

setup_zsh_environment() {
    ensure_brew_env

    print_status "Setting up Zsh environment"

    # Install Zsh if not present
    if ! command -v zsh &>/dev/null; then
        sudo apt install -y zsh
    fi

    # Install Zsh configuration
    if [ ! -d "$HOME/.config/zsh" ]; then
        print_status "Cloning Zsh configuration..."
        git clone https://github.com/y37y/zsh.git "$HOME/.config/zsh"

        cd "$HOME/.config/zsh"

        # Run the installer
        if [ -f "./install.sh" ]; then
            print_status "Running Zsh configuration installer..."
            chmod +x ./install.sh
            ./install.sh
        else
            # Manual setup if install.sh doesn't exist
            print_status "Manually setting up Zsh configuration..."
            cp .zshrc ~/.zshrc

            # Copy starship config if it exists
            if [ -f "starship.toml" ]; then
                mkdir -p ~/.config
                cp starship.toml ~/.config/starship.toml
            fi
        fi

        cd - > /dev/null
    else
        print_status "Zsh configuration already exists, updating..."
        cd "$HOME/.config/zsh"
        git pull origin main || git pull origin master
        cd - > /dev/null
    fi

    print_success "Zsh environment setup complete"
}

install_base_development() {
    ensure_brew_env
    sudo -v  # refresh sudo before long brew operations

    print_status "Installing base development tools"

    # Remove apt version of trash-cli if installed
    if dpkg -l | grep -q trash-cli; then
        print_status "Removing apt version of trash-cli..."
        sudo apt remove -y trash-cli
    fi

    # System packages
    sudo apt install -y python3-pip pipx python3-venv \
        fuse libfuse2 markdown shellcheck xclip xsel

    # Homebrew packages
    brew install gcc luarocks bottom protobuf gnu-sed ast-grep htop btop dust duf \
        procs fastfetch hyperfine httpie tldr tokei broot jq yq wget bat \
        inxi trash-cli

    # Create necessary directories
    mkdir -p ~/.local/bin

    # Create symlinks
    ln -sf "$(brew --prefix)/bin/bat" ~/.local/bin/batcat

    # Install GDU directly from GitHub
    install_gdu

    # Python packages
    python3 -m pip install --user --break-system-packages pynvim pillow

    print_success "Base development tools installed"
}

install_shell_tools() {
    ensure_brew_env
    sudo -v  # refresh sudo before long brew operations

    print_status "Installing shell tools for Zsh"

    # Install Zsh and related tools
    brew install zsh fzf eza zoxide ripgrep fd starship \
        tmux zellij ghq tree bat duf bottom \
        tree-sitter

    # Install Atuin shell history sync
    if ! command -v atuin &>/dev/null; then
        print_status "Installing Atuin..."
        curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
    else
        print_status "Atuin already installed"
    fi

    # WezTerm
    if ! command -v wezterm &>/dev/null; then
        curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
        echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
        sudo apt update && sudo apt install -y wezterm-nightly
    fi

    # Note: Zsh configuration is handled by dotfiles.sh
}

change_default_shell() {
    local zsh_path

    # Try to find zsh in common locations
    if command -v zsh &>/dev/null; then
        zsh_path=$(which zsh)
    elif [ -f "/home/linuxbrew/.linuxbrew/bin/zsh" ]; then
        zsh_path="/home/linuxbrew/.linuxbrew/bin/zsh"
    else
        zsh_path="/usr/bin/zsh"
    fi

    if [[ "$SHELL" != "$zsh_path" ]]; then
        print_status "Changing default shell to zsh..."

        # Add zsh to /etc/shells if not already there
        if ! grep -q "$zsh_path" /etc/shells; then
            echo "$zsh_path" | sudo tee -a /etc/shells
        fi

        # Change shell
        chsh -s "$zsh_path"
        print_warning "Shell change will take effect after you log out and back in"
    else
        print_status "Zsh is already the default shell"
    fi
}

install_version_control() {
    ensure_brew_env
    sudo -v  # refresh sudo
    print_status "Installing version control tools"
    brew install git git-lfs lazygit lazydocker gh difftastic
    git lfs install
}

install_browsers() {
    sudo -v  # refresh sudo
    print_status "Installing browsers"

    # Chrome
    if ! command -v google-chrome &>/dev/null; then
        print_status "Installing Google Chrome..."
        wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        sudo apt install -y ./google-chrome-stable_current_amd64.deb
        rm -f google-chrome-stable_current_amd64.deb
    else
        print_status "Google Chrome already installed"
    fi

    # Edge
    if ! command -v microsoft-edge &>/dev/null; then
        print_status "Installing Microsoft Edge..."
        curl -fSsL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --yes --dearmor -o /usr/share/keyrings/microsoft-edge.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-edge.gpg] https://packages.microsoft.com/repos/edge stable main" | sudo tee /etc/apt/sources.list.d/microsoft-edge.list
        sudo apt update && sudo apt install -y microsoft-edge-stable
    else
        print_status "Microsoft Edge already installed"
    fi

    # Brave
    if ! command -v brave-browser &>/dev/null; then
        print_status "Installing Brave Browser..."
        sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
        sudo apt update && sudo apt install -y brave-browser
    else
        print_status "Brave Browser already installed"
    fi
}

install_network_tools() {
    sudo -v  # refresh sudo
    print_status "Installing network tools"

    # Install Tailscale
    if ! command -v tailscale &>/dev/null; then
        print_status "Installing Tailscale..."
        curl -fsSL https://tailscale.com/install.sh | sh
        print_success "Tailscale installed"
    else
        print_status "Tailscale is already installed"
    fi

    # Install ZeroTier
    if ! command -v zerotier-cli &>/dev/null; then
        print_status "Installing ZeroTier..."
        curl -s https://install.zerotier.com | sudo bash
        print_success "ZeroTier installed"
    else
        print_status "ZeroTier is already installed"
    fi

    # Install LocalSend
    if ! command -v localsend &>/dev/null && ! flatpak list 2>/dev/null | grep -q localsend; then
        print_status "Installing LocalSend..."
        # Try flatpak first (most reliable on Ubuntu)
        if command -v flatpak &>/dev/null; then
            flatpak install -y flathub org.localsend.localsend_app
            print_success "LocalSend installed via Flatpak"
        else
            # Install flatpak, then LocalSend
            sudo apt install -y flatpak
            flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
            flatpak install -y flathub org.localsend.localsend_app
            print_success "LocalSend installed via Flatpak"
        fi
    else
        print_status "LocalSend already installed"
    fi

    print_success "Network tools installation complete"
}

install_remote_access_tools() {
    print_status "Installing remote access tools (NoMachine and OpenSSH)"

    # Install OpenSSH Server
    print_status "Installing OpenSSH Server..."
    sudo apt-get update
    sudo apt-get install -y openssh-server

    # Enable and start SSH service
    sudo systemctl enable ssh
    sudo systemctl start ssh

    # Install NoMachine (auto-detect latest version, fallback to pinned)
    if dpkg -l nomachine &>/dev/null 2>&1; then
        print_status "NoMachine already installed"
        print_success "Remote access tools installation complete"
        return 0
    fi

    print_status "Installing NoMachine..."

    # Use known stable version (auto-detect is unreliable)
    NOMACHINE_VERSION="8.14.2"
    NOMACHINE_URL="https://download.nomachine.com/download/${NOMACHINE_VERSION%.*}/Linux/nomachine_${NOMACHINE_VERSION}_1_amd64.deb"

    print_status "Downloading NoMachine ${NOMACHINE_VERSION}..."
    wget -q "${NOMACHINE_URL}" -O /tmp/nomachine.deb

    # Verify it's actually a .deb file (not an HTML error page)
    if file /tmp/nomachine.deb | grep -q "Debian binary package"; then
        print_status "Installing NoMachine package..."
        sudo dpkg -i /tmp/nomachine.deb
        sudo apt-get install -f -y
    else
        print_warning "NoMachine download failed (got HTML instead of .deb)"
        print_status "Install manually from: https://www.nomachine.com/download/linux&id=1"
    fi

    rm -f /tmp/nomachine.deb

    print_success "Remote access tools installation complete"
    print_warning "Remember to configure your firewall to allow SSH (port 22) and NoMachine (port 4000) if needed"
}

install_ghostty() {
    if command -v ghostty &>/dev/null; then
        print_status "Ghostty already installed"
        return 0
    fi

    ensure_brew_env
    print_status "Installing Ghostty terminal via Homebrew..."

    if brew install ghostty; then
        print_success "Ghostty installed via Homebrew"
    else
        print_warning "Ghostty installation failed — try manually: brew install ghostty"
    fi
}

install_nerd_fonts() {
    print_status "Installing Nerd Fonts"

    # Ask user which installation method to use
    if command -v whiptail >/dev/null 2>&1; then
        if whiptail --title "Nerd Fonts Installation" --yesno "Would you like to use getnf for interactive font installation?\n\nChoose:\n- Yes: Interactive installation with getnf\n- No: Default installation with pre-selected fonts" 12 78; then
            install_nerd_fonts_getnf
        else
            install_nerd_fonts_default
        fi
    else
        # Fall back to default installation if whiptail is not available
        install_nerd_fonts_default
    fi
}

install_nerd_fonts_getnf() {
    print_status "Installing getnf..."

    # Ensure required dependencies
    if ! command -v curl >/dev/null 2>&1; then
        print_error "curl is required for getnf installation"
        return 1
    fi

    # Install getnf if missing
    if ! command -v getnf >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/getnf" ]; then
        if ! curl -fsSL https://raw.githubusercontent.com/getnf/getnf/main/install.sh | bash; then
            print_error "Failed to install getnf"
            return 1
        fi
    fi

    # Ensure ~/.local/bin is on PATH for this run
    export PATH="$HOME/.local/bin:$PATH"
    local GETNF="${GETNF:-$HOME/.local/bin/getnf}"

    if [ ! -x "$GETNF" ]; then
        print_error "getnf not found at $GETNF"
        return 1
    fi

    print_status "Installing fonts using getnf..."
    if command -v fzf >/dev/null 2>&1; then
        "$GETNF" -f  # interactive selection with fzf
    else
        "$GETNF"     # standard selection
    fi

    # Update font cache
    print_status "Updating font cache..."
    fc-cache -f || sudo fc-cache -f

    print_success "Nerd Fonts installation complete using getnf"
}

install_nerd_fonts_default() {
    # Essential fonts only — add more to the list if needed
    # JetBrainsMono: primary dev font (wezterm, kitty, nvim)
    # Meslo: popular fallback / powerlevel10k default
    # FiraCode: ligatures alternative
    # UbuntuMono: system UI fallback
    local fonts=(JetBrainsMono Meslo FiraCode UbuntuMono)

    local fonts_dir="${HOME}/.local/share/fonts"
    mkdir -p "$fonts_dir"

    # Get latest version from GitHub API
    local version
    version=$(curl -s 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest' | jq -r '.name')
    if [ -z "$version" ] || [ "$version" = "null" ]; then
        version="v3.3.0"
    fi
    print_status "Using Nerd Fonts version: $version"

    for font in "${fonts[@]}"; do
        # Skip if font files already exist in fonts dir
        if ls "$fonts_dir"/${font}*.ttf &>/dev/null 2>&1 || ls "$fonts_dir"/${font}*.otf &>/dev/null 2>&1; then
            print_status "$font already installed, skipping..."
            continue
        fi
        print_status "Downloading $font..."
        local zip_file="${font}.zip"
        local download_url="https://github.com/ryanoasis/nerd-fonts/releases/download/${version}/${zip_file}"
        if wget -q "$download_url"; then
            unzip -o "$zip_file" -d "$fonts_dir"
            rm "$zip_file"
        else
            print_warning "Failed to download $font, skipping..."
            continue
        fi
    done

    # Clean up Windows Compatible files
    find "$fonts_dir" -name '*Windows Compatible*' -delete

    # Update font cache
    print_status "Updating font cache..."
    fc-cache -fv || sudo fc-cache -fv

    print_success "Nerd Fonts installation complete"
}

install_miniconda() {
    print_status "Installing Miniconda"

    if command -v conda &>/dev/null; then
        print_status "Miniconda/Conda is already installed"
        return
    fi

    # Create miniconda directory
    mkdir -p ~/miniconda3

    # Download and install Miniconda
    print_status "Downloading Miniconda installer..."
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh

    print_status "Installing Miniconda..."
    bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
    rm ~/miniconda3/miniconda.sh

    # Initialize conda for shells
    print_status "Initializing conda..."
    ~/miniconda3/bin/conda init bash
    ~/miniconda3/bin/conda init zsh

    print_success "Miniconda installation complete"
    print_warning "Please restart your shell or run 'source ~/.zshrc' to use conda"
}

install_gdu() {
    if [ -x "$HOME/.local/bin/gdu" ]; then
        print_status "GDU already installed"
        return 0
    fi

    print_status "Installing GDU (Go Disk Usage)"

    # Create temporary directory
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir"

    # Download and extract latest GDU
    print_status "Downloading GDU..."
    curl -L https://github.com/dundee/gdu/releases/latest/download/gdu_linux_amd64.tgz | tar xz

    # Make executable and move to local bin
    chmod +x gdu_linux_amd64
    mkdir -p ~/.local/bin
    mv gdu_linux_amd64 ~/.local/bin/gdu

    # Clean up
    cd - >/dev/null
    rm -rf "$temp_dir"

    print_success "GDU installed to ~/.local/bin/gdu"
}

# Improved GRUB configuration function
update_grub_config() {
    print_status "GRUB Configuration Options"

    # Backup original grub file if backup doesn't exist
    if [ ! -f "/etc/default/grub.backup" ]; then
        sudo cp /etc/default/grub /etc/default/grub.backup
        print_status "Created backup of original GRUB configuration"
    fi

    # Show current configuration
    print_status "Current GRUB configuration:"
    grep "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub

    # Ask user what they want to do with GRUB
    if command -v whiptail >/dev/null 2>&1; then
        GRUB_CHOICE=$(whiptail --title "GRUB Configuration" --menu "Choose GRUB configuration option:" 16 80 5 \
            "1" "Remove 'quiet splash' (show detailed boot messages)" \
            "2" "Keep current settings (recommended)" \
            "3" "Reset to minimal settings (no parameters)" \
            "4" "Add custom kernel parameters" \
            "5" "Skip GRUB configuration" \
            3>&1 1>&2 2>&3)
    else
        echo ""
        echo "GRUB Configuration Options:"
        echo "1) Remove 'quiet splash' (show detailed boot messages)"
        echo "2) Keep current settings (recommended)"
        echo "3) Reset to minimal settings (no parameters)"
        echo "4) Add custom kernel parameters"
        echo "5) Skip GRUB configuration"
        read -p "Choose an option (1-5): " GRUB_CHOICE
    fi

    case $GRUB_CHOICE in
        1)
            # Remove quiet splash
            print_status "Removing 'quiet splash' from GRUB..."
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=".*quiet.*splash.*"/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub
            ;;
        2)
            print_status "Keeping current GRUB settings..."
            return 0
            ;;
        3)
            # Reset to minimal
            print_status "Resetting GRUB to minimal settings..."
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub
            ;;
        4)
            # Add custom parameters
            print_status "Current GRUB configuration:"
            grep "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub
            echo ""
            echo "Common kernel parameters:"
            echo "  pci=nommconf          - Disable memory-mapped PCI config (for old hardware)"
            echo "  usbcore.autosuspend=-1 - Disable USB autosuspend"
            echo "  systemd.unit=multi-user.target - Boot to text mode"
            echo ""
            read -p "Enter additional kernel parameters (or press Enter to skip): " custom_params
            if [ -n "$custom_params" ]; then
                current_cmdline=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub | cut -d'"' -f2)
                new_cmdline="$current_cmdline $custom_params"
                sudo sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\".*\"|GRUB_CMDLINE_LINUX_DEFAULT=\"$new_cmdline\"|" /etc/default/grub
                print_status "Added custom parameters: $custom_params"
            fi
            ;;
        5|*)
            print_status "Skipping GRUB configuration"
            return 0
            ;;
    esac

    # Update GRUB
    if sudo update-grub; then
        print_success "GRUB configuration updated successfully"
        print_status "New GRUB configuration:"
        grep "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub
        print_warning "Reboot required for GRUB changes to take effect"
    else
        print_error "Failed to update GRUB"
        return 1
    fi
}

verify_setup() {
    print_status "Verifying installation..."

    local tools=(
        zsh starship wezterm zellij nvim rg fzf fd ghq
        zoxide tree bat eza git duf btm tree-sitter
    )

    local missing=0

    # Check regular tools
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            print_error "$tool not found"
            missing=1
        else
            print_success "$tool installed"
        fi
    done

    # Special check for trash-cli commands from Homebrew
    local trash_commands=(trash-put trash-list trash-restore trash-rm trash-empty)
    local trash_missing=0
    for cmd in "${trash_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            trash_missing=1
            break
        fi
    done
    if [ $trash_missing -eq 1 ]; then
        print_error "trash-cli not found"
        missing=1
    else
        print_success "trash-cli installed"
    fi

    # Check for GDU in ~/.local/bin
    if [ -x "$HOME/.local/bin/gdu" ]; then
        print_success "gdu installed"
    else
        print_error "gdu not found"
        missing=1
    fi

    [ $missing -eq 1 ] && print_warning "Some tools are missing. Check the logs."
}

# Improved dotfiles setup function
setup_dotfiles_integrated() {
    print_status "Setting up dotfiles configuration"

    # Check if dotfiles.sh exists
    if [ -f "./dotfiles.sh" ]; then
        print_status "Found dotfiles.sh script, executing..."

        # Make sure it's executable
        chmod +x ./dotfiles.sh

        # Run the dotfiles script
        if ./dotfiles.sh; then
            print_success "Dotfiles setup completed successfully"
        else
            print_error "Dotfiles setup failed"
            print_warning "You can run './dotfiles.sh' manually later"
            return 1
        fi
    else
        print_warning "dotfiles.sh not found in current directory"
        print_status "Expected location: $(pwd)/dotfiles.sh"
        print_status "You can run dotfiles setup manually later"
    fi
}

# Improved execute_subscript function with better error handling
execute_subscript() {
    local script_name="$1"
    local script_path
    local is_optional="${2:-false}"  # Second parameter for optional scripts

    script_path="$(dirname "$(realpath "$0")")/$script_name"

    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        if [[ "$is_optional" == "true" ]]; then
            print_warning "Optional script not found: $script_name - skipping"
        else
            print_error "Required script not found: $script_name"
            print_status "Expected location: $script_path"
            return 1
        fi
        return 0
    fi

    # Check if script is executable
    if [[ ! -x "$script_path" ]]; then
        print_status "Making $script_name executable..."
        chmod +x "$script_path" || {
            print_error "Failed to make $script_name executable"
            return 1
        }
    fi

    print_status "Executing $script_name..."

    # Refresh sudo before launching subscript (prevents password prompt mid-output)
    sudo -v

    # Export variables for the subscript
    export BREW_PREFIX="$(brew --prefix 2>/dev/null || echo "")"
    export SCRIPT_DIR="$(dirname "$(realpath "$0")")"

    # Execute the script with timeout for safety, from its own directory
    local run_dir
    run_dir="$(dirname "$script_path")"
    if timeout 1800 bash -c "
        set -e
        cd \"$run_dir\"
        bash \"$script_path\"
    "; then  # 30 minute timeout
        print_success "$script_name completed successfully"
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            print_error "$script_name timed out after 30 minutes"
        else
            print_error "$script_name failed with exit code $exit_code"
        fi

        if [[ "$is_optional" == "true" ]]; then
            print_warning "Continuing installation despite $script_name failure..."
            return 0
        else
            return $exit_code
        fi
    fi
}

# Function to install SSH tools (no SSH key requirements)
install_ssh_tools() {
    print_status "Installing SSH tools"

    # Install SSH client tools
    sudo apt install -y openssh-client sshpass

    # Install SSH askpass
    sudo apt install -y ssh-askpass-gnome || sudo apt install -y ssh-askpass

    print_success "SSH tools installed"
    print_status "You can configure SSH keys later if needed"
}

main() {
    # Direct command handling for all commands
    if [ -n "$1" ]; then
        case "$1" in
            "help"|"-h"|"--help")
                echo "Usage: $0 [command]"
                echo "Commands:"
                echo "  all      - Install all components (VirtualBox excluded)"
                echo "  base     - Install base development tools"
                echo "  shell    - Install shell tools"
                echo "  neovim   - Install Neovim (expects Node if you want Node provider)"
                echo "  node     - Install Node.js environment"
                echo "  docker   - Install Docker"
                echo "  ghostty  - Install Ghostty terminal"
                echo "  dotfiles - Setup dotfiles configuration"
                echo "  grub     - Update GRUB configuration"
                echo "  help     - Show this help message"
                echo ""
                echo "If no command is provided, interactive menu will be shown."
                exit 0
                ;;
        esac

        # For all other commands, run initial setup
        check_system
        maintain_sudo
        install_essential_dependencies
        install_homebrew

        case "$1" in
            "all")
                install_base_development
                install_shell_tools
                install_version_control
                install_miniconda
                # Install Node BEFORE Neovim
                execute_subscript "node.sh"
                setup_neovim
                execute_subscript "rust.sh"
                execute_subscript "go.sh"
                execute_subscript "docker.sh"
                install_browsers
                execute_subscript "kitty.sh" "true"
                install_ghostty
                setup_dotfiles_integrated
                install_ssh_tools
                install_network_tools
                install_nerd_fonts
                install_remote_access_tools
                # VirtualBox intentionally excluded (manual install)
                update_grub_config
                ;;
            "base")
                install_base_development
                ;;
            "shell")
                install_shell_tools
                ;;
            "neovim")
                setup_neovim
                ;;
            "node")
                execute_subscript "node.sh"
                ;;
            "docker")
                execute_subscript "docker.sh"
                ;;
            "ghostty")
                install_ghostty
                ;;
            "dotfiles")
                setup_dotfiles_integrated
                ;;
            "grub")
                update_grub_config
                ;;
            *)
                echo "Unknown command: $1"
                echo "Run '$0 help' for usage information"
                exit 1
                ;;
        esac
        verify_setup
        print_success "Installation complete!"
        print_warning "Please log out and log back in for all changes to take effect."
        exit 0
    fi

    # Interactive menu mode
    export NEWT_COLORS='
    root=,black
    window=white,black
    shadow=,black
    border=white,black
    title=white,black
    textbox=white,black
    button=black,white
    actbutton=black,yellow
    compactbutton=white,black
    checkbox=white,black
    actcheckbox=black,yellow
    entry=white,black
    disentry=gray,black
    label=white,black
    listbox=white,black
    actlistbox=black,yellow
    sellistbox=black,blue
    actsellistbox=white,blue
    '

    # Initial checks
    check_system
    maintain_sudo

    # Install essential dependencies first
    install_essential_dependencies

    # Install Homebrew
    install_homebrew

    # Installation options
    options=(
        "0" "Install All Components (VirtualBox excluded)" ON
        "1" "Base Development Tools" OFF
        "2" "Shell Tools (Zsh)" OFF
        "3" "Version Control Tools" OFF
        "4" "Miniconda" OFF
        "5" "Neovim Setup" OFF
        "6" "Node.js Environment" OFF
        "7" "Rust Tools" OFF
        "8" "Go Environment" OFF
        "9" "Docker" OFF
        "10" "Browsers" OFF
        "11" "Kitty Terminal" OFF
        "12" "Ghostty Terminal" OFF
        "13" "Dotfiles Configuration" OFF
        "14" "SSH Tools" OFF
        "15" "Network Tools" OFF
        "16" "Nerd Fonts" OFF
        "17" "Remote Access Tools (NoMachine + SSH)" OFF
        "18" "AI Agent Tools (Claude Code, OpenCode, etc.)" OFF
        "19" "VirtualBox (Removed — install manually)" OFF
        "20" "Update GRUB Configuration" OFF
    )

    choices=$(whiptail --title "Installation Options" \
        --checklist "Select components to install (Install All is selected by default):" \
        28 78 20 \
        "${options[@]}" \
        3>&1 1>&2 2>&3)

    [ $? -ne 0 ] && {
        print_error "Setup cancelled."
        exit 1
    }

    # Update system
    sudo apt update && sudo apt upgrade -y

    # Process installations
    if [[ $choices == *'"0"'* ]]; then
        # Install everything (VirtualBox excluded)
        install_base_development
        install_shell_tools
        install_version_control
        install_miniconda
        execute_subscript "node.sh"
        setup_neovim
        execute_subscript "rust.sh"
        execute_subscript "go.sh"
        execute_subscript "docker.sh"
        install_browsers
        execute_subscript "kitty.sh" "true"
        install_ghostty
        setup_dotfiles_integrated
        install_ssh_tools
        install_network_tools
        install_nerd_fonts
        install_remote_access_tools
        update_grub_config
    else
        # Individual selections (ensure Node before Neovim if both chosen)
        node_selected=false
        neovim_selected=false

        [[ $choices == *'"6"'* ]] && node_selected=true
        [[ $choices == *'"5"'* ]] && neovim_selected=true

        # Always run Node before Neovim if both selected
        if $node_selected; then
            execute_subscript "node.sh"
        fi
        if $neovim_selected; then
            setup_neovim
        fi

        [[ $choices == *'"1"'* ]] && install_base_development
        [[ $choices == *'"2"'* ]] && install_shell_tools
        [[ $choices == *'"3"'* ]] && install_version_control
        [[ $choices == *'"4"'* ]] && install_miniconda
        [[ $choices == *'"7"'* ]] && execute_subscript "rust.sh"
        [[ $choices == *'"8"'* ]] && execute_subscript "go.sh"
        [[ $choices == *'"9"'* ]] && execute_subscript "docker.sh"
        [[ $choices == *'"10"'* ]] && install_browsers
        [[ $choices == *'"11"'* ]] && execute_subscript "kitty.sh" "true"
        [[ $choices == *'"12"'* ]] && install_ghostty
        [[ $choices == *'"13"'* ]] && setup_dotfiles_integrated
        [[ $choices == *'"14"'* ]] && install_ssh_tools
        [[ $choices == *'"15"'* ]] && install_network_tools
        [[ $choices == *'"16"'* ]] && install_nerd_fonts
        [[ $choices == *'"17"'* ]] && install_remote_access_tools
        [[ $choices == *'"18"'* ]] && execute_subscript "agent.sh"
        if [[ $choices == *'"19"'* ]]; then
            print_warning "VirtualBox install is removed from this script. Please download from the website and install manually."
        fi
        [[ $choices == *'"20"'* ]] && update_grub_config
    fi

    verify_setup
    change_default_shell

    print_success "Installation complete!"
    print_warning "Please log out and log back in for all changes to take effect."
}

main "$@"
