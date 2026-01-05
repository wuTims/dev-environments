#!/bin/bash
set -e

# ============================================
# Dev Environments Bootstrap Script
# Pulls images and creates convenience scripts
#
# Prerequisites (install before running):
#   - Docker or Docker Desktop
#   - VS Code, Cursor, or compatible editor
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

# Configuration
REGISTRY="${REGISTRY:-ghcr.io}"
NAMESPACE="${NAMESPACE:-wutims}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================
# Check Prerequisites
# ============================================
check_prerequisites() {
    log_step "Checking prerequisites..."

    local missing=()

    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    elif ! docker info &> /dev/null 2>&1; then
        log_warn "Docker is installed but not running. Please start Docker Desktop."
        missing+=("docker (not running)")
    else
        log_info "Docker: $(docker --version)"
    fi

    # Check for VS Code-compatible editor
    local editor_found=""
    for editor in code cursor windsurf codium code-insiders; do
        if command -v "$editor" &> /dev/null; then
            editor_found="$editor"
            log_info "Editor: $editor"
            break
        fi
    done

    if [ -z "$editor_found" ]; then
        log_warn "No VS Code-compatible editor found in PATH"
        log_warn "Install VS Code, Cursor, or similar before using devcontainers"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing prerequisites: ${missing[*]}"
        echo ""
        echo "Please install the following before running bootstrap:"
        echo "  - Docker: https://docs.docker.com/get-docker/"
        echo "  - Editor: VS Code (https://code.visualstudio.com/) or Cursor (https://cursor.sh/)"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

# ============================================
# Configure Git (if needed)
# ============================================
configure_git() {
    log_step "Checking Git configuration..."

    if ! command -v git &> /dev/null; then
        log_warn "Git not found, skipping configuration"
        return
    fi

    if [ -z "$(git config --global user.name 2>/dev/null)" ]; then
        read -p "Enter your Git name: " git_name
        git config --global user.name "$git_name"
    fi

    if [ -z "$(git config --global user.email 2>/dev/null)" ]; then
        read -p "Enter your Git email: " git_email
        git config --global user.email "$git_email"
    fi

    # Set sensible defaults
    git config --global init.defaultBranch main 2>/dev/null || true
    git config --global pull.rebase true 2>/dev/null || true

    log_info "Git configured: $(git config --global user.name) <$(git config --global user.email)>"
}

# ============================================
# Pull Dev Images
# ============================================
pull_images() {
    log_step "Pulling dev images..."

    local images=(
        "$REGISTRY/$NAMESPACE/base:latest"
        "$REGISTRY/$NAMESPACE/python-dev:latest"
        "$REGISTRY/$NAMESPACE/node-dev:latest"
    )

    local failed=()

    for img in "${images[@]}"; do
        log_info "Pulling $img..."
        if docker pull "$img" 2>/dev/null; then
            log_info "Pulled $img"
        else
            log_warn "Failed to pull $img"
            failed+=("$img")
        fi
    done

    if [ ${#failed[@]} -gt 0 ]; then
        log_warn "Some images failed to pull. They may need to be built first."
        log_warn "See: ./container.sh pull"
    fi
}

# ============================================
# Install container.sh to PATH
# ============================================
install_scripts() {
    log_step "Installing convenience scripts..."

    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"

    # Create symlink to container.sh
    if [ -f "$SCRIPT_DIR/container.sh" ]; then
        ln -sf "$SCRIPT_DIR/container.sh" "$bin_dir/devctl"
        chmod +x "$SCRIPT_DIR/container.sh"
        log_info "Installed 'devctl' -> $SCRIPT_DIR/container.sh"
    fi

    # Ensure ~/.local/bin is in PATH
    local shell_rc=""
    if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        shell_rc="$HOME/.bashrc"
    fi

    if [ -n "$shell_rc" ]; then
        if ! grep -q 'HOME/.local/bin' "$shell_rc" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_rc"
            log_info "Added ~/.local/bin to PATH in $shell_rc"
        fi
    fi

    log_info "Scripts installed"
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

    check_prerequisites
    configure_git

    # Ask about pulling images
    read -p "Pull dev images now? [Y/n] " pull_now
    if [[ ! "$pull_now" =~ ^[Nn]$ ]]; then
        pull_images
    fi

    install_scripts

    echo ""
    echo "============================================"
    echo "  Bootstrap Complete!"
    echo "============================================"
    echo ""
    echo "Quick Start:"
    echo ""
    echo "  # Run a dev container"
    echo "  ./container.sh run python-dev my-project"
    echo ""
    echo "  # Or use the 'devctl' alias (after reloading shell)"
    echo "  devctl run node-dev frontend"
    echo ""
    echo "  # Attach your editor"
    echo "  devctl shell my-project"
    echo "  # Then in editor: 'Attach to Running Container'"
    echo ""
    echo "  # Stop when done"
    echo "  devctl stop my-project"
    echo ""
    echo "Container data persists at: ~/devcontainers/<name>/"
    echo ""
}

main "$@"
