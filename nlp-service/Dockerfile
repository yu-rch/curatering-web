FROM vllm/vllm-openai:latest

WORKDIR /app

# Install RunPod SDK separately (good isolation)
COPY app/requirements.txt /app/requirements.txt

RUN python3 -m pip install --no-cache-dir -r /app/requirements.txt

# Copy handler
COPY app/handler.py /app/handler.py

# Optional but useful for HF + caching stability
ENV HF_HOME=/app/huggingface
ENV TRANSFORMERS_CACHE=/app/huggingface

# Your model config
ENV NLP_MODEL_NAME=mistralai/Mistral-7B-Instruct-v0.2

# Better defaults for inference stability
ENV TOKENIZERS_PARALLELISM=false
ENV PYTHONUNBUFFERED=1

# RunPod requires direct handler execution
ENTRYPOINT []
CMD ["python3", "-u", "handler.py"]