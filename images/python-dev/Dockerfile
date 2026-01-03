# Python Development Image
# Extends base with Python tooling: uv, ruff, mypy, pytest, FastAPI
# Supports: linux/amd64 (WSL2), linux/arm64 (M-series Mac)

ARG REGISTRY=ghcr.io
ARG NAMESPACE=wutims
FROM ${REGISTRY}/${NAMESPACE}/base:latest

LABEL org.opencontainers.image.description="Python development environment with modern tooling"

USER root

# ============================================
# Python installation
# ============================================
ARG PYTHON_VERSION=3.12
RUN add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        python${PYTHON_VERSION} \
        python${PYTHON_VERSION}-dev \
        python${PYTHON_VERSION}-venv \
        python${PYTHON_VERSION}-distutils \
    && rm -rf /var/lib/apt/lists/* \
    && update-alternatives --install /usr/bin/python python /usr/bin/python${PYTHON_VERSION} 1 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1

# ============================================
# uv - Fast Python package installer (replaces pip/pip-tools/virtualenv)
# ============================================
USER developer
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && echo 'eval "$(~/.local/bin/uv generate-shell-completion zsh)"' >> ~/.zshrc \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc

ENV PATH="/home/developer/.local/bin:${PATH}"

# ============================================
# Python development tools
# ============================================
RUN uv tool install ruff \
    && uv tool install mypy \
    && uv tool install pytest \
    && uv tool install coverage \
    && uv tool install pre-commit \
    && uv tool install httpie

# ============================================
# Global Python packages for development
# Create a shared tools venv that's always available
# ============================================
RUN uv venv ~/.dev-tools \
    && . ~/.dev-tools/bin/activate \
    && uv pip install \
        # Testing
        pytest \
        pytest-cov \
        pytest-asyncio \
        pytest-mock \
        pytest-xdist \
        hypothesis \
        # FastAPI stack
        fastapi \
        uvicorn[standard] \
        httpx \
        pydantic \
        pydantic-settings \
        # Type checking
        mypy \
        types-requests \
        # Code quality
        ruff \
        # Debugging
        ipython \
        ipdb \
        rich \
        # Documentation
        mkdocs \
        mkdocs-material

# Add dev-tools activation to shell
RUN echo '# Python dev tools' >> ~/.zshrc \
    && echo 'alias activate-dev="source ~/.dev-tools/bin/activate"' >> ~/.zshrc \
    && echo '# Auto-activate project venv if exists' >> ~/.zshrc \
    && echo 'auto_activate_venv() { [[ -f .venv/bin/activate ]] && source .venv/bin/activate }' >> ~/.zshrc \
    && echo 'chpwd_functions+=(auto_activate_venv)' >> ~/.zshrc

# ============================================
# Python configuration files
# ============================================
COPY --chown=developer:developer config/pyproject.toml.template /home/developer/.config/python/pyproject.toml.template
COPY --chown=developer:developer config/ruff.toml /home/developer/.config/ruff/ruff.toml
COPY --chown=developer:developer config/mypy.ini /home/developer/.config/mypy/mypy.ini

# ============================================
# Python-specific VS Code extensions
# ============================================
COPY --chown=developer:developer ../shared/extensions/python-extensions.txt /home/developer/.config/extensions/python-extensions.txt

# ============================================
# MCP Configuration (inherits DeepWiki from base)
# ============================================
# No additional MCPs for python-dev, inherits DeepWiki from base

WORKDIR /home/developer/workspace
CMD ["zsh"]
