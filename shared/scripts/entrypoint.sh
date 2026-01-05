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
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_retry() { echo -e "${CYAN}[RETRY]${NC} $1"; }

# ============================================
# Ensure PATH includes all tool locations
# ============================================
setup_path() {
    export PATH="$HOME/.claude/bin:$HOME/.local/bin:$HOME/.bun/bin:$PATH"
}

# ============================================
# Update dotfiles from git repo
# ============================================
update_dotfiles() {
    local DOTFILES_DIR="$HOME/dotfiles"

    if [ ! -d "$DOTFILES_DIR" ]; then
        log_warn "Dotfiles directory not found at $DOTFILES_DIR"
        return
    fi

    log_info "Updating dotfiles..."

    # Pull latest changes (fail gracefully)
    if cd "$DOTFILES_DIR" && git pull --ff-only 2>/dev/null; then
        log_info "Dotfiles updated successfully"
    else
        log_warn "Dotfiles update failed (using existing version)"
    fi

    # Run install script to ensure symlinks are current
    if [ -x "$DOTFILES_DIR/install.sh" ]; then
        "$DOTFILES_DIR/install.sh" 2>/dev/null || log_warn "Dotfiles install.sh failed"
    fi
}

# ============================================
# Fix permissions for mounted volumes
# ============================================
fix_permissions() {
    local max_retries=3
    local retry_delay=2

    # Docker socket locations to check (macOS Docker Desktop uses different paths)
    local socket_paths=(
        "/var/run/docker.sock"
        "/var/run/docker-host.sock"
        "$HOME/.docker/run/docker.sock"
    )

    local socket_found=""
    for sock in "${socket_paths[@]}"; do
        if [ -S "$sock" ]; then
            socket_found="$sock"
            break
        fi
    done

    if [ -z "$socket_found" ]; then
        # Retry logic for macOS Docker Desktop - socket may not be immediately available
        for ((i=1; i<=max_retries; i++)); do
            log_retry "Docker socket not found, attempt $i/$max_retries (waiting ${retry_delay}s)..."
            sleep "$retry_delay"
            for sock in "${socket_paths[@]}"; do
                if [ -S "$sock" ]; then
                    socket_found="$sock"
                    log_info "Docker socket found at $sock after retry"
                    break 2
                fi
            done
        done
    fi

    if [ -z "$socket_found" ]; then
        log_warn "Docker socket not found after $max_retries attempts"
        log_warn "Docker-in-Docker features will be unavailable"
        log_warn "If using Docker Desktop, ensure the socket is mounted: -v /var/run/docker.sock:/var/run/docker.sock"
        return 0
    fi

    log_info "Docker socket found at $socket_found"

    # Get the GID of the docker socket
    DOCKER_GID=$(stat -c '%g' "$socket_found" 2>/dev/null || stat -f '%g' "$socket_found" 2>/dev/null)

    if [ -n "$DOCKER_GID" ]; then
        # Check if user is already in a group that owns the socket
        if id -G | grep -qw "$DOCKER_GID"; then
            log_info "User already has Docker socket access (GID: $DOCKER_GID)"
        else
            log_info "Configuring Docker socket access (GID: $DOCKER_GID)..."
            # Try to create/use docker-host group with the socket's GID
            if ! getent group docker-host > /dev/null 2>&1; then
                sudo groupadd -g "$DOCKER_GID" docker-host 2>/dev/null || true
            fi
            sudo usermod -aG docker-host "$(whoami)" 2>/dev/null || true
        fi
    fi

    # Test docker access with retries
    for ((i=1; i<=max_retries; i++)); do
        if docker info > /dev/null 2>&1; then
            log_info "Docker socket access verified"
            return 0
        fi

        if [ $i -lt $max_retries ]; then
            log_retry "Docker access failed, attempt $i/$max_retries - trying chmod fix..."
            sudo chmod 666 "$socket_found" 2>/dev/null || true
            sleep 1
        fi
    done

    log_warn "Docker socket exists but access verification failed"
    log_warn "You may need to restart the container or check Docker Desktop settings"
}

