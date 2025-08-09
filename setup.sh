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
    sudo apt install -y build-essential curl git wget ca-certificates
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
    ensure_brew_env

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

    # Install Node.js provider and dependencies
    if command -v npm &>/dev/null; then
        print_status "Installing Node.js provider and dependencies..."
        sudo npm install -g neovim tree-sitter-cli @styled/typescript-styled-plugin
    else
        print_warning "Node.js not found. Skipping Node.js provider installation."
    fi

    # Backup existing configuration
    if [ -d ~/.config/nvim ]; then
        print_status "Backing up existing Neovim configuration..."
        mv ~/.config/nvim ~/.config/nvim.bak.$(date +%Y%m%d_%H%M%S)
        rm -rf ~/.local/share/nvim
        rm -rf ~/.local/state/nvim
        rm -rf ~/.cache/nvim
    fi

    # Clone Neovim configuration
    if [ ! -d ~/.config/nvim ]; then
        print_status "Installing your Neovim configuration..."
        git clone --recursive https://github.com/y37y/nvim.git ~/.config/nvim
        cd ~/.config/nvim
        
        # Set up upstream remote
        git remote add upstream https://github.com/chaozwn/astronvim_user
        git fetch upstream
        
        # Initialize and update submodules
        git submodule update --init --recursive --force
        git submodule foreach git pull origin master
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
        procs fastfetch hyperfine httpie tldr tokei broot jq yq wget bat yazi \
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

    print_status "Installing shell tools for Zsh"

    # Install Zsh and related tools
    brew install zsh fzf eza zoxide ripgrep fd starship \
        tmux zellij ghq tree bat yazi duf bottom \
        tree-sitter

    # Install Atuin shell history sync
    print_status "Installing Atuin..."
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh

    # WezTerm
    if ! command -v wezterm &>/dev/null; then
        curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
        echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
        sudo apt update && sudo apt install -y wezterm-nightly
    fi

    # Setup Zsh configuration
    setup_zsh_environment
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
    print_status "Installing version control tools"
    brew install git git-lfs lazygit lazydocker gh difftastic
    git lfs install
}

install_browsers() {
    print_status "Installing browsers"

    # Chrome
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo apt install -y ./google-chrome-stable_current_amd64.deb
    rm google-chrome-stable_current_amd64.deb

    # Edge
    curl -fSsL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor | sudo tee /usr/share/keyrings/microsoft-edge.gpg >/dev/null
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-edge.gpg] https://packages.microsoft.com/repos/edge stable main" | sudo tee /etc/apt/sources.list.d/microsoft-edge.list
    sudo apt update && sudo apt install -y microsoft-edge-stable

    # Brave
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
    sudo apt update && sudo apt install -y brave-browser
}

install_network_tools() {
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

    # Install NoMachine
    print_status "Installing NoMachine..."

    # Latest stable version of NoMachine
    NOMACHINE_VERSION="8.14.2"
    NOMACHINE_URL="https://download.nomachine.com/download/${NOMACHINE_VERSION%.*}/Linux/nomachine_${NOMACHINE_VERSION}_1_amd64.deb"

    print_status "Downloading NoMachine ${NOMACHINE_VERSION}..."
    wget "${NOMACHINE_URL}" -O nomachine.deb

    # Install the package
    print_status "Installing NoMachine package..."
    sudo dpkg -i nomachine.deb
    sudo apt-get install -f -y # Install any missing dependencies

    # Clean up
    rm nomachine.deb

    print_success "Remote access tools installation complete"
    print_warning "Remember to configure your firewall to allow SSH (port 22) and NoMachine (port 4000) if needed"
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

    # Install getnf
    if ! curl -fsSL https://raw.githubusercontent.com/getnf/getnf/main/install.sh | bash; then
        print_error "Failed to install getnf"
        return 1
    fi

    print_status "Installing fonts using getnf..."
    if command -v fzf >/dev/null 2>&1; then
        getnf -f  # Use interactive fzf selection if available
    else
        getnf     # Fall back to standard selection
    fi

    # Update font cache
    print_status "Updating font cache..."
    fc-cache -f || sudo fc-cache -f

    print_success "Nerd Fonts installation complete using getnf"
}

