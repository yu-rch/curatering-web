#!/usr/bin/env python3
"""Bake SD 1.5 weights into the Docker image for faster cold starts."""
import os
import sys

os.environ.setdefault("HF_HOME", "/app/huggingface")

try:
    from huggingface_hub import snapshot_download

    print("Downloading SD 1.5 weights into image cache...")
    model_dir = snapshot_download(
        repo_id=os.getenv("SD_MODEL_ID", "runwayml/stable-diffusion-v1-5"),
        cache_dir=os.environ["HF_HOME"],
    )
    print(f"Model cached at: {model_dir}")
except Exception as e:
    print(f"Error during preload: {e}")
    import traceback

    traceback.print_exc()
    sys.exit(1)
