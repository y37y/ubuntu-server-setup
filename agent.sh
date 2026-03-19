#!/bin/bash

set -e

# Source common functions
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
source "$SCRIPT_DIR/common.sh"

# Initialize Homebrew if needed
if ! command -v brew &>/dev/null; then
    if [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

# ─── Shared dependencies (browser automation, display, etc.) ───

install_agent_system_deps() {
    print_status "Installing system dependencies for AI agent work..."

    sudo apt update
    sudo apt install -y \
        xvfb x11-utils x11-xserver-utils \
        xdotool wmctrl \
        scrot imagemagick \
        libatk1.0-0 libatk-bridge2.0-0 libcups2 libxcomposite1 \
        libxdamage1 libxrandr2 libgbm1 libpango-1.0-0 \
        libcairo2 libasound2t64 libnspr4 libnss3 libxss1 \
        fonts-liberation xfonts-base \
        jq curl wget unzip git \
        python3-full python3-pip python3-venv pipx

    print_success "System dependencies installed"
}

install_browser_automation_deps() {
    print_status "Installing browser automation dependencies..."

    # Playwright system deps (covers Chromium, Firefox, WebKit)
    if command -v npx &>/dev/null; then
        print_status "Installing Playwright browsers and system deps..."
        npx --yes playwright install --with-deps chromium
    else
        print_warning "npx not found — run node.sh first, then re-run this step"
    fi

    # Chrome for Puppeteer / selenium (should already be installed by install_browsers)
    if ! command -v google-chrome &>/dev/null; then
        print_status "Installing Google Chrome..."
        wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        sudo apt install -y ./google-chrome-stable_current_amd64.deb
        rm -f google-chrome-stable_current_amd64.deb
    fi

    # ChromeDriver (matches installed Chrome version)
    install_chromedriver

    print_success "Browser automation dependencies installed"
}

install_chromedriver() {
    if command -v chromedriver &>/dev/null; then
        print_status "ChromeDriver already installed: $(chromedriver --version)"
        return 0
    fi

    local chrome_version
    chrome_version=$(google-chrome --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+' || true)

    if [ -z "$chrome_version" ]; then
        print_warning "Cannot detect Chrome version, skipping ChromeDriver"
        return 0
    fi

    local major_version
    major_version=$(echo "$chrome_version" | cut -d. -f1)

    print_status "Installing ChromeDriver for Chrome ${chrome_version}..."

    # Chrome for Testing JSON endpoint
    local driver_url
    driver_url=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json" \
        | jq -r --arg v "$chrome_version" \
        '.versions[] | select(.version == $v) | .downloads.chromedriver[]? | select(.platform == "linux64") | .url' \
        | head -1)

    # Fallback: get latest for this major version
    if [ -z "$driver_url" ]; then
        driver_url=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json" \
            | jq -r --arg m "$major_version" \
            '[.versions[] | select(.version | startswith($m + ".")) | select(.downloads.chromedriver != null)] | last | .downloads.chromedriver[] | select(.platform == "linux64") | .url' \
            2>/dev/null || true)
    fi

    if [ -n "$driver_url" ]; then
        local tmpdir
        tmpdir=$(mktemp -d)
        wget -q "$driver_url" -O "$tmpdir/chromedriver.zip"
        unzip -o "$tmpdir/chromedriver.zip" -d "$tmpdir"
        local binary
        binary=$(find "$tmpdir" -name chromedriver -type f | head -1)
        if [ -n "$binary" ]; then
            chmod +x "$binary"
            sudo mv "$binary" /usr/local/bin/chromedriver
            print_success "ChromeDriver installed: $(chromedriver --version)"
        fi
        rm -rf "$tmpdir"
    else
        print_warning "Could not find matching ChromeDriver — install manually if needed"
    fi
}

# ─── Claude Code ───

install_claude_code() {
    print_status "Installing Claude Code..."

    if command -v claude &>/dev/null; then
        print_status "Claude Code already installed: $(claude --version 2>/dev/null || echo 'installed')"
        return 0
    fi

    # Install via npm (official method)
    if command -v npm &>/dev/null; then
        npm install -g @anthropic-ai/claude-code
        print_success "Claude Code installed via npm"
    else
        print_warning "npm not found — install Node.js first (node.sh), then re-run"
        return 1
    fi
}

# ─── Claude Desktop (unofficial Linux build) ───

install_claude_desktop_linux() {
    print_status "Installing Claude Desktop (unofficial Linux build)..."

    if command -v claude-desktop &>/dev/null || dpkg -l claude-desktop &>/dev/null 2>&1; then
        print_status "Claude Desktop already installed"
        return 0
    fi

    # Add the unofficial apt repository
    print_status "Adding claude-desktop-debian apt repository..."
    curl -fsSL https://aaddrick.github.io/claude-desktop-debian/KEY.gpg \
        | sudo gpg --yes --dearmor -o /usr/share/keyrings/claude-desktop.gpg

    echo "deb [signed-by=/usr/share/keyrings/claude-desktop.gpg arch=amd64,arm64] https://aaddrick.github.io/claude-desktop-debian stable main" \
        | sudo tee /etc/apt/sources.list.d/claude-desktop.list

    sudo apt update
    if sudo apt install -y claude-desktop; then
        print_success "Claude Desktop installed (unofficial Linux build)"
        print_warning "This is a community repackage — not officially supported by Anthropic"
    else
        print_warning "Claude Desktop installation failed — you can try manually later"
        print_status "See: https://github.com/aaddrick/claude-desktop-debian"
    fi
}

# ─── OpenCode ───

install_opencode() {
    print_status "Installing OpenCode..."

    if command -v opencode &>/dev/null; then
        print_status "OpenCode already installed"
        return 0
    fi

    # Try brew first, then npm
    if command -v brew &>/dev/null; then
        brew install anomalyco/tap/opencode && print_success "OpenCode installed via brew" && return 0
    fi

    if command -v npm &>/dev/null; then
        npm install -g opencode-ai@latest && print_success "OpenCode installed via npm" && return 0
    fi

    # Fallback: install script
    curl -fsSL https://raw.githubusercontent.com/opencode-ai/opencode/refs/heads/main/install | bash
    print_success "OpenCode installed via install script"
}

# ─── Qwen Code ───

install_qwen_code() {
    print_status "Installing Qwen Code..."

    if command -v qwen &>/dev/null; then
        print_status "Qwen Code already installed"
        return 0
    fi

    if command -v npm &>/dev/null; then
        npm install -g @qwen-code/qwen-code@latest
        print_success "Qwen Code installed via npm"
    elif command -v brew &>/dev/null; then
        brew install qwen-code
        print_success "Qwen Code installed via brew"
    else
        # Fallback install script
        bash -c "$(curl -fsSL https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen.sh)"
        print_success "Qwen Code installed via install script"
    fi
}

# ─── OpenClaw ───

install_openclaw() {
    print_status "Installing OpenClaw..."

    if command -v openclaw &>/dev/null; then
        print_status "OpenClaw already installed"
        return 0
    fi

    if command -v node &>/dev/null; then
        curl -fsSL https://openclaw.ai/install.sh | bash
        print_success "OpenClaw installed"
        print_status "Run 'openclaw onboard --install-daemon' to configure"
    else
        print_warning "Node.js required — install via node.sh first"
        return 1
    fi
}

# ─── Eigent ───

install_eigent() {
    print_status "Installing Eigent..."

    local eigent_dir="$HOME/Projects/eigent"

    if [ -d "$eigent_dir" ]; then
        print_status "Eigent directory already exists, updating..."
        cd "$eigent_dir"
        git pull origin main || git pull origin master
        npm install
        cd - >/dev/null
        return 0
    fi

    # Requires Docker
    if ! command -v docker &>/dev/null; then
        print_warning "Docker is required for Eigent — run docker.sh first"
        return 1
    fi

    mkdir -p "$HOME/Projects"
    git clone https://github.com/eigent-ai/eigent.git "$eigent_dir"
    cd "$eigent_dir"
    npm install
    cd - >/dev/null

    print_success "Eigent cloned and dependencies installed"
    print_status "See https://github.com/eigent-ai/eigent for setup instructions"
}

# ─── Python agent tools (common libs used by many frameworks) ───

install_python_agent_libs() {
    print_status "Installing Python agent libraries..."

    local venv_dir="$HOME/.agent-venv"

    if [ ! -d "$venv_dir" ]; then
        python3 -m venv "$venv_dir"
    fi

    source "$venv_dir/bin/activate"
    pip install --upgrade pip
    pip install \
        selenium \
        playwright \
        anthropic \
        openai \
        litellm \
        httpx \
        Pillow \
        beautifulsoup4 \
        lxml
    deactivate

    print_success "Python agent libraries installed in $venv_dir"
    print_status "Activate with: source $venv_dir/bin/activate"
}

# ─── Menu ───

show_menu() {
    if command -v whiptail >/dev/null 2>&1; then
        local choices
        choices=$(whiptail --title "AI Agent Setup" \
            --checklist "Select agent tools to install:" \
            24 78 14 \
            "0" "Install All Agent Tools" ON \
            "1" "System deps (xvfb, display, libs)" OFF \
            "2" "Browser automation (Playwright, ChromeDriver)" OFF \
            "3" "Claude Code" OFF \
            "4" "Claude Desktop (unofficial Linux build)" OFF \
            "5" "OpenCode" OFF \
            "6" "Qwen Code" OFF \
            "7" "OpenClaw" OFF \
            "8" "Eigent" OFF \
            "9" "Python agent libraries (venv)" OFF \
            3>&1 1>&2 2>&3)

        [ $? -ne 0 ] && { print_error "Setup cancelled."; exit 1; }

        if [[ $choices == *'"0"'* ]]; then
            install_all
        else
            [[ $choices == *'"1"'* ]] && install_agent_system_deps
            [[ $choices == *'"2"'* ]] && install_browser_automation_deps
            [[ $choices == *'"3"'* ]] && install_claude_code
            [[ $choices == *'"4"'* ]] && install_claude_desktop_linux
            [[ $choices == *'"5"'* ]] && install_opencode
            [[ $choices == *'"6"'* ]] && install_qwen_code
            [[ $choices == *'"7"'* ]] && install_openclaw
            [[ $choices == *'"8"'* ]] && install_eigent
            [[ $choices == *'"9"'* ]] && install_python_agent_libs
        fi
    else
        install_all
    fi
}

install_all() {
    install_agent_system_deps
    install_browser_automation_deps
    install_claude_code
    install_claude_desktop_linux
    install_opencode
    install_qwen_code
    install_openclaw
    install_eigent
    install_python_agent_libs

    print_success "All agent tools installed!"
    verify_agent_setup
}

verify_agent_setup() {
    print_status "Verifying agent tool installation..."

    local tools=(
        "claude:Claude Code"
        "opencode:OpenCode"
        "qwen:Qwen Code"
        "openclaw:OpenClaw"
        "google-chrome:Google Chrome"
        "chromedriver:ChromeDriver"
        "xvfb-run:Xvfb"
    )

    for entry in "${tools[@]}"; do
        local cmd="${entry%%:*}"
        local name="${entry##*:}"
        if command -v "$cmd" &>/dev/null; then
            print_success "$name installed"
        else
            print_warning "$name not found"
        fi
    done

    # Check Eigent directory
    if [ -d "$HOME/Projects/eigent" ]; then
        print_success "Eigent cloned"
    else
        print_warning "Eigent not found"
    fi

    # Check Python venv
    if [ -d "$HOME/.agent-venv" ]; then
        print_success "Python agent venv exists"
    else
        print_warning "Python agent venv not found"
    fi
}

# ─── CLI entry ───

case "${1:-}" in
    "all")
        install_all
        ;;
    "deps")
        install_agent_system_deps
        install_browser_automation_deps
        ;;
    "claude-code")
        install_claude_code
        ;;
    "claude-desktop")
        install_claude_desktop_linux
        ;;
    "opencode")
        install_opencode
        ;;
    "qwen")
        install_qwen_code
        ;;
    "openclaw")
        install_openclaw
        ;;
    "eigent")
        install_eigent
        ;;
    "python")
        install_python_agent_libs
        ;;
    "verify")
        verify_agent_setup
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [command]"
        echo "Commands:"
        echo "  all            - Install all agent tools"
        echo "  deps           - System + browser automation deps only"
        echo "  claude-code    - Claude Code (CLI)"
        echo "  claude-desktop - Claude Desktop (unofficial Linux)"
        echo "  opencode       - OpenCode"
        echo "  qwen           - Qwen Code"
        echo "  openclaw       - OpenClaw"
        echo "  eigent         - Eigent"
        echo "  python         - Python agent libraries (venv)"
        echo "  verify         - Check installed tools"
        echo "  help           - Show this help message"
        echo ""
        echo "If no command is provided, interactive menu will be shown."
        ;;
    *)
        show_menu
        ;;
esac
