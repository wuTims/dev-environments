# Dev Environments

Pre-built, multi-arch Docker images for consistent development across M-series Mac and Windows WSL2.

**Works with:** VS Code, Cursor, Windsurf, VSCodium, and any VS Code-compatible editor.

## Prerequisites

Before using dev-environments, install:

1. **Docker** - [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Mac/Windows) or [Docker Engine](https://docs.docker.com/engine/install/) (Linux)
2. **Editor** - [VS Code](https://code.visualstudio.com/), [Cursor](https://cursor.sh/), or compatible editor
3. **Git** - Usually pre-installed on Mac/Linux

## Quick Start

### First-Time Setup

```bash
# Clone this repo
git clone https://github.com/wutims/dev-environments.git
cd dev-environments

# Run bootstrap (pulls images, sets up convenience scripts)
./bootstrap.sh
```

### Run a Dev Container

```bash
# Start a Python dev container named "my-project"
./container.sh run python-dev my-project

# Start a Node.js container
./container.sh run node-dev frontend

# Start ML training environment
./container.sh run ml-training experiment-001
```

### Attach Your Editor

```bash
# Get a shell in the running container
./container.sh shell my-project

# Or in your editor:
# 1. Open Command Palette (Cmd/Ctrl + Shift + P)
# 2. Select "Dev Containers: Attach to Running Container"
# 3. Choose your container
```

### Manage Containers

```bash
./container.sh list              # Show running containers
./container.sh stop my-project   # Stop container (data persists)
./container.sh rm my-project     # Remove container (data still persists)
./container.sh pull              # Pull latest images
```

## Where Data Lives

All container data persists at `~/devcontainers/<container-name>/`:

```
~/devcontainers/
├── my-project/
│   └── workspace/          # Your code, mounted at /home/ubuntu/workspace
├── ml-experiment/
│   ├── workspace/
│   ├── data/               # ML data directory
│   └── models/             # Trained models
```

This survives container stops, restarts, and even removal.

## Available Images

| Image | Base | Key Tools | Use Cases |
|-------|------|-----------|-----------|
| `base` | Ubuntu 24.04 | Git, Docker CLI, Claude Code, spec-kit | Foundation |
| `python-dev` | base | Python 3.12, uv, ruff, mypy, pytest | Backend, APIs |
| `node-dev` | base | Node 22, pnpm, TypeScript, Vitest, Playwright | Frontend |
| `ml-training` | python-dev | PyTorch, Jupyter, MLflow, HuggingFace | ML/AI |

## Pre-installed Tools

### All Images

| Tool | Description |
|------|-------------|
| **Claude Code** | AI coding assistant |
| **DeepWiki MCP** | GitHub documentation via MCP |
| **spec-kit** | Spec-Driven Development (`specify` CLI) |
| **Docker CLI** | Docker-out-of-Docker support |
| **Oh-My-Zsh** | Enhanced shell with plugins |

### Python Images

| Tool | Description |
|------|-------------|
| **uv** | Fast Python package manager |
| **ruff** | Linter & formatter |
| **mypy** | Type checker |
| **pytest** | Testing framework |

### Node Images

| Tool | Description |
|------|-------------|
| **pnpm** | Fast package manager |
| **Playwright** | Browser automation + MCP |
| **Vitest** | Testing framework |
| **Biome** | Linter & formatter |

### ML Training

| Tool | Description |
|------|-------------|
| **PyTorch** | Deep learning framework |
| **Jupyter Lab** | Interactive notebooks |
| **MLflow** | Experiment tracking |
| **HuggingFace** | transformers, datasets, hub |

## Script Reference

### bootstrap.sh

One-time setup script for new machines:

```bash
./bootstrap.sh
```

- Checks prerequisites (Docker, editor)
- Configures git (if needed)
- Pulls dev images
- Installs `devctl` alias to `~/.local/bin`

### container.sh

Container lifecycle management:

```bash
./container.sh <command> [options]

Commands:
  run <image> [name]    Run container with automatic volume mounts
  pull [image]          Pull latest images
  list                  List running containers
  stop <name>           Stop container
  rm <name>             Remove container (data persists)
  shell <name>          Attach shell to container
  config                Show Docker Desktop manual config
```

After bootstrap, you can also use `devctl` as an alias:

```bash
devctl run python-dev my-api
devctl shell my-api
```

## Alternative: Devcontainer Workflow

If you prefer VS Code's native devcontainer integration:

```bash
# Copy devcontainer config to your project
cp -r ~/dev-environments/devcontainers/python-dev/.devcontainer ./

# Open project in editor - it will offer to reopen in container
code .
```

This uses the same images but lets VS Code manage the container lifecycle.

## Architecture

```
dev-environments/
├── bootstrap.sh              # First-time setup
├── container.sh              # Container management
├── images/
│   ├── base/                 # Common foundation
│   ├── python-dev/           # Python development
│   ├── node-dev/             # Node/React development
│   └── ml-training/          # ML/AI training
├── devcontainers/            # Ready-to-use devcontainer configs
├── shared/
│   ├── scripts/              # Entrypoint, extension installer
│   ├── mcp/                  # MCP server configurations
│   └── extensions/           # VS Code extension lists + security audit
└── .github/workflows/
    └── build-push.yml        # Multi-arch image builds
```

## Customization

### MCP Servers

MCPs are pre-configured in `~/.claude.json`:

```bash
# List configured MCPs
claude mcp list

# Add additional MCP servers
claude mcp add --scope user my-server -- npx @my/mcp-server
```

### spec-kit

```bash
# Initialize spec-driven development in a project
specify init my-project

# Available after init:
# /speckit.specify - Define requirements
# /speckit.plan - Create implementation plan
# /speckit.tasks - Generate task list
# /speckit.implement - Execute implementation
```

### Project-Specific Settings

Create `.devcontainer/devcontainer.json` in your project:

```json
{
  "image": "ghcr.io/wutims/python-dev:latest",
  "postCreateCommand": "uv pip install -r requirements.txt"
}
```

## Building Locally

```bash
# Build specific image
docker build -t python-dev -f images/python-dev/Dockerfile .

# Build with multi-arch
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ghcr.io/wutims/python-dev:latest \
  -f images/python-dev/Dockerfile .
```

## Troubleshooting

### Container won't start on M-series Mac

Ensure images are multi-arch compatible (ours are).

### Claude Code authentication

Run `claude` inside container and follow OAuth flow. Credentials persist in the container.

### Docker socket permission denied

The entrypoint automatically fixes permissions, but if issues persist:

```bash
# Inside container
sudo chmod 666 /var/run/docker.sock
```

### MCP servers not showing

Check `~/.claude.json` contains the `mcpServers` config:

```bash
cat ~/.claude.json | jq '.mcpServers'
```

### Extensions not showing

Extensions are pre-installed in the image. For "Attach to Container" workflow, they should appear automatically. If not, check the extension volumes are mounted.
