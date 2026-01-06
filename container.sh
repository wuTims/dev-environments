#!/bin/bash
# ============================================
# Dev Container Runner
# Pulls images and runs containers with proper volume mounts
# Works with both Docker CLI and Docker Desktop
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Configuration
REGISTRY="${REGISTRY:-ghcr.io}"
NAMESPACE="${NAMESPACE:-wutims}"
BASE_DIR="${DEV_CONTAINERS_DIR:-$HOME/devcontainers}"

# Available images
IMAGES=("python-dev" "node-dev" "ml-training" "base")

usage() {
    echo ""
    echo -e "${CYAN}Dev Container Runner${NC}"
    echo "Runs dev containers with automatic volume mounts and persistence"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  run <image> [name]    Run a container (pulls if needed)"
    echo "  pull [image]          Pull latest images (all if no image specified)"
    echo "  list                  List running dev containers"
    echo "  stop <name>           Stop a running container"
    echo "  rm <name>             Remove a stopped container"
    echo "  shell <name>          Attach shell to running container"
    echo "  config                Show Docker Desktop run configuration"
    echo ""
    echo "Images: ${IMAGES[*]}"
    echo ""
    echo "Examples:"
    echo "  $0 run python-dev                    # Run with auto-generated name"
    echo "  $0 run python-dev my-project         # Run with custom name"
    echo "  $0 run ml-training ml-exp-001        # Run ML container"
    echo "  $0 pull                              # Pull all latest images"
    echo "  $0 shell my-project                  # Attach to running container"
    echo ""
    echo "Environment Variables:"
    echo "  DEV_CONTAINERS_DIR    Base directory for mounts (default: ~/devcontainers)"
    echo "  REGISTRY              Container registry (default: ghcr.io)"
    echo "  NAMESPACE             Image namespace (default: wutims)"
    echo ""
}

# ============================================
# Check Docker is running
# ============================================
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker Desktop."
        exit 1
    fi
}

# ============================================
# Pull images
# ============================================
pull_images() {
    local image="$1"

    if [ -n "$image" ]; then
        log_step "Pulling $REGISTRY/$NAMESPACE/$image:latest..."
        docker pull "$REGISTRY/$NAMESPACE/$image:latest"
    else
        log_step "Pulling all dev images..."
        for img in "${IMAGES[@]}"; do
            log_info "Pulling $img..."
            docker pull "$REGISTRY/$NAMESPACE/$img:latest" || log_warn "Failed to pull $img"
        done
    fi

    log_info "Pull complete!"
}

# ============================================
# Get volume mounts for an image type
# ============================================
get_mounts() {
    local image_type="$1"
    local container_name="$2"
    local workspace_dir="$BASE_DIR/$container_name"

    # Common mounts for all containers
    local mounts=(
        # Workspace persistence
        "-v" "$workspace_dir/workspace:/home/ubuntu/workspace"
        # VS Code server extensions (named volumes for persistence)
        "-v" "vscode-$container_name:/home/ubuntu/.vscode-server/extensions"
        "-v" "cursor-$container_name:/home/ubuntu/.cursor-server/extensions"
        # Git config from host
        "-v" "$HOME/.gitconfig:/home/ubuntu/.gitconfig:ro"
        # SSH keys (read-only for security)
        "-v" "$HOME/.ssh:/home/ubuntu/.ssh:ro"
    )

    # Docker socket (if exists)
    if [ -S "/var/run/docker.sock" ]; then
        mounts+=("-v" "/var/run/docker.sock:/var/run/docker.sock")
    fi

    # Image-specific mounts
    case "$image_type" in
        ml-training)
            mounts+=(
                "-v" "$workspace_dir/data:/home/ubuntu/data"
                "-v" "$workspace_dir/models:/home/ubuntu/models"
                "-v" "$workspace_dir/mlruns:/home/ubuntu/mlruns"
                "-v" "huggingface-cache:/home/ubuntu/.cache/huggingface"
            )
            ;;
        node-dev)
            mounts+=(
                "-v" "pnpm-store-$container_name:/home/ubuntu/.local/share/pnpm/store"
            )
            ;;
        python-dev)
            mounts+=(
                "-v" "pip-cache-$container_name:/home/ubuntu/.cache/pip"
                "-v" "uv-cache-$container_name:/home/ubuntu/.cache/uv"
            )
            ;;
    esac

    echo "${mounts[@]}"
}


