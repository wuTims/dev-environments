#!/bin/bash
# ============================================
# Editor-Agnostic Extension Installer
# Works with VS Code, Cursor, Windsurf, and other VS Code forks
# Installs extensions inside the container for "Attach to Container" workflow
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[EXT]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[EXT]${NC} $1"; }
log_error() { echo -e "${RED}[EXT]${NC} $1"; }

# ============================================
# Detect available CLI tools
# ============================================
detect_editor_cli() {
    # Check for various VS Code-compatible CLIs
    # Priority: whatever is available
    local editors=("code" "cursor" "windsurf" "codium" "code-insiders")
    
    for editor in "${editors[@]}"; do
        if command -v "$editor" &> /dev/null; then
            echo "$editor"
            return 0
        fi
    done
    
    return 1
}

# ============================================
# Install extension using detected CLI
# ============================================
install_extension() {
    local ext_id="$1"
    local cli="$2"
    
    if [ -n "$cli" ]; then
        log_info "Installing $ext_id via $cli..."
        "$cli" --install-extension "$ext_id" --force 2>/dev/null || true
    else
        log_warn "No VS Code CLI found, skipping $ext_id"
    fi
}

# ============================================
# Install extensions from file
# ============================================
install_from_file() {
    local file="$1"
    local cli="$2"
    
    if [ ! -f "$file" ]; then
        log_warn "Extensions file not found: $file"
        return 1
    fi
    
    log_info "Installing extensions from $file..."
    
    while IFS= read -r ext || [ -n "$ext" ]; do
        # Skip empty lines and comments
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue
        install_extension "$ext" "$cli"
    done < "$file"
}

# ============================================
# Download extension from Open VSX (editor-agnostic)
# This works even without a VS Code CLI
# ============================================
download_from_openvsx() {
    local ext_id="$1"
    local target_dir="${2:-$HOME/.vscode-server/extensions}"
    
    # Parse publisher.extension format
    local publisher="${ext_id%%.*}"
    local extension="${ext_id#*.}"
    
    log_info "Downloading $ext_id from Open VSX..."
    
    # Get latest version info
    local api_url="https://open-vsx.org/api/${publisher}/${extension}"
    local version_info=$(curl -s "$api_url" 2>/dev/null)
    
    if [ -z "$version_info" ] || echo "$version_info" | grep -q "error"; then
        log_warn "Extension $ext_id not found on Open VSX, trying VS Code Marketplace..."
        return 1
    fi
    
    local version=$(echo "$version_info" | jq -r '.version // empty' 2>/dev/null)
    local download_url=$(echo "$version_info" | jq -r '.files.download // empty' 2>/dev/null)
    
    if [ -z "$download_url" ]; then
        log_warn "Could not get download URL for $ext_id"
        return 1
    fi
    
    # Download and extract
    local temp_dir=$(mktemp -d)
    local vsix_file="$temp_dir/${ext_id}.vsix"
    
    curl -sL "$download_url" -o "$vsix_file" 2>/dev/null
    
    if [ -f "$vsix_file" ]; then
        mkdir -p "$target_dir/${publisher}.${extension}-${version}"
        unzip -q "$vsix_file" -d "$temp_dir/extracted" 2>/dev/null
        cp -r "$temp_dir/extracted/extension/"* "$target_dir/${publisher}.${extension}-${version}/" 2>/dev/null || true
        log_info "Installed $ext_id v$version"
    fi
    
    rm -rf "$temp_dir"
}

# ============================================
# Get all possible server extension directories
# Different editors use different paths
# ============================================
get_extension_dirs() {
    local dirs=(
        "$HOME/.vscode-server/extensions"      # VS Code
        "$HOME/.cursor-server/extensions"      # Cursor
        "$HOME/.windsurf-server/extensions"    # Windsurf
        "$HOME/.vscodium-server/extensions"    # VSCodium
    )
    echo "${dirs[@]}"
}

# ============================================
# Install extensions for "Attach to Container" workflow
# Installs to ALL known editor server directories
# ============================================
install_for_attach_workflow() {
    local extensions_file="${1:-$HOME/.config/extensions/base-extensions.txt}"

    if [ ! -f "$extensions_file" ]; then
        log_warn "No extensions file at $extensions_file"
        return
    fi

    # Get all extension directories
    local dirs=($(get_extension_dirs))

    log_info "Installing extensions for Attach to Container workflow..."
    log_info "Target directories: ${dirs[*]}"

    # Create all directories
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done

    # Read extensions and install to all directories
    while IFS= read -r ext || [ -n "$ext" ]; do
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue

        # Download once to temp, then copy to all directories
        local temp_dir=$(mktemp -d)

        # Parse publisher.extension format
        local publisher="${ext%%.*}"
        local extension="${ext#*.}"

        log_info "Downloading $ext from Open VSX..."

        # Get latest version info
        local api_url="https://open-vsx.org/api/${publisher}/${extension}"
        local version_info=$(curl -s "$api_url" 2>/dev/null)

        if [ -z "$version_info" ] || echo "$version_info" | grep -q '"error"'; then
            log_warn "Extension $ext not found on Open VSX"
            rm -rf "$temp_dir"
            continue
        fi

        local version=$(echo "$version_info" | jq -r '.version // empty' 2>/dev/null)
        local download_url=$(echo "$version_info" | jq -r '.files.download // empty' 2>/dev/null)

        if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
            log_warn "Could not get download URL for $ext"
            rm -rf "$temp_dir"
            continue
        fi

        # Download and extract once
        local vsix_file="$temp_dir/${ext}.vsix"
        curl -sL "$download_url" -o "$vsix_file" 2>/dev/null

        if [ -f "$vsix_file" ]; then
            unzip -q "$vsix_file" -d "$temp_dir/extracted" 2>/dev/null || true

            if [ -d "$temp_dir/extracted/extension" ]; then
                # Copy to all editor directories
                for dir in "${dirs[@]}"; do
                    local ext_dir="$dir/${publisher}.${extension}-${version}"
                    mkdir -p "$ext_dir"
                    cp -r "$temp_dir/extracted/extension/"* "$ext_dir/" 2>/dev/null || true
                done
                log_info "Installed $ext v$version to all editor directories"
            fi
        fi

        rm -rf "$temp_dir"
    done < "$extensions_file"
}

# ============================================
# Main
# ============================================
main() {
    local mode="${1:-auto}"
    local extensions_file="${2:-}"
    
    case "$mode" in
        cli)
            # Install using detected VS Code CLI
            local cli=$(detect_editor_cli)
            if [ -n "$cli" ]; then
                log_info "Using CLI: $cli"
                if [ -n "$extensions_file" ]; then
                    install_from_file "$extensions_file" "$cli"
                else
                    install_from_file "$HOME/.config/extensions/base-extensions.txt" "$cli"
                fi
            else
                log_warn "No VS Code-compatible CLI found"
            fi
            ;;
        openvsx)
            # Download directly from Open VSX
            install_for_attach_workflow "$extensions_file"
            ;;
        auto|*)
            # Try CLI first, fall back to Open VSX
            local cli=$(detect_editor_cli)
            if [ -n "$cli" ]; then
                log_info "Using CLI: $cli"
                install_from_file "${extensions_file:-$HOME/.config/extensions/base-extensions.txt}" "$cli"
            else
                log_info "No CLI found, using Open VSX download"
                install_for_attach_workflow "$extensions_file"
            fi
            ;;
    esac
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
