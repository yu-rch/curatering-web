FROM pytorch/pytorch:2.3.0-cuda12.1-cudnn8-devel

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip

RUN pip install numpy==1.26.4

COPY app/requirements.txt ./requirements.txt

RUN pip install --no-cache-dir -r requirements.txt
RUN python -c "from transformers import AutoTokenizer; AutoTokenizer.from_pretrained('mistralai/Mistral-7B-Instruct-v0.2')"
RUN python -c "from huggingface_hub import snapshot_download; snapshot_download(repo_id='mistralai/Mistral-7B-Instruct-v0.2')"

COPY app/handler.py ./handler.py

ENV HF_HOME=/app/huggingface
ENV TRANSFORMERS_CACHE=/app/huggingface
ENV HUGGINGFACE_HUB_CACHE=/app/huggingface

CMD ["python", "-u", "handler.py"]