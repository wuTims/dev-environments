# Dev Environments

Pre-built, multi-arch Docker images for consistent development across M-series Mac and Windows WSL2.

**Works with:** VS Code, Cursor, Windsurf, VSCodium, and any VS Code-compatible editor.

## Quick Start

### First-Time Setup (Any Machine)

```bash
# Clone this repo
git clone https://github.com/YOUR_USERNAME/dev-environments.git
cd dev-environments

# Run bootstrap (installs Docker, detects/installs editor, configures everything)
./bootstrap.sh
```

### Start Developing

```bash
# Clone any project
git clone https://github.com/your/project.git
cd project

# Copy the devcontainer you need
cp -r ~/dev-environments/devcontainers/python-dev/.devcontainer .

# Open in your editor - it will auto-detect and offer to reopen in container
cursor .  # or: code . / windsurf . / codium .
```

### "Attach to Running Container" Workflow

If you prefer running containers manually and attaching:

```bash
# Start container
docker run -d --name my-dev \
  -v $(pwd):/home/developer/workspace \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/YOUR_USERNAME/python-dev:latest \
  sleep infinity

# In your editor: "Attach to Running Container" -> my-dev
# Extensions are pre-installed inside the container!
```

## Available Images

| Image | Base | Key Tools | Use Cases |
|-------|------|-----------|-----------|
| `base` | Ubuntu 24.04 | Git, Docker CLI, Claude Code, DeepWiki MCP, spec-kit, claude-mem | Foundation for all others |
| `python-dev` | base | Python 3.12, uv, ruff, mypy, pytest, FastAPI | Backend, scripts, APIs |
| `node-dev` | base | Node 22, pnpm, TypeScript, React, Tailwind, Vitest, Playwright MCP | Frontend, full-stack |
| `ml-training` | python-dev | PyTorch, CUDA, Jupyter, MLflow | Model training |

## Pre-installed Tools

### All Images (Base)

| Tool | Description |
|------|-------------|
| **Claude Code** | AI coding assistant (native binary) |
| **claude-mem** | Persistent memory plugin for Claude Code |
| **DeepWiki MCP** | GitHub repo documentation via MCP |
| **spec-kit** | Spec-Driven Development CLI (`specify` command) |
| **Docker CLI** | For Docker-out-of-Docker workflows |

### Python Images

| Tool | Description |
|------|-------------|
| **uv** | Fast Python package manager |
| **ruff** | Linter & formatter |
| **mypy** | Type checker |
| **pytest** | Testing framework with coverage |

### Node Images

| Tool | Description |
|------|-------------|
| **pnpm** | Fast package manager |
| **Playwright** | Browser automation + MCP server |
| **Vitest** | Testing framework |
| **Biome** | Linter & formatter |

## Architecture

```
dev-environments/
├── bootstrap.sh              # One-liner setup for new machines
├── images/
│   ├── base/                 # Common foundation
│   ├── python-dev/           # Python development
│   ├── node-dev/             # Node/React development
│   └── ml-training/          # ML/AI training
├── devcontainers/
│   ├── python-dev/           # Ready-to-use devcontainer configs
│   ├── node-dev/
│   ├── ml-training/
│   └── general/              # Python + Node combined
├── shared/
│   ├── scripts/              # Common shell scripts
│   ├── dotfiles/             # zshrc, gitconfig templates
│   ├── mcp/                  # MCP server configurations
│   └── extensions/           # VS Code extension lists
└── .github/workflows/
    └── build-push.yml        # Multi-arch image builds
```

## Editor Compatibility

Extensions are handled two ways to support different workflows:

1. **"Reopen in Container"**: Extensions defined in `devcontainer.json` are installed by your editor
2. **"Attach to Running Container"**: Extensions are pre-installed inside the container image

This means extensions work regardless of which VS Code-compatible editor you use.

### Supported Editors

- VS Code
- Cursor
- Windsurf
- VSCodium
- VS Code Insiders
- Any editor supporting the devcontainer spec

## Docker-out-of-Docker Support

All images support connecting to the host's Docker engine for integration testing:

```json
// In devcontainer.json
"mounts": [
  "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind"
]
```

This allows spinning up sibling containers for E2E testing without nested Docker overhead.

## Customization

### Adding Tools to Base

Edit `images/base/Dockerfile` and push. All child images will inherit on next build.

### Project-Specific Extensions

Add to your project's `.devcontainer/devcontainer.json`:

```json
{
  "image": "ghcr.io/YOUR_USERNAME/python-dev:latest",
  "postCreateCommand": "uv pip install -r requirements-dev.txt"
}
```

### MCP Servers

MCPs are pre-configured but can be customized:

```bash
# Add additional MCP servers
claude mcp add my-server -- npx @my/mcp-server

# List configured MCPs
claude mcp list
```

### spec-kit

```bash
# Initialize spec-driven development
specify init my-project

# Check environment
specify check

# More: specify --help
```

### claude-mem

```bash
# View memory stream
open http://localhost:37777

# Search project history
# Use the mem-search skill in Claude Code
```

## Building Locally

```bash
# Build specific image
docker build -t dev-base ./images/base

# Build with buildx for multi-arch
docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/YOUR_USERNAME/base:latest ./images/base
```

## Updating Images

Images auto-update via GitHub Actions on push to `main`. To force rebuild:

```bash
gh workflow run build-push.yml
```

## Troubleshooting

### Container won't start on M-series Mac
Ensure you're using `linux/arm64` compatible image. Our images support both architectures.

### Claude Code authentication
Run `claude` inside container and follow OAuth flow. Credentials persist in mounted volume.

### Docker socket permission denied
Add your user to docker group or ensure socket has correct permissions in devcontainer.json mounts.

### Extensions not showing in "Attach to Container"
Extensions are installed in `/home/developer/.vscode-server/extensions`. Mount this as a volume to persist across container restarts:
```json
"mounts": [
  "source=vscode-extensions,target=/home/developer/.vscode-server/extensions,type=volume"
]
```
