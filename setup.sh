#!/bin/bash

set -e

# Source common functions
source ./common.sh

# Check if script is run with sudo
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script with sudo or as root."
    exit 1
fi

# Add this helper function at the top of the script
ensure_brew_env() {
    if ! command -v brew &>/dev/null; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
}

# Function to check SSH agent and keys
check_ssh_setup() {
    print_status "Checking SSH setup..."

    if ! pgrep -u "$USER" ssh-agent >/dev/null; then
        eval "$(ssh-agent -s)" >/dev/null
    fi

    # Add SSH keys to the agent (looking for any id_ed25519 or id_rsa key)
    if ! ssh-add -l &>/dev/null; then
        # Add all id_ed25519 and id_rsa keys from ~/.ssh
        for key in ~/.ssh/id_ed25519* ~/.ssh/id_rsa*; do
            if [[ -f "$key" ]]; then
                print_status "Adding SSH key: $key"
                ssh-add "$key" &>/dev/null
            fi
        done

        # If no key is added, show error and exit
        if ! ssh-add -l &>/dev/null; then
            print_error "No SSH keys found. Please set up SSH keys first."
            exit 1
        fi
    fi

    # Check GitHub access
    if ssh -T git@github.com 2>&1 | grep -q "success"; then
        print_status "GitHub SSH access verified"
    else
        print_error "GitHub SSH access not available"
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

setup_chezmoi() {
    ensure_brew_env

    print_status "Setting up Chezmoi"

    # Install chezmoi using Homebrew for latest version
    brew install chezmoi

    # Initialize chezmoi if not already done
    if [ ! -d "$HOME/.local/share/chezmoi" ]; then
        print_status "Initializing Chezmoi..."
        
        if chezmoi init git@github.com:y37y/chezmoi-ubuntu.git; then
            print_success "Initialized from GitHub successfully"

            # Setup Neovim configuration directory if it doesn't exist
            if [ ! -d "$HOME/.local/share/chezmoi/dot_config/nvim" ]; then
                print_status "Setting up Neovim configuration in Chezmoi..."
                mkdir -p "$HOME/.local/share/chezmoi/dot_config"
                
                print_status "Cloning Neovim configuration..."
                if git clone git@github.com:y37y/nvim-config.git "$HOME/.local/share/chezmoi/dot_config/nvim"; then
                    print_success "Cloned from GitHub successfully"
                else
                    print_error "Failed to clone from GitHub"
                    return 1
                fi
                
                cd "$HOME/.local/share/chezmoi/dot_config/nvim"
                
                # Setup upstream for Neovim configuration
                git remote add upstream https://github.com/chaozwn/astronvim_user
                git fetch upstream
                
                # Initialize and update submodules
                git submodule update --init --recursive
                
                cd - > /dev/null
            fi

            # Apply chezmoi configuration
            if ! chezmoi apply; then
                print_warning "Some chezmoi files couldn't be applied. Run 'chezmoi apply' after logging back in."
            fi
        else
            print_error "Failed to initialize from GitHub"
            return 1
        fi
    else
        print_status "Chezmoi already initialized, updating..."
        chezmoi update
        
        # Update Neovim configuration if it exists
        if [ -d "$HOME/.local/share/chezmoi/dot_config/nvim" ]; then
            print_status "Updating Neovim configuration..."
            cd "$HOME/.local/share/chezmoi/dot_config/nvim"
            
            git fetch origin
            git fetch upstream
            
            # Update submodules
            git submodule update --init --recursive
            
            cd - > /dev/null
        fi
    fi

    print_success "Chezmoi setup complete"
    print_status "Chezmoi workflow reminders:"
    print_status "1. Make changes in ~/.local/share/chezmoi/dot_config/nvim"
    print_status "2. Use 'chezmoi apply' to apply changes"
    print_status "3. Use 'chezmoi update' to pull latest changes"
    print_status "4. For Neovim updates, don't modify ~/.config/nvim directly"
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
    sudo apt install -y build-essential curl python3-pip pipx python3-venv ca-certificates \
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

    print_status "Installing shell tools"

    # Fish shell setup (only if not already installed)
    if ! command -v fish &>/dev/null; then
        brew install fish
        if ! grep -q "/home/linuxbrew/.linuxbrew/bin/fish" /etc/shells; then
            echo /home/linuxbrew/.linuxbrew/bin/fish | sudo tee -a /etc/shells
        fi
    fi

    # Shell tools (will skip already installed ones)
    brew install nushell fzf eza zoxide ripgrep fd starship \
        tmux zellij ghq tree sshpass bat yazi duf bottom \
        tree-sitter

    # Setup fisher and plugins if not already done
    if ! test -f ~/.config/fish/functions/fisher.fish; then
        fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'
        fish -c 'fisher install edc/bass'
    fi

    # Install Atuin shell history sync
    print_status "Installing Atuin..."
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh

    # WezTerm
    if ! command -v wezterm &>/dev/null; then
        curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
        echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
        sudo apt update && sudo apt install -y wezterm-nightly
    fi
}

change_default_shell() {
    if [[ "$SHELL" != "/home/linuxbrew/.linuxbrew/bin/fish" ]]; then
        print_status "Changing default shell to fish..."
        if ! grep -q "/home/linuxbrew/.linuxbrew/bin/fish" /etc/shells; then
            echo /home/linuxbrew/.linuxbrew/bin/fish | sudo tee -a /etc/shells
        fi
        chsh -s /home/linuxbrew/.linuxbrew/bin/fish
        print_warning "Shell change will take effect after you log out and back in"
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
    
    # Detailed post-installation instructions
    echo "
    Network Tools Post-Installation Steps:

    Tailscale:
    - To start Tailscale: sudo tailscale up
    - To get status: tailscale status
    - To disable: sudo tailscale down

    ZeroTier:
    - To join a network: sudo zerotier-cli join <your-network-id>
    - To check status: sudo zerotier-cli status
    - To leave a network: sudo zerotier-cli leave <your-network-id>

    Note: You can enable/disable these services as needed using:
    - Tailscale: sudo systemctl enable/disable tailscaled
    - ZeroTier: sudo systemctl enable/disable zerotier-one
    "
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
    ~/miniconda3/bin/conda init fish

    print_success "Miniconda installation complete"
    print_warning "Please restart your shell or run 'source ~/.bashrc' to use conda"
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
        fish starship wezterm zellij nvim rg fzf fd ghq
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

execute_subscript() {
    local script_name="$1"
    local script_path
    script_path="$(dirname "$(realpath "$0")")/$script_name"

    if [[ ! -f "$script_path" ]]; then
        print_error "Script not found: $script_name"
        return 1
    fi

    print_status "Executing $script_name..."

    local brew_prefix
    brew_prefix="$(brew --prefix)"
    export BREW_PREFIX="$brew_prefix"

    (
        cd "$(dirname "$script_path")"
        source "$script_path"
        if declare -F "install_node_environment" >/dev/null; then
            install_node_environment
        fi
    )

    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        print_error "$script_name failed with exit code $exit_code"
        return $exit_code
    fi
}

main() {
    # Direct command handling for all commands
    if [ -n "$1" ]; then
        case "$1" in
            "help"|"-h"|"--help")
                echo "Usage: $0 [command]"
                echo "Commands:"
                echo "  all     - Install all components"
                echo "  base    - Install base development tools"
                echo "  shell   - Install shell tools"
                echo "  neovim  - Install Neovim"
                echo "  grub    - Update GRUB configuration"
                echo "  help    - Show this help message"
                echo ""
                echo "If no command is provided, interactive menu will be shown."
                exit 0
                ;;
        esac

        # For all other commands
        check_system
        check_ssh_setup
        maintain_sudo
        sudo apt update && sudo apt upgrade -y

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
                setup_chezmoi
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
    check_ssh_setup
    maintain_sudo

    # Install Homebrew if needed
    if ! command -v brew &>/dev/null; then
        print_status "Installing Homebrew"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi

    # Installation options
    options=(
        "0" "Install All Components" ON
        "1" "Base Development Tools" OFF
        "2" "Shell Tools" OFF
        "3" "Version Control Tools" OFF
        "4" "Miniconda" OFF
        "5" "Neovim Setup" OFF
        "6" "Node.js Environment" OFF
        "7" "Rust Tools" OFF
        "8" "Go Environment" OFF
        "9" "Browsers" OFF
        "10" "Chezmoi Dotfiles" OFF
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
        setup_chezmoi
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
        [[ $choices == *'"10"'* ]] && setup_chezmoi
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
