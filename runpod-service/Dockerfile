FROM runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel

WORKDIR /app

# system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg libgl1 \
    && rm -rf /var/lib/apt/lists/*

# IMPORTANT: prevent numpy 2.x breakage
RUN pip install --no-cache-dir numpy==1.26.4

COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "-u", "handler.py"]