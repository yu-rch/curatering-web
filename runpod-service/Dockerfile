FROM runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel

WORKDIR /app

# system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# upgrade pip FIRST
RUN python3 -m pip install --no-cache-dir --upgrade pip

# force stable numpy FIRST (critical for torch/diffusers)
RUN python3 -m pip install --no-cache-dir numpy==1.26.4

# Torch/CUDA comes from the base image. Install app requirements after numpy is stable.
COPY requirements.txt /app/requirements.txt
RUN python3 -m pip install --no-cache-dir -r /app/requirements.txt \
    && python3 -c "import runpod; import torch; print('runpod import OK'); print('torch', torch.__version__, 'cuda', torch.version.cuda); print('torch arch list', torch.cuda.get_arch_list())"

# SD 1.5 downloads on first worker boot (HF_HOME). Baking weights in the image adds long build time.
ENV HF_HOME=/app/huggingface
ENV SD_MODEL_ID=runwayml/stable-diffusion-v1-5
ENV SD_CONTROLNET_MODEL_ID=lllyasviel/control_v11p_sd15_canny
ENV SD_IMAGE_SIZE=768

# copy primary event-design handler
COPY prompt_engine.py prompt_engine.py
COPY handler.py handler.py

# Runtime: inject SUPABASE_URL and SUPABASE_KEY through RunPod secrets (do not bake into the image).
CMD ["python3", "-u", "handler.py"]