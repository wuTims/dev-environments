#!/bin/bash
set -e

# ============================================
# Dev Environment Entrypoint
# Handles first-run setup and MCP configuration
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================
# Fix permissions for mounted volumes
# ============================================
fix_permissions() {
    # Docker socket permissions
    if [ -S /var/run/docker.sock ]; then
        log_info "Docker socket found, configuring permissions..."

        # Get the GID of the docker socket
        DOCKER_GID=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock 2>/dev/null)

        if [ -n "$DOCKER_GID" ]; then
            # Check if user is already in a group that owns the socket
            if id -G | grep -qw "$DOCKER_GID"; then
                log_info "User already has Docker socket access"
            else
                # Try to create/use docker-host group with the socket's GID
                if ! getent group docker-host > /dev/null 2>&1; then
                    sudo groupadd -g "$DOCKER_GID" docker-host 2>/dev/null || true
                fi
                sudo usermod -aG docker-host "$(whoami)" 2>/dev/null || true
            fi
        fi

        # For macOS Docker Desktop: socket may have root:root ownership with 0660 permissions
        # Try to make it accessible if docker commands fail
        if ! docker info > /dev/null 2>&1; then
            log_warn "Docker socket not accessible, attempting chmod fix..."
            sudo chmod 666 /var/run/docker.sock 2>/dev/null || true
        fi

        # Verify docker is working
        if docker info > /dev/null 2>&1; then
            log_info "Docker socket permissions configured successfully"
        else
            log_warn "Docker socket may require reconnection - try restarting the container"
        fi
    else
        log_warn "Docker socket not found at /var/run/docker.sock"
    fi
}

# ============================================
# Configure MCP servers if not already done
# ============================================
configure_mcp() {
    local CLAUDE_BIN="$HOME/.claude/bin/claude"
    
    if [ ! -x "$CLAUDE_BIN" ]; then
        log_warn "Claude Code not found, skipping MCP configuration"
        return
    fi

    # Check if MCPs are already configured
    if [ -f "$HOME/.claude/settings.json" ]; then
        log_info "Claude Code already configured"
        return
    fi

    log_info "Configuring MCP servers..."
    
    # Add DeepWiki MCP (HTTP transport - works everywhere)
    $CLAUDE_BIN mcp add -s user -t http deepwiki https://mcp.deepwiki.com/mcp 2>/dev/null || true
    
    # If this is node-dev image, add Playwright MCP
    if command -v playwright &> /dev/null || [ -f "$HOME/.config/claude/.mcp.json" ] && grep -q "playwright" "$HOME/.config/claude/.mcp.json" 2>/dev/null; then
        log_info "Adding Playwright MCP..."
        $CLAUDE_BIN mcp add playwright -- npx @playwright/mcp@latest 2>/dev/null || true
    fi

    log_info "MCP servers configured"
}

# ============================================
# Configure claude-mem plugin
# ============================================
configure_claude_mem() {
    local CLAUDE_BIN="$HOME/.claude/bin/claude"
    
    if [ ! -x "$CLAUDE_BIN" ]; then
        log_warn "Claude Code not found, skipping claude-mem setup"
        return
    fi
    
    # Check if claude-mem is already installed
    if [ -d "$HOME/.claude/plugins/claude-mem" ]; then
        log_info "claude-mem already installed"
        return
    fi
    
    # Check if npm global claude-mem is available
    if command -v claude-mem &> /dev/null; then
        log_info "Setting up claude-mem..."
        claude-mem install 2>/dev/null || true
        log_info "claude-mem configured"
    else
        log_warn "claude-mem not found, skipping"
    fi
}

# ============================================
# Setup git configuration if not present
# ============================================
setup_git() {
    if [ ! -f "$HOME/.gitconfig" ]; then
        # Check for VS Code environment variables
        if [ -n "$GIT_AUTHOR_NAME" ]; then
            git config --global user.name "$GIT_AUTHOR_NAME"
        fi
        if [ -n "$GIT_AUTHOR_EMAIL" ]; then
            git config --global user.email "$GIT_AUTHOR_EMAIL"
        fi
        
        # Common git settings
        git config --global init.defaultBranch main
        git config --global pull.rebase true
        git config --global core.autocrlf input
        git config --global core.editor "code --wait"
        
        log_info "Git configured"
    fi
}

# ============================================
# Install VS Code extensions for Attach workflow
# ============================================
install_extensions() {
    local INSTALL_SCRIPT="$HOME/.local/bin/install-extensions.sh"
    
    if [ ! -x "$INSTALL_SCRIPT" ]; then
        log_warn "Extension installer not found"
        return
    fi
    
    # Only run on first container start (check marker file)
    local MARKER_FILE="$HOME/.config/extensions/.installed"
    if [ -f "$MARKER_FILE" ]; then
        log_info "Extensions already installed"
        return
    fi
    
    log_info "Installing VS Code extensions..."
    
    # Install base extensions
    "$INSTALL_SCRIPT" openvsx "$HOME/.config/extensions/base-extensions.txt" 2>/dev/null || true
    
    # Install environment-specific extensions if present
    for ext_file in "$HOME/.config/extensions/"*-extensions.txt; do
        if [ -f "$ext_file" ] && [ "$ext_file" != "$HOME/.config/extensions/base-extensions.txt" ]; then
            "$INSTALL_SCRIPT" openvsx "$ext_file" 2>/dev/null || true
        fi
    done
    
    # Create marker file
    mkdir -p "$(dirname "$MARKER_FILE")"
    touch "$MARKER_FILE"
    
    log_info "Extensions installed"
}

# ============================================
# Start Xvfb for headless browser testing
# ============================================
start_xvfb() {
    if command -v Xvfb &> /dev/null; then
        if ! pgrep -x "Xvfb" > /dev/null; then
            Xvfb :99 -screen 0 1920x1080x24 &
            export DISPLAY=:99
            log_info "Xvfb started on display :99"
        fi
    fi
}

# ============================================
# Main
# ============================================
main() {
    log_info "Initializing development environment..."
    
    fix_permissions
    setup_git
    configure_mcp
    configure_claude_mem
    install_extensions
    
    # Start Xvfb if available (for Playwright)
    start_xvfb
    
    log_info "Environment ready!"
    
    # Execute the command passed to the container
    exec "$@"
}

main "$@"