#!/bin/bash

set -e

# Source common functions
source ./common.sh

# Initialize Homebrew if not already in PATH
if ! command -v brew &>/dev/null; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

install_dotfiles_environment() {
    print_status "Installing dotfiles from existing repositories"

    # Create Projects directory if it doesn't exist
    mkdir -p ~/Projects

    # Backup existing configurations first
    backup_existing_configs

    # Setup each dotfile repository
    setup_wezterm_dotfiles
    setup_kitty_dotfiles
    setup_tmux_dotfiles
    setup_zsh_dotfiles
    # Note: nvim is handled separately in setup.sh
    # Note: yazi dotfiles skipped by default — run 'setup_yazi_dotfiles' manually if needed

    print_success "Dotfiles environment setup complete"
    print_warning "Please restart your shell or run 'exec zsh' to apply all changes"
}

backup_existing_configs() {
    print_status "Backing up existing configurations..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$HOME/.config_backup_$timestamp"
    
    mkdir -p "$backup_dir"
    
    # Backup existing configs
    [ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$backup_dir/"
    [ -f "$HOME/.tmux.conf" ] && cp "$HOME/.tmux.conf" "$backup_dir/"
    [ -f "$HOME/.wezterm.lua" ] && cp "$HOME/.wezterm.lua" "$backup_dir/"
    [ -d "$HOME/.config/kitty" ] && cp -r "$HOME/.config/kitty" "$backup_dir/"
    [ -d "$HOME/.config/yazi" ] && cp -r "$HOME/.config/yazi" "$backup_dir/"
    [ -d "$HOME/.config/wezterm" ] && cp -r "$HOME/.config/wezterm" "$backup_dir/"
    
    if [ "$(ls -A "$backup_dir" 2>/dev/null)" ]; then
        print_success "Existing configurations backed up to $backup_dir"
    else
        rmdir "$backup_dir"
        print_status "No existing configurations found to backup"
    fi
}

setup_wezterm_dotfiles() {
    local repo_dir="$HOME/Projects/wezterm"
    local config_dir="$HOME/.config/wezterm"

    print_status "Setting up WezTerm dotfiles..."

    # Clone or update repository
    if [ ! -d "$repo_dir" ]; then
        print_status "Cloning WezTerm dotfiles repository..."
        git clone --recursive https://github.com/y37y/wezterm-ubuntu.git "$repo_dir"
    else
        print_status "Updating WezTerm dotfiles repository..."
        cd "$repo_dir"
        git pull origin main || git pull origin master
        # Update submodules (for wezterm-session-manager)
        git submodule update --init --recursive
        cd - > /dev/null
    fi

    # Create config directory
    mkdir -p "$config_dir"

    # Remove existing symlinks/files
    [ -L "$config_dir/wezterm.lua" ] && rm "$config_dir/wezterm.lua"
    [ -L "$HOME/.wezterm.lua" ] && rm "$HOME/.wezterm.lua"

    # Link all configuration files
    if [ -f "$repo_dir/wezterm.lua" ]; then
        ln -sf "$repo_dir/wezterm.lua" "$config_dir/wezterm.lua"
        print_success "WezTerm main configuration linked"
    elif [ -f "$repo_dir/.wezterm.lua" ]; then
        ln -sf "$repo_dir/.wezterm.lua" "$HOME/.wezterm.lua"
        print_success "WezTerm configuration linked to home directory"
    else
        print_warning "WezTerm main configuration file not found"
    fi

    # Link additional lua files (appearance.lua, etc.)
    for lua_file in "$repo_dir"/*.lua; do
        if [ -f "$lua_file" ] && [ "$(basename "$lua_file")" != "wezterm.lua" ]; then
            ln -sf "$lua_file" "$config_dir/$(basename "$lua_file")"
        fi
    done

    # Link subdirectories (like wezterm-session-manager)
    for subdir in "$repo_dir"/*/; do
        if [ -d "$subdir" ]; then
            local dirname=$(basename "$subdir")
            [ -L "$config_dir/$dirname" ] && rm "$config_dir/$dirname"
            ln -sf "$subdir" "$config_dir/$dirname"
        fi
    done

    print_success "WezTerm dotfiles setup complete"
}

setup_kitty_dotfiles() {
    local repo_dir="$HOME/Projects/kitty"
    local config_dir="$HOME/.config/kitty"

    print_status "Setting up Kitty dotfiles..."

    # Clone or update repository
    if [ ! -d "$repo_dir" ]; then
        print_status "Cloning Kitty dotfiles repository..."
        git clone https://github.com/y37y/kitty.git "$repo_dir"
    else
        print_status "Updating Kitty dotfiles repository..."
        cd "$repo_dir"
        git pull origin main || git pull origin master
        cd - > /dev/null
    fi

    # Create config directory
    mkdir -p "$config_dir"

    # Remove existing symlinks
    [ -L "$config_dir/kitty.conf" ] && rm "$config_dir/kitty.conf"

    # Link main configuration file
    if [ -f "$repo_dir/kitty.conf" ]; then
        ln -sf "$repo_dir/kitty.conf" "$config_dir/kitty.conf"
        print_success "Kitty configuration linked"
    elif [ -f "$repo_dir/.config/kitty/kitty.conf" ]; then
        ln -sf "$repo_dir/.config/kitty/kitty.conf" "$config_dir/kitty.conf"
        print_success "Kitty configuration linked"
    else
        print_warning "Kitty configuration file not found in repository"
    fi

    # Link any additional config files
    for config_file in "$repo_dir"/*.conf; do
        if [ -f "$config_file" ] && [ "$(basename "$config_file")" != "kitty.conf" ]; then
            [ -L "$config_dir/$(basename "$config_file")" ] && rm "$config_dir/$(basename "$config_file")"
            ln -sf "$config_file" "$config_dir/$(basename "$config_file")"
        fi
    done

    # Link themes if they exist
    if [ -d "$repo_dir/themes" ]; then
        [ -L "$config_dir/themes" ] && rm "$config_dir/themes"
        ln -sf "$repo_dir/themes" "$config_dir/themes"
    fi
}

setup_tmux_dotfiles() {
    local repo_dir="$HOME/Projects/tmux"

    print_status "Setting up Tmux dotfiles..."

    if [ ! -d "$repo_dir" ]; then
        print_status "Cloning Tmux dotfiles repository..."
        git clone https://github.com/y37y/tmux.git "$repo_dir"
    else
        print_status "Updating Tmux dotfiles repository..."
        cd "$repo_dir"
        git pull origin main || git pull origin master
        cd - > /dev/null
    fi

    # Symlink entire directory (not just the file)
    ln -sfn "$repo_dir" "$HOME/.config/tmux"

    # Still need ~/.tmux.conf as tmux's default entrypoint
    [ -L "$HOME/.tmux.conf" ] && rm "$HOME/.tmux.conf"
    ln -sf "$HOME/.config/tmux/tmux.conf" "$HOME/.tmux.conf"
    print_success "Tmux configuration linked"

    # TPM goes inside the repo dir (gitignored via plugins/)
    if [ ! -d "$HOME/.config/tmux/plugins/tpm" ]; then
        print_status "Installing Tmux Plugin Manager..."
        git clone https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm"
        print_success "TPM installed. Run 'prefix + I' in tmux to install plugins"
    else
        print_status "TPM already installed"
    fi
}

setup_yazi_dotfiles() {
    local repo_dir="$HOME/Projects/yazi"
    local config_dir="$HOME/.config/yazi"

    print_status "Setting up Yazi dotfiles..."

    # Clone or update repository
    if [ ! -d "$repo_dir" ]; then
        print_status "Cloning Yazi dotfiles repository..."
        git clone https://github.com/y37y/yazi.git "$repo_dir"
    else
        print_status "Updating Yazi dotfiles repository..."
        cd "$repo_dir"
        git pull origin main || git pull origin master
        cd - > /dev/null
    fi

    # Create config directory
    mkdir -p "$config_dir"

    # Remove existing symlinks
    find "$config_dir" -type l -delete 2>/dev/null || true

    # Link configuration files
    local files_linked=0
    for config_file in "$repo_dir"/*.toml "$repo_dir"/*.lua; do
        if [ -f "$config_file" ]; then
            ln -sf "$config_file" "$config_dir/$(basename "$config_file")"
            files_linked=$((files_linked + 1))
        fi
    done

    # Link any subdirectories (like plugins or themes)
    for subdir in "$repo_dir"/*/; do
        if [ -d "$subdir" ]; then
            ln -sf "$subdir" "$config_dir/$(basename "$subdir")"
            files_linked=$((files_linked + 1))
        fi
    done

    if [ $files_linked -gt 0 ]; then
        print_success "Yazi configuration linked ($files_linked items)"
    else
        print_warning "No Yazi configuration files found in repository"
    fi
}

setup_zsh_dotfiles() {
    local repo_dir="$HOME/Projects/zsh"

    print_status "Setting up Zsh dotfiles..."

    # Install Zsh if not present
    if ! command -v zsh &>/dev/null; then
        print_status "Installing Zsh..."
        sudo apt install -y zsh
    fi

    # Clone or update repository
    if [ ! -d "$repo_dir" ]; then
        print_status "Cloning Zsh dotfiles repository..."
        git clone https://github.com/y37y/zsh.git "$repo_dir"
    else
        print_status "Updating Zsh dotfiles repository..."
        cd "$repo_dir"
        git pull origin main || git pull origin master
        cd - > /dev/null
    fi

    # Remove existing symlinks
    [ -L "$HOME/.zshrc" ] && rm "$HOME/.zshrc"
    [ -L "$HOME/.config/starship.toml" ] && rm "$HOME/.config/starship.toml"

    # Setup configuration
    cd "$repo_dir"
    
    # Run the installer if it exists
    if [ -f "./install.sh" ]; then
        print_status "Running Zsh configuration installer..."
        chmod +x ./install.sh
        ./install.sh
    else
        # Manual setup if install.sh doesn't exist
        print_status "Manually setting up Zsh configuration..."
        ln -sf "$repo_dir/.zshrc" "$HOME/.zshrc"
        
        # Copy starship config if it exists
        if [ -f "$repo_dir/starship.toml" ]; then
            mkdir -p ~/.config
            ln -sf "$repo_dir/starship.toml" "$HOME/.config/starship.toml"
        fi
    fi
    
    cd - > /dev/null
    print_success "Zsh dotfiles setup complete"
}

update_all_dotfiles() {
    print_status "Updating all dotfiles repositories..."
    
    local repos=("wezterm" "kitty" "tmux" "yazi" "zsh")
    
    for repo in "${repos[@]}"; do
        local repo_dir="$HOME/Projects/$repo"
        if [ -d "$repo_dir" ]; then
            print_status "Updating $repo..."
            cd "$repo_dir"
            git pull origin main || git pull origin master
            
            # Update submodules for wezterm
            if [ "$repo" = "wezterm" ]; then
                git submodule update --init --recursive
            fi
            
            cd - > /dev/null
            print_success "$repo updated"
        else
            print_warning "$repo repository not found at $repo_dir"
        fi
    done
    
    print_success "All dotfiles repositories updated"
}

show_dotfiles_status() {
    print_status "Dotfiles installation status:"
    
    # Check repositories
    local repos=("wezterm" "kitty" "tmux" "yazi" "zsh")
    for repo in "${repos[@]}"; do
        if [ -d "$HOME/Projects/$repo" ]; then
            print_success "$repo repository: ✓ Cloned"
        else
            print_error "$repo repository: ✗ Missing"
        fi
    done
    
    echo ""
    print_status "Configuration file status:"
    
    # Check configuration files
    [ -f "$HOME/.zshrc" ] && print_success ".zshrc: ✓ Linked" || print_error ".zshrc: ✗ Missing"
    [ -f "$HOME/.tmux.conf" ] && print_success ".tmux.conf: ✓ Linked" || print_error ".tmux.conf: ✗ Missing"
    [ -f "$HOME/.config/wezterm/wezterm.lua" ] && print_success "wezterm.lua: ✓ Linked" || print_error "wezterm.lua: ✗ Missing"
    [ -f "$HOME/.config/kitty/kitty.conf" ] && print_success "kitty.conf: ✓ Linked" || print_error "kitty.conf: ✗ Missing"
    [ -d "$HOME/.config/yazi" ] && [ "$(ls -A "$HOME/.config/yazi" 2>/dev/null)" ] && print_success "yazi config: ✓ Linked" || print_error "yazi config: ✗ Missing"
}

# Handle command line arguments
case "${1:-}" in
    "update")
        update_all_dotfiles
        ;;
    "status")
        show_dotfiles_status
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [command]"
        echo "Commands:"
        echo "  (none)  - Install all dotfiles"
        echo "  update  - Update all dotfiles repositories"
        echo "  status  - Show installation status"
        echo "  help    - Show this help message"
        ;;
    *)
        install_dotfiles_environment
        ;;
esac

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # If no arguments provided, run the main installation
    if [ $# -eq 0 ]; then
        install_dotfiles_environment
    fi
fi
