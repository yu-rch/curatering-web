# Production SDXL Event Design Handler (Upgraded)

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
    AutoencoderKL,
    ControlNetModel,
    DPMSolverMultistepScheduler,
    StableDiffusionXLControlNetImg2ImgPipeline,
    StableDiffusionXLImg2ImgPipeline,
)
from diffusers.pipelines.controlnet.multicontrolnet import MultiControlNetModel

from controlnet_aux import CannyDetector


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

SDXL_MODEL_ID = os.getenv(
    "SDXL_MODEL_ID",
    "stabilityai/stable-diffusion-xl-base-1.0"
)

SDXL_REFINER_ID = os.getenv(
    "SDXL_REFINER_ID",
    "stabilityai/stable-diffusion-xl-refiner-1.0"
)

IMAGE_SIZE = int(os.getenv("SD_IMAGE_SIZE", "1024"))
MAX_IMAGE_BYTES = int(os.getenv("MAX_INIT_IMAGE_BYTES", "6000000"))

DEFAULT_STRENGTH = float(os.getenv("SD_IMG2IMG_STRENGTH", "0.58"))
DEFAULT_GUIDANCE = float(os.getenv("SD_GUIDANCE_SCALE", "6.5"))
DEFAULT_CONTROL_SCALE = float(
    os.getenv("SD_CONTROLNET_CONDITIONING_SCALE", "0.7")
)

ENABLE_REFINER = os.getenv("ENABLE_REFINER", "true").lower() == "true"
ENABLE_IP_ADAPTER = os.getenv("ENABLE_IP_ADAPTER", "false").lower() == "true"


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
print("Loading ControlNet models...")

canny_controlnet = ControlNetModel.from_pretrained(
    "diffusers/controlnet-canny-sdxl-1.0",
    torch_dtype=DTYPE,
)

depth_controlnet = ControlNetModel.from_pretrained(
    "diffusers/controlnet-depth-sdxl-1.0",
    torch_dtype=DTYPE,
)

controlnet = MultiControlNetModel([
    canny_controlnet,
    depth_controlnet,
])


# =========================================================
# LOAD SDXL PIPELINE
# =========================================================
print("Loading SDXL pipeline...")

vae = AutoencoderKL.from_pretrained(
    "madebyollin/sdxl-vae-fp16-fix",
    torch_dtype=DTYPE,
)

