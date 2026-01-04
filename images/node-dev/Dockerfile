# Node.js Development Image
# Extends base with Node/React/TypeScript tooling, Tailwind, Vitest, Playwright MCP
# Supports: linux/amd64 (WSL2), linux/arm64 (M-series Mac)

ARG REGISTRY=ghcr.io
ARG NAMESPACE=wutims
FROM ${REGISTRY}/${NAMESPACE}/base:latest

LABEL org.opencontainers.image.description="Node.js/React/TypeScript development environment"

ARG USERNAME=ubuntu

# ============================================
# System dependencies (requires root)
# ============================================
USER root

# Playwright browser dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxkbcommon0 \
    libatspi2.0-0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2t64 \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

# Global npm packages (requires root for /usr/lib/node_modules)
RUN npm install -g pnpm@latest

# ============================================
# Switch to non-root user
# ============================================
USER $USERNAME

# Setup pnpm for user
RUN pnpm setup \
    && echo 'export PNPM_HOME="$HOME/.local/share/pnpm"' >> ~/.zshrc \
    && echo 'export PATH="$PNPM_HOME:$PATH"' >> ~/.zshrc

ENV PNPM_HOME="/home/${USERNAME}/.local/share/pnpm"
ENV PATH="${PNPM_HOME}:${PATH}"

# ============================================
# Global Node.js tools (user space via pnpm)
# ============================================
RUN pnpm add -g \
    # TypeScript
    typescript \
    ts-node \
    tsx \
    # Linting & Formatting
    eslint \
    prettier \
    @biomejs/biome \
    # Build tools
    vite \
    turbo \
    # Testing
    vitest \
    # Utilities
    npm-check-updates \
    depcheck \
    serve \
    concurrently \
    nodemon

# ============================================
# Playwright browsers
# ============================================
RUN pnpm add -g playwright \
    && npx playwright install chromium

# Playwright system deps (requires root)
USER root
RUN npx playwright install-deps chromium
USER $USERNAME

# ============================================
# TanStack & React tooling (pre-cache)
# ============================================
RUN mkdir -p ~/.npm-cache/tanstack \
    && cd ~/.npm-cache/tanstack \
    && pnpm init -y \
    && pnpm add \
        @tanstack/react-query \
        @tanstack/react-router \
        @tanstack/react-table \
        @tanstack/react-form \
        @tanstack/start \
        react \
        react-dom \
        tailwindcss \
        postcss \
        autoprefixer \
        @tailwindcss/forms \
        @tailwindcss/typography \
        @tailwindcss/container-queries \
        clsx \
        class-variance-authority \
        tailwind-merge \
        lucide-react \
        zod \
    && rm -rf ~/.npm-cache/tanstack

# ============================================
# MCP Configuration (Playwright + DeepWiki)
# ============================================
COPY --chown=$USERNAME:$USERNAME images/node-dev/config/node-mcp.json /home/$USERNAME/.claude/settings.json

# ============================================
# Node-specific VS Code extensions
# ============================================
COPY --chown=$USERNAME:$USERNAME ../shared/extensions/node-extensions.txt /home/$USERNAME/.config/extensions/node-extensions.txt

# ============================================
# Configuration templates
# ============================================
COPY --chown=$USERNAME:$USERNAME images/node-dev/config/tsconfig.json.template /home/$USERNAME/.config/node/tsconfig.json.template
COPY --chown=$USERNAME:$USERNAME images/node-dev/config/eslint.config.js.template /home/$USERNAME/.config/node/eslint.config.js.template
COPY --chown=$USERNAME:$USERNAME images/node-dev/config/tailwind.config.js.template /home/$USERNAME/.config/node/tailwind.config.js.template
COPY --chown=$USERNAME:$USERNAME images/node-dev/config/vitest.config.ts.template /home/$USERNAME/.config/node/vitest.config.ts.template

# ============================================
# Shell aliases
# ============================================
RUN echo '' >> ~/.zshrc \
    && echo '# Node.js aliases' >> ~/.zshrc \
    && echo 'alias pi="pnpm install"' >> ~/.zshrc \
    && echo 'alias pd="pnpm dev"' >> ~/.zshrc \
    && echo 'alias pb="pnpm build"' >> ~/.zshrc \
    && echo 'alias pt="pnpm test"' >> ~/.zshrc \
    && echo 'alias pw="pnpm run test:watch"' >> ~/.zshrc \
    && echo 'alias lint="pnpm lint"' >> ~/.zshrc \
    && echo 'alias format="pnpm format"' >> ~/.zshrc \
    && echo '' >> ~/.zshrc \
    && echo '# Playwright' >> ~/.zshrc \
    && echo 'alias pwtest="npx playwright test"' >> ~/.zshrc \
    && echo 'alias pwui="npx playwright test --ui"' >> ~/.zshrc \
    && echo 'alias pwcodegen="npx playwright codegen"' >> ~/.zshrc

WORKDIR /home/$USERNAME/workspace
CMD ["zsh"]