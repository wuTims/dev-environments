#!/bin/bash
set -e

# ============================================
# Dev Environments Bootstrap Script
# Run this on any new machine to set up everything
# ============================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# ============================================
# Detect OS
# ============================================
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if grep -q Microsoft /proc/version 2>/dev/null; then
            OS="wsl"
        else
            OS="linux"
        fi
    else
        log_error "Unsupported OS: $OSTYPE"
        exit 1
    fi
    log_info "Detected OS: $OS"
}

# ============================================
# Install Docker
# ============================================
install_docker() {
    log_step "Checking Docker..."
    
    if command -v docker &> /dev/null; then
        log_info "Docker already installed: $(docker --version)"
        return
    fi

    log_info "Installing Docker..."
    
    case $OS in
        macos)
            if command -v brew &> /dev/null; then
                brew install --cask docker
                log_warn "Please open Docker Desktop to complete setup"
            else
                log_error "Please install Homebrew first: https://brew.sh"
                exit 1
            fi
            ;;
        wsl|linux)
            # Install Docker using official script
            curl -fsSL https://get.docker.com | sh
            sudo usermod -aG docker $USER
            log_warn "You may need to log out and back in for docker group to take effect"
            ;;
    esac
    
    log_info "Docker installed successfully"
}

# ============================================
# Install VS Code or compatible editor
# ============================================
install_editor() {
    log_step "Checking for VS Code-compatible editors..."
    
    # Check for various editors
    local editors=("code" "cursor" "windsurf" "codium" "code-insiders")
    local found_editor=""
    
    for editor in "${editors[@]}"; do
        if command -v "$editor" &> /dev/null; then
            found_editor="$editor"
            log_info "Found editor: $editor ($($editor --version 2>/dev/null | head -1))"
            break
        fi
    done
    
    if [ -n "$found_editor" ]; then
        log_info "Using existing editor: $found_editor"
        echo "$found_editor" > "$HOME/.config/dev-environments/editor"
        return 0
    fi

    log_info "No VS Code-compatible editor found."
    echo ""
    echo "Which editor would you like to install?"
    echo "  1) VS Code (Microsoft)"
    echo "  2) Cursor (AI-native fork)"
    echo "  3) VSCodium (FOSS build)"
    echo "  4) Skip - I'll install one manually"
    echo ""
    read -p "Choice [1-4]: " editor_choice
    
    case $editor_choice in
        1)
            install_vscode
            echo "code" > "$HOME/.config/dev-environments/editor"
            ;;
        2)
            install_cursor
            echo "cursor" > "$HOME/.config/dev-environments/editor"
            ;;
        3)
            install_vscodium
            echo "codium" > "$HOME/.config/dev-environments/editor"
            ;;
        *)
            log_warn "Skipping editor installation"
            log_info "Install VS Code, Cursor, or similar and re-run bootstrap"
            ;;
    esac
}

install_vscode() {
    log_info "Installing VS Code..."
    
    case $OS in
        macos)
            brew install --cask visual-studio-code
            ;;
        wsl)
            log_info "For WSL, install VS Code on Windows and use Remote - WSL extension"
            log_info "Download from: https://code.visualstudio.com/"
            ;;
        linux)
            if command -v apt &> /dev/null; then
                wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
                sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
                sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
                rm -f packages.microsoft.gpg
                sudo apt update
                sudo apt install -y code
            fi
            ;;
    esac
}

install_cursor() {
    log_info "Installing Cursor..."
    
    case $OS in
        macos)
            brew install --cask cursor
            ;;
        wsl|linux)
            log_info "Download Cursor from: https://cursor.sh/"
            log_info "Or use: curl -fsSL https://cursor.sh/install.sh | sh"
            curl -fsSL https://cursor.sh/install.sh | sh || true
            ;;
    esac
}

install_vscodium() {
    log_info "Installing VSCodium..."
    
    case $OS in
        macos)
            brew install --cask vscodium
            ;;
        linux)
            if command -v apt &> /dev/null; then
                wget -qO - https://gitlab.com/paunin-alexey/vscodium-deb-rpm-repo/-/raw/master/pub.gpg | gpg --dearmor | sudo dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg
                echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' | sudo tee /etc/apt/sources.list.d/vscodium.list
                sudo apt update
                sudo apt install -y codium
            fi
            ;;
    esac
}

# ============================================
# Install VS Code Extensions (on host)
# ============================================
install_editor_extensions() {
    log_step "Installing editor extensions on host..."
    
    # Detect which editor CLI is available
    local editor_cli=""
    for cli in "code" "cursor" "windsurf" "codium" "code-insiders"; do
        if command -v "$cli" &> /dev/null; then
            editor_cli="$cli"
            break
        fi
    done
    
    if [ -z "$editor_cli" ]; then
        log_warn "No editor CLI found, skipping host extensions"
        return
    fi
    
    log_info "Using $editor_cli to install extensions..."

    # Core extensions needed on HOST for container workflows
    local host_extensions=(
        "ms-vscode-remote.remote-containers"
        "ms-vscode-remote.remote-ssh"
        "ms-azuretools.vscode-docker"
    )

    for ext in "${host_extensions[@]}"; do
        log_info "Installing $ext..."
        "$editor_cli" --install-extension "$ext" --force 2>/dev/null || true
    done
    
    log_info "Host extensions installed"
}

