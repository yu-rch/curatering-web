# =========================
# Base CUDA image (stable)
# =========================
FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# =========================
# System dependencies
# =========================
RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-dev \
    git curl wget build-essential \
    && rm -rf /var/lib/apt/lists/*

# =========================
# Python setup
# =========================
RUN pip3 install --upgrade pip

# =========================
# Core ML stack (stable zone)
# =========================

# PyTorch (CUDA 12.1 compatible stable)
RUN pip install torch==2.3.1 torchvision==0.18.1 --index-url https://download.pytorch.org/whl/cu121

# vLLM (stable modern version with better model support incl. Phi-3)
RUN pip install vllm>=0.4.0

# Transformers stack
RUN pip install transformers>=4.41.0 accelerate sentencepiece

# Numerical stack
RUN pip install numpy==1.26.4

# HTTP / API stack (fixes your earlier proxy + RunPod issues)
RUN pip install httpx==0.27.2 requests==2.31.0

# Supabase stable aligned versions
RUN pip install supabase==2.5.0 gotrue==2.5.0

# Optional utilities
RUN pip install fastapi uvicorn[standard]

# =========================
# Working directory
# =========================
WORKDIR /app

# =========================
# Copy your application
# =========================
COPY . /app

# =========================
# Environment variables (safe defaults)
# =========================
ENV PYTHONUNBUFFERED=1
ENV CUDA_VISIBLE_DEVICES=0

# =========================
# Expose API port
# =========================
EXPOSE 8000

# =========================
# Startup command
# (adjust if using vLLM server mode)
# =========================

CMD ["bash", "-c", "uvicorn main:app --host 0.0.0.0 --port 8000"]