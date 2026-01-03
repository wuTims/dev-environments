# Node.js Development Image
# Extends base with Node/React/TypeScript tooling, Tailwind, Vitest, Playwright MCP
# Supports: linux/amd64 (WSL2), linux/arm64 (M-series Mac)

ARG REGISTRY=ghcr.io
ARG NAMESPACE=YOUR_USERNAME
FROM ${REGISTRY}/${NAMESPACE}/base:latest

LABEL org.opencontainers.image.description="Node.js/React/TypeScript development environment"

USER root

# ============================================
# Playwright dependencies (for browser automation)
# ============================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Playwright browser dependencies
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
    # Additional utilities
    xvfb \
    && rm -rf /var/lib/apt/lists/*

USER developer

# ============================================
# pnpm - Fast, disk space efficient package manager
# ============================================
RUN npm install -g pnpm@latest \
    && pnpm setup \
    && echo 'export PNPM_HOME="$HOME/.local/share/pnpm"' >> ~/.zshrc \
    && echo 'export PATH="$PNPM_HOME:$PATH"' >> ~/.zshrc

ENV PNPM_HOME="/home/developer/.local/share/pnpm"
ENV PATH="${PNPM_HOME}:${PATH}"

# ============================================
# Global Node.js tools
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
# Playwright browsers (pre-install to avoid runtime delays)
# ============================================
RUN pnpm add -g playwright \
    && npx playwright install chromium \
    && npx playwright install-deps chromium

# ============================================
# TanStack & React tooling
# Pre-install common packages to speed up project setup
# ============================================
RUN mkdir -p ~/.npm-cache/tanstack \
    && cd ~/.npm-cache/tanstack \
    && pnpm init -y \
    && pnpm add \
        # TanStack ecosystem
        @tanstack/react-query \
        @tanstack/react-router \
        @tanstack/react-table \
        @tanstack/react-form \
        @tanstack/start \
        # React
        react \
        react-dom \
        # Tailwind CSS
        tailwindcss \
        postcss \
        autoprefixer \
        @tailwindcss/forms \
        @tailwindcss/typography \
        @tailwindcss/container-queries \
        # Common UI libraries
        clsx \
        class-variance-authority \
        tailwind-merge \
        lucide-react \
        # Zod for validation
        zod \
    && rm -rf ~/.npm-cache/tanstack

# ============================================
# MCP Configuration
# ============================================
# Copy node-specific MCP config (includes Playwright MCP + DeepWiki)
COPY --chown=developer:developer config/node-mcp.json /home/developer/.config/claude/.mcp.json

# ============================================
# Node-specific VS Code extensions
# ============================================
COPY --chown=developer:developer ../shared/extensions/node-extensions.txt /home/developer/.config/extensions/node-extensions.txt

# ============================================
# Configuration templates
# ============================================
COPY --chown=developer:developer config/tsconfig.json.template /home/developer/.config/node/tsconfig.json.template
COPY --chown=developer:developer config/eslint.config.js.template /home/developer/.config/node/eslint.config.js.template
COPY --chown=developer:developer config/tailwind.config.js.template /home/developer/.config/node/tailwind.config.js.template
COPY --chown=developer:developer config/vitest.config.ts.template /home/developer/.config/node/vitest.config.ts.template

# ============================================
# Shell aliases for Node development
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

WORKDIR /home/developer/workspace
CMD ["zsh"]
