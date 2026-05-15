FROM runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel

WORKDIR /app

# system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg libgl1 \
    && rm -rf /var/lib/apt/lists/*

# upgrade pip FIRST
RUN pip install --no-cache-dir --upgrade pip

# force stable numpy FIRST (critical for torch/diffusers)
RUN pip install --no-cache-dir numpy==1.26.4

# install requirements AFTER numpy is stable
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt \
    && python -c "import runpod; print('runpod import OK')"

# Model downloads on first worker boot (HF_HOME). Baking weights in the image adds ~30+ min to builds.
ENV HF_HOME=/app/huggingface

# copy handler
COPY handler_minimal.py handler.py

# Runtime: inject SUPABASE_URL and SUPABASE_KEY through RunPod secrets (do not bake into the image).
CMD ["python", "-u", "handler.py"]