FROM vllm/vllm-openai:v0.5.4

WORKDIR /app

RUN pip install --no-cache-dir \
    runpod==1.7.1 \
    supabase==2.5.0 \
    gotrue==2.9.0 \
    postgrest==0.16.11 \
    realtime==1.0.6 \
    httpx==0.27.2 \
    requests==2.31.0

COPY . /app

ENV PYTHONUNBUFFERED=1
ENV CUDA_MODULE_LOADING=LAZY
ENV TOKENIZERS_PARALLELISM=false
ENV VLLM_WORKER_MULTIPROC_METHOD=spawn
ENV VLLM_LOGGING_LEVEL=ERROR

ENTRYPOINT []

CMD ["python3", "-u", "app/handler.py"]