install_nerd_fonts_default() {
    # list from getnf
    local fonts=(BitstreamVeraSansMono CascadiaCode CodeNewRoman DroidSansMono FiraCode FiraMono Go-Mono Hack Hermit JetBrainsMono Meslo Noto Overpass ProggyClean RobotoMono SourceCodePro SpaceMono Ubuntu UbuntuMono)

    local fonts_dir="${HOME}/.local/share/fonts"
    mkdir -p "$fonts_dir"

    # Get latest version from GitHub API
    local version=$(curl -s 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest' | jq -r '.name')
    if [ -z "$version" ] || [ "$version" = "null" ]; then
        version="v3.3.0"
    fi
    print_status "Using Nerd Fonts version: $version"

    for font in "${fonts[@]}"; do
        print_status "Downloading $font..."
        local zip_file="${font}.zip"
        local download_url="https://github.com/ryanoasis/nerd-fonts/releases/download/${version}/${zip_file}"
        if wget "$download_url"; then
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
    print_status "Installing GDU (Go Disk Usage)"

    # Create temporary directory
    local temp_dir=$(mktemp -d)
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

update_grub_config() {
    print_status "Updating GRUB configuration..."
    
    # Backup original grub file if backup doesn't exist
    if [ ! -f "/etc/default/grub.backup" ]; then
        sudo cp /etc/default/grub /etc/default/grub.backup
        print_status "Created backup of original GRUB configuration"
    fi

    # Define required kernel parameters
    local required_params=(
        "pci=nommconf"
    )

    # Read current GRUB configuration
    local current_cmdline
    current_cmdline=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub | cut -d'"' -f2)
    
    # Create a temporary file for the new configuration
    local temp_grub
    temp_grub=$(mktemp)
    
    # Process the configuration
    while IFS= read -r line; do
        if [[ $line =~ ^GRUB_CMDLINE_LINUX_DEFAULT= ]]; then
            # Start with an empty parameter set
            local new_params=()
            
            # Add existing parameters that aren't in our required set
            for param in $current_cmdline; do
                found=0
                for req in "${required_params[@]}"; do
                    if [ "$param" = "$req" ]; then
                        found=1
                        break
                    fi
                done
                if [ "$found" -eq 0 ] && [[ $param != GRUB_CMDLINE_LINUX_DEFAULT* ]]; then
                    new_params+=("$param")
                fi
            done
            
            # Add our required parameters
            new_params+=("${required_params[@]}")
            
            # Join parameters with spaces
            local new_cmdline
            new_cmdline=$(printf "%s " "${new_params[@]}" | sed 's/ $//')
            
            # Write the new line
            echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$new_cmdline\"" >> "$temp_grub"
        else
            echo "$line" >> "$temp_grub"
        fi
    done < /etc/default/grub
    
    # Verify the new configuration
    if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" "$temp_grub"; then
        # Apply the new configuration
        sudo cp "$temp_grub" /etc/default/grub
        print_status "Updated GRUB parameters"
    else
        print_error "Failed to update GRUB configuration"
        rm "$temp_grub"
        return 1
    fi
    
    # Clean up
    rm "$temp_grub"
    
    # Update GRUB
    if sudo update-grub; then
        print_success "GRUB configuration updated successfully"
        print_warning "A system reboot is required for changes to take effect"
    else
        print_error "Failed to update GRUB"
        return 1
    fi
}

verify_setup() {
    print_status "Verifying installation..."

    local tools=(
        zsh starship wezterm zellij nvim rg fzf fd ghq
        zoxide tree bat eza git yazi duf btm tree-sitter
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

# Improved execute_subscript function with better error handling
execute_subscript() {
    local script_name="$1"
    local script_path
    script_path="$(dirname "$(realpath "$0")")/$script_name"

    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        print_warning "Script not found: $script_name - skipping"
        return 0  # Return 0 to continue with other installations
    fi

    # Check if script is executable
    if [[ ! -x "$script_path" ]]; then
        print_status "Making $script_name executable..."
        chmod +x "$script_path"
    fi

    print_status "Executing $script_name..."

    # Export variables for the subscript
    export BREW_PREFIX="$(brew --prefix 2>/dev/null || echo "")"
    
    # Execute the script in a subshell
    if bash "$script_path"; then
        print_success "$script_name completed successfully"
    else
        local exit_code=$?
        print_error "$script_name failed with exit code $exit_code"
        return $exit_code
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
                echo "  all      - Install all components"
                echo "  base     - Install base development tools"
                echo "  shell    - Install shell tools"
                echo "  neovim   - Install Neovim"
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
                setup_neovim
                execute_subscript "node.sh"
                execute_subscript "rust.sh"
                execute_subscript "go.sh"
                install_browsers
                execute_subscript "dotfiles.sh"
                install_ssh_tools
                install_network_tools
                install_nerd_fonts
                install_remote_access_tools
                execute_subscript "virtualbox.sh"
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
            "dotfiles")
                execute_subscript "dotfiles.sh"
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
        "0" "Install All Components" ON
        "1" "Base Development Tools" OFF
        "2" "Shell Tools (Zsh)" OFF
        "3" "Version Control Tools" OFF
        "4" "Miniconda" OFF
        "5" "Neovim Setup" OFF
        "6" "Node.js Environment" OFF
        "7" "Rust Tools" OFF
        "8" "Go Environment" OFF
        "9" "Browsers" OFF
        "10" "Dotfiles Configuration" OFF
        "11" "SSH Tools" OFF
        "12" "Network Tools" OFF
        "13" "Nerd Fonts" OFF
        "14" "Remote Access Tools" OFF
        "15" "VirtualBox" OFF
        "16" "Update GRUB Configuration" OFF
    )

    choices=$(whiptail --title "Installation Options" \
        --checklist "Select components to install (Install All is selected by default):" \
        24 78 16 \
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
        # Install everything
        install_base_development
        install_shell_tools
        install_version_control
        install_miniconda
        setup_neovim
        execute_subscript "node.sh"
        execute_subscript "rust.sh"
        execute_subscript "go.sh"
        install_browsers
        execute_subscript "dotfiles.sh"
        install_ssh_tools
        install_network_tools
        install_nerd_fonts
        install_remote_access_tools
        execute_subscript "virtualbox.sh"
        update_grub_config
    else
        # Individual selections
        [[ $choices == *'"1"'* ]] && install_base_development
        [[ $choices == *'"2"'* ]] && install_shell_tools
        [[ $choices == *'"3"'* ]] && install_version_control
        [[ $choices == *'"4"'* ]] && install_miniconda
        [[ $choices == *'"5"'* ]] && setup_neovim
        [[ $choices == *'"6"'* ]] && execute_subscript "node.sh"
        [[ $choices == *'"7"'* ]] && execute_subscript "rust.sh"
        [[ $choices == *'"8"'* ]] && execute_subscript "go.sh"
        [[ $choices == *'"9"'* ]] && install_browsers
        [[ $choices == *'"10"'* ]] && execute_subscript "dotfiles.sh"
        [[ $choices == *'"11"'* ]] && install_ssh_tools
        [[ $choices == *'"12"'* ]] && install_network_tools
        [[ $choices == *'"13"'* ]] && install_nerd_fonts
        [[ $choices == *'"14"'* ]] && install_remote_access_tools
        [[ $choices == *'"15"'* ]] && execute_subscript "virtualbox.sh"
        [[ $choices == *'"16"'* ]] && update_grub_config
    fi

    verify_setup
    change_default_shell

    print_success "Installation complete!"
    print_warning "Please log out and log back in for all changes to take effect."
}

main "$@"