# ============================================
# Find Claude Code binary
# ============================================
find_claude() {
    # Check multiple possible locations
    local claude_paths=(
        "$HOME/.claude/bin/claude"
        "$HOME/.local/bin/claude"
        "/usr/local/bin/claude"
    )

    for path in "${claude_paths[@]}"; do
        if [ -x "$path" ]; then
            echo "$path"
            return 0
        fi
    done

    # Try command lookup as fallback
    if command -v claude &> /dev/null; then
        command -v claude
        return 0
    fi

    return 1
}

# ============================================
# Configure MCP servers if not already done
# ============================================
configure_mcp() {
    local CLAUDE_BIN
    CLAUDE_BIN=$(find_claude) || true

    if [ -z "$CLAUDE_BIN" ]; then
        log_warn "Claude Code not found in PATH or standard locations"
        log_warn "Searched: ~/.claude/bin, ~/.local/bin, /usr/local/bin"
        log_warn "Skipping MCP configuration"
        return
    fi

    log_info "Found Claude Code at: $CLAUDE_BIN"

    # MCP servers are stored in ~/.claude.json (NOT ~/.claude/settings.json)
    local MCP_CONFIG="$HOME/.claude.json"

    # Show current MCP config if exists
    if [ -f "$MCP_CONFIG" ] && grep -q "mcpServers" "$MCP_CONFIG" 2>/dev/null; then
        if command -v jq &> /dev/null; then
            log_info "Base MCPs from dotfiles: $(jq -r '.mcpServers | keys | join(", ")' "$MCP_CONFIG" 2>/dev/null || echo 'parse error')"
        fi
    fi

    # Add image-specific MCPs (these will be added to existing config)

    # Node-dev: Add Playwright MCP
    if command -v playwright &> /dev/null || [ -f "$HOME/.config/extensions/node-extensions.txt" ]; then
        # Check if Playwright MCP already exists
        if [ -f "$MCP_CONFIG" ] && grep -q '"playwright"' "$MCP_CONFIG" 2>/dev/null; then
            log_info "Playwright MCP already configured"
        else
            log_info "Node environment detected, adding Playwright MCP..."
            if "$CLAUDE_BIN" mcp add --scope user playwright -- npx @playwright/mcp@latest 2>/dev/null; then
                log_info "Added Playwright MCP"
            else
                log_warn "Failed to add Playwright MCP"
            fi
        fi
    fi

    log_info "MCP configuration complete"
}

# ============================================
# Configure claude-mem plugin
# ============================================
configure_claude_mem() {
    local CLAUDE_BIN
    CLAUDE_BIN=$(find_claude) || true

    if [ -z "$CLAUDE_BIN" ]; then
        # Already warned in configure_mcp, just skip silently
        return
    fi

    # Check if claude-mem is already installed
    if [ -d "$HOME/.claude/plugins/claude-mem" ]; then
        log_info "claude-mem already installed"
        return
    fi

    # Check if npm global claude-mem is available
    if command -v claude-mem &> /dev/null; then
        log_info "Setting up claude-mem persistent memory..."
        if claude-mem install 2>/dev/null; then
            log_info "claude-mem configured successfully"
        else
            log_warn "claude-mem install failed (non-critical)"
        fi
    else
        log_info "claude-mem not installed globally, skipping"
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
# Print startup summary
# ============================================
print_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Development Environment Ready${NC}"
    echo -e "${GREEN}========================================${NC}"

    # Show key tool versions
    if command -v claude &> /dev/null; then
        echo -e "  Claude Code: $(claude --version 2>/dev/null | head -1 || echo 'installed')"
    fi
    if command -v python3 &> /dev/null; then
        echo -e "  Python:      $(python3 --version 2>/dev/null)"
    fi
    if command -v node &> /dev/null; then
        echo -e "  Node.js:     $(node --version 2>/dev/null)"
    fi
    if command -v docker &> /dev/null && docker info > /dev/null 2>&1; then
        echo -e "  Docker:      connected"
    fi

    echo ""
}

# ============================================
# Main
# ============================================
main() {
    log_info "Initializing development environment..."

    # Ensure PATH is set up before anything else
    setup_path

    # Update dotfiles (pulls latest from git)
    update_dotfiles

    # Core setup
    fix_permissions
    setup_git

    # Claude Code configuration
    configure_mcp
    configure_claude_mem

    # Editor extensions
    install_extensions

    # Start Xvfb if available (for Playwright)
    start_xvfb

    # Show summary
    print_summary

    # Execute the command passed to the container
    exec "$@"
}

main "$@"