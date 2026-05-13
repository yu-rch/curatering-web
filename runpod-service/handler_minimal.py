import runpod
import base64
from io import BytesIO
import os
import requests
from supabase import create_client
import random

# ---------------------------
# SUPABASE CONFIG
# ---------------------------
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError("SUPABASE_URL and SUPABASE_KEY environment variables are required")

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# ---------------------------
# PROMPT ENGINE
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
# MOCK IMAGE GENERATION
# ---------------------------
def generate(prompt):
    print("Generating mock image for:", prompt)
    
    # Create a simple mock image using requests
    try:
        # Generate a simple colored image using an online service or create local
        from PIL import Image
        import numpy as np
        
        # Create a simple test image (512x512)
        img_array = np.random.randint(0, 255, (512, 512, 3), dtype=np.uint8)
        image = Image.fromarray(img_array)
        
        buffer = BytesIO()
        image.save(buffer, format="PNG")
        
        return buffer.getvalue()
    except Exception as e:
        print("Error generating mock image:", e)
        # Return a simple 1x1 pixel as fallback
        return b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00sRGB\x00\xae\xce\x1c\xe9\x00\x00\x00\x00pHYs\x00\x00\x0b\x13\x00\x00\x00\x09p\x08\x00\x00\x00\x09\x1c\x1c\x1c\x9c\x18\x00\x00\x00\x1cIDATx\x9cc\xf8\x0f\x00\x00\x01\x00\x01'

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
        filename = f"{user_id}_{random.randint(0,999999)}.png"
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
print("Starting minimal RunPod serverless handler...")
runpod.serverless.start({"handler": handler})
