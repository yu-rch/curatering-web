# pyright: reportMissingModuleSource=false, reportMissingImports=false, reportPrivateImportUsage=false, reportAttributeAccessIssue=false
# Production SD 1.5 Event Design Handler

import base64
import gc
import os
import random
import traceback
import uuid
from io import BytesIO

import requests
import runpod
import torch
from PIL import Image
from supabase import create_client

from diffusers import (
    ControlNetModel,
    DPMSolverMultistepScheduler,
    StableDiffusionControlNetImg2ImgPipeline,
)

from controlnet_aux import CannyDetector

from prompt_engine import (
    clean,
    compile_generation_payload,
    controlnet_scale_for_denoise,
)


# =========================================================
# CONFIG
# =========================================================
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
DTYPE = torch.float16 if DEVICE == "cuda" else torch.float32

BUCKET_ID = "ai-images"

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = (
    os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    or os.getenv("SUPABASE_KEY")
)

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError("Missing Supabase credentials")

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

HF_HOME = os.getenv("HF_HOME", "/app/huggingface")

SD_MODEL_ID = os.getenv(
    "SD_MODEL_ID",
    "runwayml/stable-diffusion-v1-5"
)

CONTROLNET_MODEL_ID = os.getenv(
    "SD_CONTROLNET_MODEL_ID",
    "lllyasviel/control_v11p_sd15_canny"
)

IMAGE_SIZE = int(os.getenv("SD_IMAGE_SIZE", "768"))
MAX_IMAGE_BYTES = int(os.getenv("MAX_INIT_IMAGE_BYTES", "6000000"))

DEFAULT_STRENGTH = float(os.getenv("SD_IMG2IMG_STRENGTH", "0.72"))
DEFAULT_GUIDANCE = float(os.getenv("SD_GUIDANCE_SCALE", "7"))
DEFAULT_CONTROL_SCALE = float(
    os.getenv("SD_CONTROLNET_CONDITIONING_SCALE", "0.55")
)


# =========================================================
# STARTUP LOGS
# =========================================================
print("====================================")
print("DEVICE:", DEVICE)
print("CUDA:", torch.version.cuda)
print("GPU:", torch.cuda.get_device_name(0) if DEVICE == "cuda" else "CPU")
print("====================================")


# =========================================================
# CONTROLNETS
# =========================================================
print("Loading SD 1.5 Canny ControlNet...")

controlnet = ControlNetModel.from_pretrained(
    CONTROLNET_MODEL_ID,
    torch_dtype=DTYPE,
)


# =========================================================
# LOAD SD 1.5 PIPELINE
# =========================================================
print("Loading SD 1.5 pipeline...")

pipe = StableDiffusionControlNetImg2ImgPipeline.from_pretrained(
    SD_MODEL_ID,
    controlnet=controlnet,
    torch_dtype=DTYPE,
    use_safetensors=True,
)

pipe.scheduler = DPMSolverMultistepScheduler.from_config(
    pipe.scheduler.config
)

pipe.to(DEVICE)

pipe.enable_attention_slicing()

try:
    pipe.enable_vae_slicing()
except Exception:
    pass

try:
    pipe.enable_xformers_memory_efficient_attention()
    print("xformers enabled")
except Exception as e:
    print("xformers unavailable:", e)


# =========================================================
# OPTIONAL TORCH COMPILE
# =========================================================
try:
    pipe.unet = torch.compile(pipe.unet)
    print("torch.compile enabled")
except Exception as e:
    print("torch.compile unavailable:", e)


# =========================================================
# DETECTORS
# =========================================================
canny_detector = CannyDetector()


# =========================================================
# IMAGE HELPERS
# =========================================================
def resize_image(image):
    image = image.convert("RGB")

    width, height = image.size

    scale = IMAGE_SIZE / max(width, height)

    new_width = int(width * scale)
    new_height = int(height * scale)

    image = image.resize(
        (new_width, new_height),
        Image.Resampling.LANCZOS,
    )

    canvas = Image.new("RGB", (IMAGE_SIZE, IMAGE_SIZE), (24, 24, 24))

    canvas.paste(
        image,
        (
            (IMAGE_SIZE - new_width) // 2,
            (IMAGE_SIZE - new_height) // 2,
        )
    )

    return canvas



def load_url_image(url):
    response = requests.get(url, timeout=90)

    if response.status_code != 200:
        raise Exception(f"Failed to download image ({response.status_code})")

    return Image.open(BytesIO(response.content)).convert("RGB")



def load_base64_image(raw):
    if not raw:
        return None

    s = str(raw).strip()

    if s.startswith("data:"):
        s = s.split(",", 1)[-1]

    image_bytes = base64.b64decode(s)

    if len(image_bytes) > MAX_IMAGE_BYTES:
        raise Exception("Image exceeds maximum size")

    return Image.open(BytesIO(image_bytes)).convert("RGB")



def load_base_image(data):
    base_url = clean(
        data.get("base_image")
        or data.get("base_image_url")
    )

    if base_url:
        if base_url.startswith("data:"):
            return load_base64_image(base_url)

        return load_url_image(base_url)

    return load_base64_image(
        data.get("image_base64")
        or data.get("venue_image_base64")
    )


