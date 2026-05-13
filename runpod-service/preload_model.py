#!/usr/bin/env python3
import os
import sys
from huggingface_hub import snapshot_download

# Set environment variables to avoid XPU issues
os.environ['DIFFUSERS_DISABLE_TELEX_METRICS'] = '1'
os.environ['CUDA_VISIBLE_DEVICES'] = '0'

try:
    print("Starting model preload...")
    
    # Download and cache the model files without importing the problematic pipeline
    print("Downloading Stable Diffusion model files...")
    model_dir = snapshot_download(
        repo_id="runwayml/stable-diffusion-v1-5",
        cache_dir="/app/huggingface",
        ignore_patterns=["*.bin", "*.safetensors"]  # Don't download large files during build
    )
    
    print(f"Model files cached to: {model_dir}")
    print("Model cache prepared successfully!")
    
except Exception as e:
    print(f"Error during preload: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
