FROM runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel

WORKDIR /app

# =========================================================
# SYSTEM DEPENDENCIES
# =========================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# =========================================================
# PYTHON BASE SETUP
# =========================================================
RUN python3 -m pip install --no-cache-dir --upgrade pip

# critical stability pin
RUN python3 -m pip install --no-cache-dir numpy==1.26.4

# =========================================================
# PYTORCH ECOSYSTEM (PINNED FOR STABILITY)
# =========================================================
RUN python3 -m pip install --no-cache-dir \
    torch==2.1.0 \
    torchvision==0.16.0 \
    torchaudio==2.1.0

# =========================================================
# CORE AI STACK
# =========================================================
RUN python3 -m pip install --no-cache-dir \
    torch==2.1.0 \
    torchvision==0.16.0 \
    torchaudio==2.1.0 \
    diffusers==0.27.2 \
    transformers==4.38.2 \
    accelerate==0.28.0 \
    safetensors \
    huggingface_hub==0.20.3 \
    xformers==0.0.22.post7\
    controlnet-aux \
    pillow \
    requests \
    runpod \
    supabase

# =========================================================
# VERIFY INSTALL
# =========================================================
RUN python3 -c "import torch, diffusers, runpod; print('OK torch', torch.__version__); print('OK diffusers', diffusers.__version__)"

# =========================================================
# ENV CONFIG
# =========================================================
ENV HF_HOME=/app/huggingface
ENV TRANSFORMERS_CACHE=/app/huggingface
ENV DIFFUSERS_CACHE=/app/huggingface

ENV SD_MODEL_ID=runwayml/stable-diffusion-v1-5
ENV SD_CONTROLNET_MODEL_ID=lllyasviel/control_v11p_sd15_depth
ENV SD_DEPTH_ANNOTATOR_MODEL_ID=lllyasviel/Annotators
ENV SD_IMAGE_SIZE=768

# =========================================================
# COPY CODE
# =========================================================
COPY prompt_engine.py prompt_engine.py
COPY handler.py handler.py

# =========================================================
# START
# =========================================================
CMD ["python3", "-u", "handler.py"]