# =========================================================
# CONTROL IMAGES
# =========================================================
def generate_canny(image):
    return canny_detector(
        image,
        detect_resolution=IMAGE_SIZE,
        image_resolution=IMAGE_SIZE,
    )


# =========================================================
# GENERATION
# =========================================================
def generate_image(data, image, prompt, negative_prompt):
    image = resize_image(image)

    canny_image = generate_canny(image)

    control_image = canny_image

    strength = max(0.5, min(float(data.get("strength", DEFAULT_STRENGTH)), 0.78))
    guidance = float(data.get("guidance_scale") or data.get("cfg_scale") or DEFAULT_GUIDANCE)

    controlnet_config = data.get("controlnet") if isinstance(data.get("controlnet"), dict) else {}
    control_scale = float(
        controlnet_config.get(
            "conditioning_scale",
            data.get("controlnet_conditioning_scale", controlnet_scale_for_denoise(strength)),
        )
    )
    control_scale = max(0.45, min(control_scale, 0.85))

    steps = int(data.get("num_inference_steps") or data.get("steps") or 35)
    steps = max(25, min(steps, 35))

    seed = int(data.get("seed", random.randint(1, 999999999)))

    generator = torch.Generator(device=DEVICE).manual_seed(seed)

    print("====================================")
    print("PROMPT:", prompt)
    print("NEGATIVE:", negative_prompt)
    print("SEED:", seed)
    print("====================================")

    result = pipe(
        prompt=prompt,
        negative_prompt=negative_prompt,
        image=image,
        control_image=control_image,
        num_inference_steps=steps,
        guidance_scale=guidance,
        strength=strength,
        controlnet_conditioning_scale=control_scale,
        generator=generator,
    )

    generated = result.images[0]

    return generated, seed


# =========================================================
# STORAGE
# =========================================================
def upload_image(image, filename):
    buffer = BytesIO()

    image.save(buffer, format="PNG")

    image_bytes = buffer.getvalue()

    bucket = supabase.storage.from_(BUCKET_ID)

    bucket.upload(
        path=filename,
        file=image_bytes,
        file_options={
            "content-type": "image/png",
            "upsert": "true",
        },
    )

    public_url = bucket.get_public_url(filename)

    if isinstance(public_url, dict):
        return public_url.get("publicUrl")

    return public_url


# =========================================================
# DATABASE
# =========================================================
def save_generation(record):
    supabase.table("ai_generations").insert(record).execute()


# =========================================================
# UUID
# =========================================================
def valid_uuid(value):
    try:
        uuid.UUID(str(value))
        return True
    except Exception:
        return False


# =========================================================
# MEMORY CLEANUP
# =========================================================
def cleanup_memory():
    gc.collect()

    if DEVICE == "cuda":
        torch.cuda.empty_cache()


# =========================================================
# HANDLER
# =========================================================
def handler(event):
    data = (event or {}).get("input") or {}

    try:
        base_image = load_base_image(data)

        if base_image is None:
            return {
                "status": "error",
                "message": "Base image required",
            }

        compiled = compile_generation_payload(data)
        data = {**data, **compiled}
        prompt = compiled["prompt"]
        negative_prompt = compiled["negative_prompt"]

        generated_image, seed = generate_image(
            data,
            base_image,
            prompt,
            negative_prompt,
        )

        user_id = str(data.get("user_id") or "guest")

        filename = (
            f"{uuid.uuid4().hex}_{random.randint(0,999999)}.png"
        )

        image_url = upload_image(generated_image, filename)

        record = {
            "prompt": prompt,
            "negative_prompt": negative_prompt,
            "image_url": image_url,
            "seed": seed,
            "generation_mode": "sd15_controlnet_canny",
            "design_meta": {
                "mode": compiled["mode"],
                "controlnet": compiled["controlnet"],
                "transformation_plan": compiled["transformation_plan"],
            },
            "event_type": clean(data.get("event_type")),
            "style": clean(data.get("style")),
            "mood": clean(data.get("mood")),
            "formality": clean(data.get("formality")),
        }

        if valid_uuid(user_id):
            record["user_id"] = user_id

        try:
            save_generation(record)
            db_saved = True
        except Exception as db_exc:
            print("DB save failed:", db_exc)
            db_saved = False

        cleanup_memory()

        return {
            "status": "success",
            "image_url": image_url,
            "prompt_used": prompt,
            "negative_prompt_used": negative_prompt,
            "seed": seed,
            "mode": compiled["mode"],
            "controlnet": compiled["controlnet"],
            "generation_mode": "production_sd15_controlnet",
            "db_saved": db_saved,
        }

    except Exception as e:
        traceback.print_exc()

        cleanup_memory()

        return {
            "status": "error",
            "message": str(e),
            "traceback": traceback.format_exc()[-3000:],
        }


# =========================================================
# START
# =========================================================
print("Starting Production Event Design AI...")

runpod.serverless.start({
    "handler": handler
})