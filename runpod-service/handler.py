import runpod
import base64
from io import BytesIO
from diffusers import StableDiffusionPipeline
import torch
import os
from supabase import create_client
import random
import torch

# -------------------------
# CONFIG
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
MODEL_DIR = "/app/huggingface"

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError("SUPABASE_URL and SUPABASE_KEY environment variables are required")

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# -------------------------
# Prevent any weird device detection
if not torch.cuda.is_available():
    print("⚠️ CUDA not available, using CPU")

# -------------------------
# LOAD MODEL
print("Loading Stable Diffusion model...")

device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Using device: {device}")

pipe = StableDiffusionPipeline.from_pretrained(
    "runwayml/stable-diffusion-v1-5",
    cache_dir=MODEL_DIR,
    torch_dtype=torch.float16
)

pipe = pipe.to(device)
pipe.enable_attention_slicing()
pipe.enable_vae_slicing()

# Optional but recommended
if device == "cuda":
    try:
        pipe.enable_xformers_memory_efficient_attention()
        print("xformers enabled")
    except Exception as e:
        print("xformers not available:", e)

print("Model loaded successfully!")
# -------------------------
# IMAGE GENERATION
def generate_image(prompt):
    image = pipe(prompt).images[0]
    
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    
    return buffer.getvalue()

# -------------------------
# UPLOAD TO SUPABASE
def upload_to_supabase(image_bytes, filename):
    try:
        supabase.storage.from_("ai-images").upload(
            path=filename,
            file=image_bytes,
            file_options={"content-type": "image/png"}
        )

        public_url = supabase.storage.from_("ai-images").get_public_url(filename)
        return public_url
    except Exception as e:
        print(f"Error uploading to Supabase: {e}")
        raise

# -------------------------
# HANDLER
def handler(event):
    try:
        input_data = event.get("input", {})
        prompt = input_data.get("prompt")
        user_id = input_data.get("user_id")
        event_type = input_data.get("event_type", "")
        theme = input_data.get("theme", "")
        formality = input_data.get("formality", "")
        base_image = input_data.get("base_image", "")
        objects = input_data.get("objects", [])
        options = input_data.get("options", {})

        if not prompt:
            return {"error": "Prompt is required"}

        # 1. Generate image
        print(f"Generating image for prompt: {prompt}")
        image_bytes = generate_image(prompt)

        # 2. Upload to Supabase
        filename = f"{user_id}_{random.randint(0,100000)}.png"
        image_url = upload_to_supabase(image_bytes, filename)

        # 3. Save metadata
        metadata = {
            "user_id": user_id,
            "prompt": prompt,
            "image_url": image_url,
            "event_type": event_type,
            "theme": theme,
            "formality": formality,
            "base_image": base_image,
            "objects": objects,
            "options": options
        }
        
        supabase.table("ai_generations").insert(metadata).execute()

        print(f"Successfully generated and uploaded image: {image_url}")
        return {
            "status": "success",
            "image_url": image_url,
            "metadata": metadata
        }

    except Exception as e:
        print(f"Error in handler: {e}")
        return {"status": "error", "message": str(e)}

print("Starting RunPod serverless handler...")
runpod.serverless.start({"handler": handler})