pipe = StableDiffusionXLControlNetImg2ImgPipeline.from_pretrained(
    SDXL_MODEL_ID,
    controlnet=controlnet,
    vae=vae,
    torch_dtype=DTYPE,
    variant="fp16",
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
# OPTIONAL SDXL REFINER
# =========================================================
refiner = None

if ENABLE_REFINER:
    try:
        print("Loading SDXL refiner...")

        refiner = StableDiffusionXLImg2ImgPipeline.from_pretrained(
            SDXL_REFINER_ID,
            vae=vae,
            torch_dtype=DTYPE,
            variant="fp16",
            use_safetensors=True,
        )

        refiner.scheduler = DPMSolverMultistepScheduler.from_config(
            refiner.scheduler.config
        )

        refiner.to(DEVICE)

        try:
            refiner.enable_xformers_memory_efficient_attention()
        except Exception:
            pass

        print("Refiner loaded")

    except Exception as e:
        print("Refiner failed:", e)
        refiner = None


# =========================================================
# OPTIONAL IP-ADAPTER
# =========================================================
if ENABLE_IP_ADAPTER:
    try:
        print("Loading IP Adapter...")

        pipe.load_ip_adapter(
            "h94/IP-Adapter",
            subfolder="sdxl_models",
            weight_name="ip-adapter_sdxl.bin"
        )

        print("IP Adapter loaded")

    except Exception as e:
        print("IP Adapter failed:", e)


# =========================================================
# DETECTORS
# =========================================================
canny_detector = CannyDetector()


# =========================================================
# THEME MAP
# =========================================================
THEME_MAP = {
    "cinderella": [
        "(luxury fairytale ballroom:1.4)",
        "(royal blue drapery:1.3)",
        "(glass slipper centerpiece:1.5)",
        "(crystal chandeliers:1.3)",
        "(magical elegant lighting:1.2)",
    ],

    "harry potter": [
        "(floating candles:1.4)",
        "(gothic banquet hall:1.3)",
        "(warm magical candlelight:1.3)",
        "(castle-inspired decor:1.2)",
    ],

    "garden": [
        "(lush floral styling:1.4)",
        "(romantic greenery:1.3)",
        "(soft natural lighting:1.2)",
    ],
}


# =========================================================
# NEGATIVE PROMPTS
# =========================================================
GEOMETRY_NEGATIVE = [
    "warped architecture",
    "distorted room",
    "crooked walls",
    "fisheye",
    "bad perspective",
    "warped ceiling",
    "melted surfaces",
]

STYLE_NEGATIVE = [
    "cartoon",
    "anime",
    "cgi",
    "illustration",
]

ARTIFACT_NEGATIVE = [
    "duplicate objects",
    "floating decor",
    "blurry",
    "low quality",
    "watermark",
    "logo",
    "text",
]


# =========================================================
# HELPERS
# =========================================================
def clean(value):
    if value is None:
        return ""

    if isinstance(value, list):
        return ", ".join([str(v).strip() for v in value if str(v).strip()])

    return str(value).strip()



def as_list(value):
    if isinstance(value, list):
        return [str(v).strip() for v in value if str(v).strip()]

    text = clean(value)

    if not text:
        return []

    return [x.strip() for x in text.split(",") if x.strip()]



def dedupe(items, limit=32):
    out = []
    seen = set()

    for item in items:
        text = str(item or "").strip()

        if not text:
            continue

        key = text.lower()

        if key in seen:
            continue

        seen.add(key)
        out.append(text)

        if len(out) >= limit:
            break

    return out


# =========================================================
# PROMPT BUILDER
# =========================================================
def theme_tokens(data):
    lookup = " ".join([
        clean(data.get("theme")),
        clean(data.get("style")),
        clean(data.get("prompt")),
    ]).lower()

    tokens = []

    for key, values in THEME_MAP.items():
        if key in lookup:
            tokens.extend(values)

    return dedupe(tokens)



def build_prompt(data):
    prompt = clean(data.get("positive_prompt") or data.get("prompt"))

    event_type = clean(data.get("event_type"))
    mood = clean(data.get("mood"))
    formality = clean(data.get("formality"))

    colors = as_list(data.get("color_palette") or data.get("colors"))
    decor = as_list(data.get("decor_elements") or data.get("decor"))
    semantic_theme = as_list(data.get("theme_tokens"))
    semantic_style = as_list(data.get("style_tokens"))
    semantic_lighting = as_list(data.get("lighting_tokens"))
    semantic_decor = as_list(data.get("decor_tokens"))

    notes = clean(
        data.get("custom_instructions")
        or data.get("notes")
    )

    weighted_parts = [
        prompt,

        f"({event_type} luxury event venue:1.2)" if event_type else "",
        f"({mood} atmosphere:1.2)" if mood else "",
        f"({formality} styling:1.1)" if formality else "",

        f"({', '.join(colors)} color palette:1.3)" if colors else "",
        f"({', '.join(decor)} decorations:1.2)" if decor else "",
        f"({', '.join(semantic_theme)} theme details:1.2)" if semantic_theme else "",
        f"({', '.join(semantic_style)} style details:1.15)" if semantic_style else "",
        f"({', '.join(semantic_lighting)} lighting:1.2)" if semantic_lighting else "",
        f"({', '.join(semantic_decor)} decor details:1.15)" if semantic_decor else "",

        "(photorealistic event styling:1.4)",
        "(luxury interior photography:1.3)",
        "(cinematic lighting:1.2)",
        "(ultra detailed:1.2)",

        "(center focal centerpiece:1.4)",
        "(symmetrical venue layout:1.2)",

        notes,
    ]

    weighted_parts.extend(theme_tokens(data))

    return ", ".join(dedupe(weighted_parts, 24))



def build_negative_prompt(data):
    extra = as_list(data.get("negative_tokens"))

    negatives = (
        GEOMETRY_NEGATIVE
        + STYLE_NEGATIVE
        + ARTIFACT_NEGATIVE
        + extra
    )

    return ", ".join(dedupe(negatives, 32))


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
        detect_resolution=1024,
        image_resolution=1024,
    )


# =========================================================
# GENERATION
# =========================================================
def generate_image(data, image, prompt, negative_prompt):
    image = resize_image(image)

    canny_image = generate_canny(image)

    control_images = [
        canny_image,
        image,
    ]

    strength = float(data.get("strength", DEFAULT_STRENGTH))
    guidance = float(data.get("guidance_scale", DEFAULT_GUIDANCE))

    control_scale = float(
        data.get(
            "controlnet_conditioning_scale",
            DEFAULT_CONTROL_SCALE,
        )
    )

    steps = int(data.get("steps", 35))

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
        control_image=control_images,
        num_inference_steps=steps,
        guidance_scale=guidance,
        strength=strength,
        controlnet_conditioning_scale=[
            control_scale,
            0.5,
        ],
        generator=generator,
    )

    generated = result.images[0]

    if refiner is not None:
        print("Running SDXL refiner...")

        refined = refiner(
            prompt=prompt,
            negative_prompt=negative_prompt,
            image=generated,
            strength=0.2,
            guidance_scale=5,
            num_inference_steps=15,
            generator=generator,
        ).images[0]

        return refined, seed

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

        prompt = build_prompt(data)
        negative_prompt = build_negative_prompt(data)

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
            "generation_mode": "sdxl_controlnet_multi",
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
            "generation_mode": "production_sdxl_controlnet",
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