# ============================================
# Configure Git
# ============================================
configure_git() {
    log_step "Configuring Git..."
    
    if ! command -v git &> /dev/null; then
        case $OS in
            macos)
                xcode-select --install 2>/dev/null || true
                ;;
            wsl|linux)
                sudo apt update && sudo apt install -y git
                ;;
        esac
    fi

    # Check if git is configured
    if [ -z "$(git config --global user.name)" ]; then
        read -p "Enter your Git name: " git_name
        git config --global user.name "$git_name"
    fi
    
    if [ -z "$(git config --global user.email)" ]; then
        read -p "Enter your Git email: " git_email
        git config --global user.email "$git_email"
    fi

    # Common git settings
    git config --global init.defaultBranch main
    git config --global pull.rebase true
    git config --global core.autocrlf input
    
    log_info "Git configured"
}

# ============================================
# Setup GitHub Container Registry Auth
# ============================================
setup_ghcr() {
    log_step "Setting up GitHub Container Registry authentication..."
    
    if docker login ghcr.io -u _ -p _ 2>&1 | grep -q "Login Succeeded"; then
        log_info "Already authenticated with ghcr.io"
        return
    fi

    log_info "To pull images from ghcr.io, you need a GitHub Personal Access Token"
    log_info "Create one at: https://github.com/settings/tokens"
    log_info "Required scopes: read:packages"
    echo ""
    read -p "Enter your GitHub username: " gh_user
    read -s -p "Enter your GitHub PAT: " gh_token
    echo ""
    
    echo "$gh_token" | docker login ghcr.io -u "$gh_user" --password-stdin
    
    log_info "GitHub Container Registry configured"
}

# ============================================
# Pull Dev Images
# ============================================
pull_images() {
    log_step "Pulling dev images (this may take a while)..."
    
    # Replace with your actual namespace
    NAMESPACE="YOUR_USERNAME"
    
    images=(
        "ghcr.io/$NAMESPACE/base:latest"
        "ghcr.io/$NAMESPACE/python-dev:latest"
        "ghcr.io/$NAMESPACE/node-dev:latest"
    )

    for img in "${images[@]}"; do
        log_info "Pulling $img..."
        docker pull "$img" || log_warn "Failed to pull $img - you may need to build it first"
    done
    
    log_info "Images pulled"
}

# ============================================
# Create convenience scripts
# ============================================
create_scripts() {
    log_step "Creating convenience scripts..."
    
    SCRIPT_DIR="$HOME/.local/bin"
    mkdir -p "$SCRIPT_DIR"

    # dev-python: Quick start Python project with devcontainer
    cat > "$SCRIPT_DIR/dev-python" << 'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: dev-python <project-dir>"
    exit 1
fi
mkdir -p "$1/.devcontainer"
cp -r ~/dev-environments/devcontainers/python-dev/.devcontainer/* "$1/.devcontainer/"
cd "$1"
code .
EOF
    chmod +x "$SCRIPT_DIR/dev-python"

    # dev-node: Quick start Node project with devcontainer
    cat > "$SCRIPT_DIR/dev-node" << 'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: dev-node <project-dir>"
    exit 1
fi
mkdir -p "$1/.devcontainer"
cp -r ~/dev-environments/devcontainers/node-dev/.devcontainer/* "$1/.devcontainer/"
cd "$1"
code .
EOF
    chmod +x "$SCRIPT_DIR/dev-node"

    # Add to PATH if not already
    if ! grep -q 'HOME/.local/bin' ~/.bashrc 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
    if ! grep -q 'HOME/.local/bin' ~/.zshrc 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
    fi
    
    log_info "Convenience scripts created: dev-python, dev-node"
}

# ============================================
# Main
# ============================================
main() {
    echo ""
    echo "============================================"
    echo "  Dev Environments Bootstrap"
    echo "============================================"
    echo ""

    # Create config directory
    mkdir -p "$HOME/.config/dev-environments"

    detect_os
    install_docker
    install_editor
    install_editor_extensions
    configure_git
    
    # Only setup ghcr if images are public or user wants to auth
    read -p "Set up GitHub Container Registry authentication? [y/N] " setup_auth
    if [[ "$setup_auth" =~ ^[Yy]$ ]]; then
        setup_ghcr
    fi
    
    read -p "Pull dev images now? [y/N] " pull_now
    if [[ "$pull_now" =~ ^[Yy]$ ]]; then
        pull_images
    fi
    
    create_scripts

    echo ""
    echo "============================================"
    echo "  ✅ Bootstrap Complete!"
    echo "============================================"
    echo ""
    echo "Quick start commands:"
    echo "  dev-python <dir>  - Create Python project with devcontainer"
    echo "  dev-node <dir>    - Create Node project with devcontainer"
    echo ""
    echo "Or manually:"
    echo "  1. cd your-project"
    echo "  2. cp -r ~/dev-environments/devcontainers/python-dev/.devcontainer ."
    echo "  3. Open in your editor"
    echo "  4. Use 'Reopen in Container' OR 'Attach to Running Container'"
    echo ""
    echo "For 'Attach to Running Container' workflow:"
    echo "  1. docker compose up -d  (or docker run your image)"
    echo "  2. In editor: Attach to Running Container"
    echo "  3. Extensions are pre-installed inside container"
    echo ""
    
    if [[ "$OS" == "wsl" ]]; then
        log_warn "WSL users: Make sure Docker Desktop is running on Windows"
        log_warn "Enable 'Use the WSL 2 based engine' in Docker Desktop settings"
    fi
}

main "$@"
