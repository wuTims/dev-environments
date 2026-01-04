# Base Development Image
# Foundation for all dev environments with common tooling
# Supports: linux/amd64 (WSL2), linux/arm64 (M-series Mac)

FROM ubuntu:24.04

LABEL maintainer="your-email@example.com"
LABEL org.opencontainers.image.source="https://github.com/wutims/dev-environments"
LABEL org.opencontainers.image.description="Base development environment with Claude Code and common tools"

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Shell configuration
ENV SHELL=/bin/zsh
ENV TERM=xterm-256color

# ============================================
# System packages and utilities
# ============================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core utilities
    ca-certificates \
    curl \
    wget \
    gnupg \
    lsb-release \
    software-properties-common \
    sudo \
    # Development essentials
    build-essential \
    git \
    git-lfs \
    openssh-client \
    # Shell and terminal
    zsh \
    tmux \
    neovim \
    # File utilities
    tree \
    jq \
    ripgrep \
    fd-find \
    fzf \
    bat \
    eza \
    unzip \
    zip \
    # Network utilities
    netcat-openbsd \
    dnsutils \
    iputils-ping \
    # Process utilities
    htop \
    procps \
    # Locale support
    locales \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8

# ============================================
# Docker CLI (for Docker-out-of-Docker)
# ============================================
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        docker-ce-cli \
        docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# GitHub CLI
# ============================================
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# AWS CLI
# ============================================
RUN ARCH=$(dpkg --print-architecture) \
    && if [ "$ARCH" = "amd64" ]; then AWS_ARCH="x86_64"; else AWS_ARCH="aarch64"; fi \
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" -o "/tmp/awscliv2.zip" \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

# ============================================
# Google Cloud CLI
# ============================================
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends google-cloud-cli \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Node.js (required for Claude Code and MCPs)
# ============================================
ARG NODE_VERSION=22
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g npm@latest

# ============================================
# Create non-root user
# ============================================
# ============================================
# Configure existing ubuntu user for development
# ============================================
ARG USERNAME=ubuntu

RUN echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && chsh -s /bin/zsh $USERNAME \
    && groupadd -f docker \
    && usermod -aG docker $USERNAME

# ============================================
# Setup user environment
# ============================================
USER $USERNAME
WORKDIR /home/$USERNAME

# Oh-My-Zsh for better shell experience
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    && git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# ============================================
# Python & uv (needed for spec-kit)
# ============================================
USER root
RUN add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        python3.12 \
        python3.12-venv \
    && rm -rf /var/lib/apt/lists/* \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

USER $USERNAME

# Install uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc

ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"

# ============================================
# spec-kit (Spec-Driven Development)
# https://github.com/github/spec-kit
# ============================================
RUN uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

# ============================================
# Bun (fast JavaScript runtime and package manager)
# Required for claude-mem plugin
# ============================================
RUN curl -fsSL https://bun.sh/install | bash \
    && echo 'export BUN_INSTALL="$HOME/.bun"' >> ~/.zshrc \
    && echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> ~/.zshrc

ENV BUN_INSTALL="/home/${USERNAME}/.bun"
ENV PATH="${BUN_INSTALL}/bin:${PATH}"

# ============================================
# Claude Code (native binary - recommended 2025 method)
# ============================================
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && echo 'export PATH="$HOME/.claude/bin:$PATH"' >> ~/.zshrc \
    && echo 'export PATH="$HOME/.claude/bin:$PATH"' >> ~/.bashrc

# Ensure Claude is in PATH for this build stage
ENV PATH="/home/${USERNAME}/.claude/bin:${PATH}"

# ============================================
# claude-mem plugin (Persistent Memory for Claude Code)
# https://github.com/thedotmack/claude-mem
# ============================================
USER root
RUN npm install -g claude-mem

# ============================================
# Cloudflare CLI (Wrangler)
# ============================================
RUN npm install -g wrangler
USER $USERNAME

# ============================================
# VS Code Server Extensions (for Attach to Container workflow)
# These persist inside the container for any VS Code-compatible editor
# ============================================
COPY --chown=$USERNAME:$USERNAME shared/scripts/install-extensions.sh /home/$USERNAME/.local/bin/install-extensions.sh
RUN chmod +x /home/$USERNAME/.local/bin/install-extensions.sh

# Pre-install common extensions at build time (editor-agnostic via Open VSX)
# Extensions list is defined in shared/extensions/base-extensions.txt
COPY --chown=$USERNAME:$USERNAME shared/extensions/base-extensions.txt /home/$USERNAME/.config/extensions/base-extensions.txt
RUN mkdir -p /home/$USERNAME/.vscode-server/extensions

# ============================================
# MCP Server Configuration
# ============================================
# Create MCP config directory
RUN mkdir -p ~/.config/claude ~/.claude

# DeepWiki MCP (HTTP transport - no local server needed)
# This will be configured on first run via entrypoint
COPY --chown=$USERNAME:$USERNAME shared/mcp/base-mcp.json /home/$USERNAME/.claude/settings.json

# ============================================
# Shell configuration
# ============================================
COPY --chown=$USERNAME:$USERNAME shared/dotfiles/.zshrc.template /home/$USERNAME/.zshrc.custom
RUN cat /home/$USERNAME/.zshrc.custom >> /home/$USERNAME/.zshrc

# ============================================
# Workspace setup
# ============================================
RUN mkdir -p /home/$USERNAME/workspace
WORKDIR /home/$USERNAME/workspace

# ============================================
# Entrypoint for MCP setup
# ============================================
COPY --chown=$USERNAME:$USERNAME shared/scripts/entrypoint.sh /home/$USERNAME/.local/bin/entrypoint.sh
RUN chmod +x /home/$USERNAME/.local/bin/entrypoint.sh

ENTRYPOINT ["/home/ubuntu/.local/bin/entrypoint.sh"]
CMD ["zsh"]
