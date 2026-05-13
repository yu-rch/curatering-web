FROM runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel

WORKDIR /app

# Set HuggingFace cache environment variables
ENV HF_HOME=/app/huggingface
ENV TRANSFORMERS_CACHE=/app/huggingface

# system deps (optimized)
RUN sed -i 's/archive.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list && \
    apt-get update -o Acquire::Retries=3 && \
    apt-get install -y --no-install-recommends \
        git \
        ffmpeg \
        libgl1 \
    && rm -rf /var/lib/apt/lists/*

# install python deps FIRST (for caching)
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir "numpy<2.0" \
 && pip install --no-cache-dir -r requirements.txt

# copy code
COPY . .

# start RunPod serverless
CMD ["python", "-u", "handler.py"]