# ============================================
# Create required directories
# ============================================
create_directories() {
    local image_type="$1"
    local container_name="$2"
    local workspace_dir="$BASE_DIR/$container_name"

    log_info "Creating directories at $workspace_dir..."
    mkdir -p "$workspace_dir/workspace"

    case "$image_type" in
        ml-training)
            mkdir -p "$workspace_dir/data"
            mkdir -p "$workspace_dir/models"
            mkdir -p "$workspace_dir/mlruns"
            ;;
    esac
}

# ============================================
# Run a container
# ============================================
run_container() {
    local image_type="$1"
    local container_name="${2:-$image_type-$(date +%Y%m%d%H%M%S)}"

    # Validate image type
    local valid=false
    for img in "${IMAGES[@]}"; do
        if [ "$image_type" == "$img" ]; then
            valid=true
            break
        fi
    done

    if [ "$valid" != "true" ]; then
        log_error "Invalid image type: $image_type"
        log_info "Available images: ${IMAGES[*]}"
        exit 1
    fi

    local full_image="$REGISTRY/$NAMESPACE/$image_type:latest"

    # Always pull latest (docker only downloads changed layers)
    log_info "Pulling latest image..."
    docker pull "$full_image"

    # Check if container already exists
    if docker container inspect "$container_name" > /dev/null 2>&1; then
        log_warn "Container '$container_name' already exists"
        read -p "Start existing container? [Y/n] " response
        if [[ "$response" =~ ^[Nn]$ ]]; then
            exit 0
        fi
        docker start "$container_name"
        log_info "Container '$container_name' started"
        log_info "Attach with: $0 shell $container_name"
        return
    fi

    # Create required directories
    create_directories "$image_type" "$container_name"

    # Build run command
    local mounts
    mounts=$(get_mounts "$image_type" "$container_name")

    log_step "Starting container '$container_name'..."
    log_info "Image: $full_image"
    log_info "Workspace: $BASE_DIR/$container_name/workspace"

    # Run the container
    # shellcheck disable=SC2086
    docker run -d \
        --name "$container_name" \
        --hostname "$container_name" \
        --restart unless-stopped \
        $mounts \
        -e "CONTAINER_NAME=$container_name" \
        "$full_image" \
        sleep infinity

    log_info "Container '$container_name' is running!"
    echo ""
    echo -e "${CYAN}Quick Start:${NC}"
    echo "  Attach shell:           $0 shell $container_name"
    echo "  VS Code/Cursor attach:  Use 'Attach to Running Container' in your editor"
    echo "  Stop container:         $0 stop $container_name"
    echo ""
    echo -e "${CYAN}Workspace Location:${NC}"
    echo "  Host:      $BASE_DIR/$container_name/workspace"
    echo "  Container: /home/ubuntu/workspace"
    echo ""

    if [ "$image_type" == "ml-training" ]; then
        echo -e "${CYAN}ML-specific:${NC}"
        echo "  Data:   $BASE_DIR/$container_name/data  -> /home/ubuntu/data"
        echo "  Models: $BASE_DIR/$container_name/models -> /home/ubuntu/models"
        echo ""
    fi
}

# ============================================
# List running containers
# ============================================
list_containers() {
    log_step "Running dev containers:"
    docker ps --filter "label=org.opencontainers.image.source" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || \
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | grep -E "(NAMES|wutims)" || \
    echo "No dev containers running"
}

