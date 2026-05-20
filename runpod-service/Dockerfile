FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

WORKDIR /app

# system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-dev git ffmpeg libgl1 \
    && rm -rf /var/lib/apt/lists/*

# upgrade pip FIRST
RUN python3 -m pip install --no-cache-dir --upgrade pip

# force stable numpy FIRST (critical for torch/diffusers)
RUN python3 -m pip install --no-cache-dir numpy==1.26.4

# install requirements AFTER numpy is stable
COPY requirements.txt /app/requirements.txt
RUN python3 -m pip install --no-cache-dir -r /app/requirements.txt \
    && python3 -c "import runpod; print('runpod import OK')"

# SDXL downloads on first worker boot (HF_HOME). Baking weights in the image adds ~30+ min to builds.
ENV HF_HOME=/app/huggingface
ENV SD_MODEL_ID=stabilityai/stable-diffusion-xl-base-1.0
ENV SD_IMAGE_SIZE=1024

# copy handler
COPY handler_minimal.py handler.py

# Runtime: inject SUPABASE_URL and SUPABASE_KEY through RunPod secrets (do not bake into the image).
CMD ["python3", "-u", "handler.py"]