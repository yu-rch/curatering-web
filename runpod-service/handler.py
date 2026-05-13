import runpod
import torch
import base64
import os
import requests
from io import BytesIO
from diffusers import StableDiffusionPipeline
from supabase import create_client

# ---------------------------
# SUPABASE CONFIG
# ---------------------------
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# ---------------------------
# DEVICE SETUP
# ---------------------------
device = "cuda" if torch.cuda.is_available() else "cpu"
print("Device:", device)

# ---------------------------
# LOAD MODEL ONCE (cold start optimized)
# ---------------------------
pipe = StableDiffusionPipeline.from_pretrained(
    "runwayml/stable-diffusion-v1-5",
    torch_dtype=torch.float16 if device == "cuda" else torch.float32,
)

pipe = pipe.to(device)

pipe.enable_attention_slicing()
pipe.enable_vae_slicing()

print("Model loaded")

# ---------------------------
# PROMPT ENGINE (IMPORTANT)
# ---------------------------
def build_prompt(data):
    base = data.get("prompt", "")

    event = data.get("event_type", "")
    theme = data.get("theme", "")
    formality = data.get("formality", "")

    enriched = f"""
    {base},
    event: {event},
    theme: {theme},
    formality: {formality},
    high quality, detailed, realistic lighting, professional composition
    """

    return enriched.strip()

# ---------------------------
# IMAGE GENERATION
# ---------------------------
def generate(prompt):
    image = pipe(prompt).images[0]

    buffer = BytesIO()
    image.save(buffer, format="PNG")

    return buffer.getvalue()

# ---------------------------
# SUPABASE UPLOAD
# ---------------------------
def upload_image(image_bytes, filename):
    supabase.storage.from_("ai-images").upload(
        path=filename,
        file=image_bytes,
        file_options={"content-type": "image/png"}
    )

    return supabase.storage.from_("ai-images").get_public_url(filename)

# ---------------------------
# DATABASE SAVE
# ---------------------------
def save_to_db(data):
    supabase.table("ai_generations").insert(data).execute()

# ---------------------------
# HANDLER
# ---------------------------
def handler(event):
    try:
        data = event["input"]

        prompt = build_prompt(data)
        user_id = data.get("user_id", "anonymous")

        print("Prompt:", prompt)

        # 1. generate image
        img_bytes = generate(prompt)

        # 2. upload
        filename = f"{user_id}_{torch.randint(0,999999,(1,)).item()}.png"
        url = upload_image(img_bytes, filename)

        # 3. save metadata
        record = {
            "user_id": user_id,
            "prompt": prompt,
            "image_url": url,
            "event_type": data.get("event_type"),
            "theme": data.get("theme"),
            "formality": data.get("formality"),
        }

        save_to_db(record)

        return {
            "status": "success",
            "image_url": url
        }

    except Exception as e:
        print("ERROR:", str(e))
        return {
            "status": "error",
            "message": str(e)
        }

# ---------------------------
# START SERVERLESS
# ---------------------------
runpod.serverless.start({"handler": handler})