# ML Training Development Image
# Extends python-dev with ML/AI frameworks: PyTorch, Jupyter, MLflow
# Supports: linux/amd64 (with optional CUDA), linux/arm64 (M-series Mac - CPU only)

ARG REGISTRY=ghcr.io
ARG NAMESPACE=wutims
FROM ${REGISTRY}/${NAMESPACE}/python-dev:latest

LABEL org.opencontainers.image.description="ML/AI training environment with PyTorch and Jupyter"

ARG USERNAME=ubuntu

# ============================================
# System dependencies for ML (requires root)
# ============================================
USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    # HDF5 for data storage
    libhdf5-dev \
    # Graphics libraries
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Switch to non-root user
# ============================================
USER $USERNAME

ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"

# ============================================
# ML/AI Python packages
# Split into stages to avoid OOM during multi-arch builds
# GitHub Actions runners have ~7GB RAM limit
# ============================================

# Create venv
RUN uv venv ~/.ml-tools

# Stage 1: PyTorch (largest dependency - install alone)
# Using CPU-only for smaller image; GPU users can override at runtime
RUN . ~/.ml-tools/bin/activate \
    && uv pip install --no-cache-dir \
        torch \
        torchvision \
        torchaudio \
        --index-url https://download.pytorch.org/whl/cpu

# Stage 2: Data processing and core scientific stack
RUN . ~/.ml-tools/bin/activate \
    && uv pip install --no-cache-dir \
        numpy \
        pandas \
        polars \
        pyarrow \
        scikit-learn \
        scipy

# Stage 3: Visualization
RUN . ~/.ml-tools/bin/activate \
    && uv pip install --no-cache-dir \
        matplotlib \
        seaborn \
        plotly

# Stage 4: Jupyter ecosystem
RUN . ~/.ml-tools/bin/activate \
    && uv pip install --no-cache-dir \
        jupyterlab \
        ipywidgets \
        jupyter-ai

# Stage 5: Experiment tracking
RUN . ~/.ml-tools/bin/activate \
    && uv pip install --no-cache-dir \
        mlflow \
        wandb \
        tensorboard

# Stage 6: HuggingFace ecosystem
RUN . ~/.ml-tools/bin/activate \
    && uv pip install --no-cache-dir \
        huggingface-hub \
        transformers \
        datasets \
        accelerate \
        safetensors \
        tokenizers \
        sentencepiece

# Stage 7: Computer vision and utilities
RUN . ~/.ml-tools/bin/activate \
    && uv pip install --no-cache-dir \
        opencv-python-headless \
        albumentations \
        tqdm \
        einops \
        hydra-core \
        omegaconf \
        python-dotenv

# ============================================
# Shell configuration for ML
# ============================================
RUN echo '' >> ~/.zshrc \
    && echo '# ML environment' >> ~/.zshrc \
    && echo 'alias mlenv="source ~/.ml-tools/bin/activate"' >> ~/.zshrc \
    && echo 'alias jlab="jupyter lab --ip=0.0.0.0 --no-browser"' >> ~/.zshrc \
    && echo 'alias tb="tensorboard --logdir=./runs --bind_all"' >> ~/.zshrc \
    && echo '' >> ~/.zshrc \
    && echo '# GPU utilities (if available)' >> ~/.zshrc \
    && echo 'alias gpu="nvidia-smi"' >> ~/.zshrc \
    && echo 'alias gpuwatch="watch -n 1 nvidia-smi"' >> ~/.zshrc

# ============================================
# Jupyter configuration
# ============================================
RUN mkdir -p ~/.jupyter \
    && echo "c.ServerApp.ip = '0.0.0.0'" > ~/.jupyter/jupyter_lab_config.py \
    && echo "c.ServerApp.open_browser = False" >> ~/.jupyter/jupyter_lab_config.py \
    && echo "c.ServerApp.allow_origin = '*'" >> ~/.jupyter/jupyter_lab_config.py

# ============================================
# MLflow configuration
# ============================================
ENV MLFLOW_TRACKING_URI=mlruns

# ============================================
# Expose ports
# ============================================
EXPOSE 8888
EXPOSE 6006
EXPOSE 5000

WORKDIR /home/$USERNAME/workspace
CMD ["zsh"]