FROM runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel

WORKDIR /app

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# system deps (optimized)
RUN sed -i 's/archive.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        ffmpeg \
        libgl1 \
    && rm -rf /var/lib/apt/lists/*

#retry
RUN apt-get update -o Acquire::Retries=3 && \
    apt-get install -y --no-install-recommends \
        git \
        ffmpeg \
        libgl1 \
    && rm -rf /var/lib/apt/lists/*

# install python deps FIRST (for caching)
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir -r requirements.txt

# copy rest of code
COPY . .

# ensure executable
RUN chmod +x start.sh

# kill any default jupyter behavior
ENV JUPYTER_ENABLE_LAB=no

EXPOSE 8888

CMD ["bash", "start.sh"]