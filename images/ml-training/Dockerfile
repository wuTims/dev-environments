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
# ============================================
RUN uv venv ~/.ml-tools \
    && . ~/.ml-tools/bin/activate \
    && uv pip install \
        # Core ML frameworks
        torch \
        torchvision \
        torchaudio \
        # Data processing
        numpy \
        pandas \
        polars \
        pyarrow \
        # Visualization
        matplotlib \
        seaborn \
        plotly \
        # Jupyter
        jupyterlab \
        ipywidgets \
        jupyter-ai \
        # Experiment tracking
        mlflow \
        wandb \
        tensorboard \
        # Model management
        huggingface-hub \
        transformers \
        datasets \
        accelerate \
        safetensors \
        # Computer vision
        opencv-python-headless \
        albumentations \
        # NLP
        tokenizers \
        sentencepiece \
        # Utilities
        scikit-learn \
        scipy \
        tqdm \
        einops \
        # Config management
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