# ============================================
# Stop a container
# ============================================
stop_container() {
    local name="$1"
    if [ -z "$name" ]; then
        log_error "Container name required"
        exit 1
    fi

    log_step "Stopping container '$name'..."
    docker stop "$name"
    log_info "Container stopped. Data persisted at $BASE_DIR/$name/"
}

# ============================================
# Remove a container
# ============================================
remove_container() {
    local name="$1"
    if [ -z "$name" ]; then
        log_error "Container name required"
        exit 1
    fi

    log_warn "This will remove container '$name' but NOT delete persisted data."
    log_info "Data at $BASE_DIR/$name/ will remain."
    read -p "Continue? [y/N] " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 0
    fi

    docker rm -f "$name" 2>/dev/null || true
    log_info "Container removed"
}

# ============================================
# Attach shell to container
# ============================================
shell_container() {
    local name="$1"
    if [ -z "$name" ]; then
        log_error "Container name required"
        exit 1
    fi

    log_info "Attaching to container '$name'..."
    docker exec -it "$name" zsh
}

# ============================================
# Show Docker Desktop configuration
# ============================================
show_config() {
    echo ""
    echo -e "${CYAN}Docker Desktop Run Configuration${NC}"
    echo ""
    echo "When running images directly from Docker Desktop UI, use these settings:"
    echo ""
    echo -e "${YELLOW}For python-dev:${NC}"
    echo "  Container name: python-dev-main (or your choice)"
    echo "  Volumes:"
    echo "    ~/devcontainers/python-dev-main/workspace -> /home/ubuntu/workspace"
    echo "    ~/.gitconfig -> /home/ubuntu/.gitconfig (read-only)"
    echo "    ~/.ssh -> /home/ubuntu/.ssh (read-only)"
    echo "    /var/run/docker.sock -> /var/run/docker.sock"
    echo "  Ports: 8000:8000, 5000:5000, 8080:8080"
    echo ""
    echo -e "${YELLOW}For node-dev:${NC}"
    echo "  Container name: node-dev-main"
    echo "  Volumes:"
    echo "    ~/devcontainers/node-dev-main/workspace -> /home/ubuntu/workspace"
    echo "    ~/.gitconfig -> /home/ubuntu/.gitconfig (read-only)"
    echo "    ~/.ssh -> /home/ubuntu/.ssh (read-only)"
    echo "    /var/run/docker.sock -> /var/run/docker.sock"
    echo "  Ports: 3000:3000, 5173:5173, 6006:6006"
    echo ""
    echo -e "${YELLOW}For ml-training:${NC}"
    echo "  Container name: ml-training-main"
    echo "  Volumes:"
    echo "    ~/devcontainers/ml-training-main/workspace -> /home/ubuntu/workspace"
    echo "    ~/devcontainers/ml-training-main/data -> /home/ubuntu/data"
    echo "    ~/devcontainers/ml-training-main/models -> /home/ubuntu/models"
    echo "    ~/.gitconfig -> /home/ubuntu/.gitconfig (read-only)"
    echo "    ~/.ssh -> /home/ubuntu/.ssh (read-only)"
    echo "  Ports: 8888:8888, 6006:6006, 5000:5000"
    echo ""
    echo -e "${GREEN}Recommended:${NC} Use './dev-run.sh run <image> <name>' instead for automatic setup!"
    echo ""
}

# ============================================
# Main
# ============================================
main() {
    local command="${1:-}"

    case "$command" in
        run)
            check_docker
            run_container "$2" "$3"
            ;;
        pull)
            check_docker
            pull_images "$2"
            ;;
        list|ls)
            check_docker
            list_containers
            ;;
        stop)
            check_docker
            stop_container "$2"
            ;;
        rm|remove)
            check_docker
            remove_container "$2"
            ;;
        shell|attach|exec)
            check_docker
            shell_container "$2"
            ;;
        config)
            show_config
            ;;
        help|--help|-h|"")
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

main "$@"
