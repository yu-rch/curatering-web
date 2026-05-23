import base64
import os
import random
import traceback
import uuid
from io import BytesIO

import requests
import runpod
import torch
from diffusers import (
    ControlNetModel,
    StableDiffusionXLControlNetImg2ImgPipeline,
)
from controlnet_aux import CannyDetector
from PIL import Image
from supabase import create_client


# =========================================================
# CONFIG
# =========================================================
BUCKET_ID = "ai-images"
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY/SUPABASE_KEY")

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

DEVICE = "cuda"
HF_CACHE = os.getenv("HF_HOME", "/app/huggingface")
SD_IMAGE_SIZE = int(os.getenv("SD_IMAGE_SIZE", "1024"))
MAX_INIT_IMAGE_BYTES = int(os.getenv("MAX_INIT_IMAGE_BYTES", "6000000"))
DEFAULT_STRENGTH = float(os.getenv("SD_IMG2IMG_STRENGTH", "0.35"))
DEFAULT_GUIDANCE = float(os.getenv("SD_GUIDANCE_SCALE", "6.5"))

print("====================================")
print("DEVICE:", DEVICE)
print("GPU:", torch.cuda.get_device_name(0))
print("CUDA:", torch.version.cuda)
print("====================================")


# =========================================================
# LOAD CONTROLNET + SDXL
# =========================================================
print("Loading ControlNet...")
controlnet = ControlNetModel.from_pretrained(
    "diffusers/controlnet-canny-sdxl-1.0",
    torch_dtype=torch.float16,
)

print("Loading SDXL ControlNet img2img pipeline...")
pipe = StableDiffusionXLControlNetImg2ImgPipeline.from_pretrained(
    "stabilityai/stable-diffusion-xl-base-1.0",
    controlnet=controlnet,
    torch_dtype=torch.float16,
    variant="fp16",
    use_safetensors=True,
)
pipe.to("cuda")
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

print("SDXL ControlNet Canny Loaded")


# =========================================================
# PROMPT EXPANSION FALLBACKS
# =========================================================
THEME_MAP = {
    "cinderella": [
        "luxury fairytale princess ballroom",
        "royal blue drapery",
        "blue and silver palette",
        "crystal chandeliers",
        "glass slipper centerpiece",
        "magical glowing lighting",
        "elegant royal decor",
    ],
    "harry potter": [
        "floating candles",
        "dark gothic banquet hall",
        "dark academia banquet hall",
        "castle-inspired styling",
        "warm magical lighting",
        "magical gothic atmosphere",
    ],
    "garden": [
        "lush floral styling",
        "romantic greenery",
        "soft natural lighting",
        "elegant botanical decor",
    ],
}

NEGATIVE_PROMPT = (
    "warped architecture, distorted room, melted surfaces, duplicate objects, "
    "blurry, low quality, cartoon, CGI, fisheye, deformed ceiling, crooked walls, "
    "bad perspective, text, logo, watermark"
)

canny = CannyDetector()


# =========================================================
# DIAGNOSTICS
# =========================================================
def _storage_headers():
    return {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
    }


def _preview(text, limit=800):
    text = str(text or "").strip()
    return text if len(text) <= limit else text[:limit] + "..."


def diagnose_supabase_rest():
    base = SUPABASE_URL.rstrip("/")
    out = {"supabase_url_host": base.split("//", 1)[-1].split("/")[0]}
    try:
        r = requests.get(
            f"{base}/storage/v1/bucket",
            headers=_storage_headers(),
            timeout=45,
        )
        out["storage_list_buckets"] = {
            "ok": r.ok,
            "status_code": r.status_code,
            "body_preview": _preview(r.text),
        }
        if r.ok:
            buckets = r.json()
            names = [b.get("id") for b in buckets if isinstance(b, dict)]
            out["bucket_ids"] = names
            out["bucket_ai_images_present"] = BUCKET_ID in names
    except Exception as e:
        out["storage_list_buckets"] = {"ok": False, "error": repr(e)}
    return out


def diagnose_db_rest():
    base = SUPABASE_URL.rstrip("/")
    try:
        r = requests.get(
            f"{base}/rest/v1/ai_generations?select=id&limit=1",
            headers={**_storage_headers(), "Accept": "application/json"},
            timeout=45,
        )
        return {
            "ai_generations_head_ok": r.ok,
            "status_code": r.status_code,
            "body_preview": _preview(r.text),
        }
    except Exception as e:
        return {"ok": False, "error": repr(e)}


def format_exception_detail(exc):
    detail = {
        "type": type(exc).__name__,
        "str": str(exc),
        "repr": repr(exc),
    }
    for attr in ("code", "message", "details", "hint", "status_code"):
        if hasattr(exc, attr):
            try:
                detail[attr] = getattr(exc, attr)
            except Exception:
                pass
    return detail


# =========================================================
# PROMPT BUILDER
# =========================================================
def _clean_field(value):
    if value is None:
        return ""
    if isinstance(value, (list, tuple)):
        return ", ".join(str(v).strip() for v in value if str(v).strip())
    return str(value).strip()


def _list_field(value):
    if isinstance(value, (list, tuple)):
        return [str(v).strip() for v in value if str(v).strip()]
    text = _clean_field(value)
    return [part.strip() for part in text.split(",") if part.strip()] if text else []


def _dedupe(parts, limit=24):
    out = []
    seen = set()
    for part in parts:
        text = str(part or "").strip()
        key = text.lower()
        if not text or key in seen:
            continue
        seen.add(key)
        out.append(text)
        if len(out) >= limit:
            break
    return out


def _theme_tokens(data):
    lookup = " ".join(
        [
            _clean_field(data.get("theme")),
            _clean_field(data.get("style")),
            _clean_field(data.get("prompt")),
            _clean_field(data.get("positive_prompt")),
        ]
    ).lower()
    tokens = []
    for key, values in THEME_MAP.items():
        if key in lookup:
            tokens.extend(values)
    return tokens


def build_prompt(data):
    positive = _clean_field(data.get("positive_prompt"))
    prompt = positive or _clean_field(data.get("prompt"))

    token_parts = []
    for key in (
        "theme_tokens",
        "visual_direction",
        "visual_keywords",
        "style_tokens",
        "lighting_tokens",
        "decor_tokens",
        "decor_elements",
    ):
        token_parts.extend(_list_field(data.get(key)))

    event_type = _clean_field(data.get("event_type"))
    theme = _clean_field(data.get("theme") or data.get("style"))
    mood = _clean_field(data.get("mood"))
    notes = _clean_field(data.get("notes") or data.get("custom_instructions"))
    colors = _list_field(data.get("colors") or data.get("color_palette"))
    decor = _list_field(data.get("decor") or data.get("decor_elements"))

    structured_parts = [
        f"{event_type} event venue" if event_type else "",
        f"{theme} inspired luxury event styling" if theme else "",
        f"{mood} atmosphere" if mood else "",
        f"{', '.join(colors)} color palette" if colors else "",
        f"{', '.join(decor)} decorations" if decor else "",
        notes,
    ]

    parts = _dedupe(
        [prompt]
        + token_parts
        + structured_parts
        + _theme_tokens(data)
        + [
            "photorealistic event styling",
            "realistic premium venue styling",
            "luxury interior photography",
            "cinematic lighting",
            "ultra detailed",
        ],
        28,
    )

    return ", ".join(parts)


def build_negative_prompt(data):
    prompt = _clean_field(data.get("negative_prompt"))
    tokens = _list_field(data.get("negative_tokens"))
    return ", ".join(_dedupe([prompt] + tokens + [NEGATIVE_PROMPT], 16))


# =========================================================
# IMAGE LOADING + CONTROL IMAGE
# =========================================================
def _resize_for_sdxl(image):
    img = image.convert("RGB").copy()
    img.thumbnail((SD_IMAGE_SIZE, SD_IMAGE_SIZE), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (SD_IMAGE_SIZE, SD_IMAGE_SIZE), (32, 32, 32))
    canvas.paste(img, ((SD_IMAGE_SIZE - img.width) // 2, (SD_IMAGE_SIZE - img.height) // 2))
    return canvas


def load_image_from_url(url):
    response = requests.get(url, timeout=90)
    if response.status_code != 200:
        raise Exception(f"Failed to download base image ({response.status_code})")
    return Image.open(BytesIO(response.content)).convert("RGB")


def load_image_from_base64(raw):
    s = str(raw or "").strip()
    if not s:
        return None
    if s.startswith("data:"):
        s = s.split(",", 1)[-1]
    image_bytes = base64.b64decode(s, validate=False)
    if len(image_bytes) > MAX_INIT_IMAGE_BYTES:
        raise ValueError(
            f"Init image too large ({len(image_bytes)} bytes; max {MAX_INIT_IMAGE_BYTES})"
        )
    return Image.open(BytesIO(image_bytes)).convert("RGB")


def load_base_image(data):
    base_image_url = _clean_field(data.get("base_image") or data.get("base_image_url"))
    if base_image_url:
        if base_image_url.startswith("data:"):
            return load_image_from_base64(base_image_url)
        return load_image_from_url(base_image_url)

    raw_b64 = (
        data.get("init_image_base64")
        or data.get("image_base64")
        or data.get("venue_image_base64")
        or data.get("venuePhotoBase64")
    )
    return load_image_from_base64(raw_b64)


def generate_control_image(image):
    return canny(
        image,
        detect_resolution=1024,
        image_resolution=1024,
    )


# =========================================================
# SDXL GENERATION
# =========================================================
def _clamp_float(value, default, lo, hi):
    try:
        n = float(value)
    except Exception:
        n = default
    return max(lo, min(n, hi))


def _clamp_int(value, default, lo, hi):
    try:
        n = int(value)
    except Exception:
        n = default
    return max(lo, min(n, hi))


def generate_event_design(base_image, prompt, negative_prompt, data):
    base_image = _resize_for_sdxl(base_image)
    control_image = generate_control_image(base_image)
    strength = _clamp_float(data.get("strength"), DEFAULT_STRENGTH, 0.30, 0.42)
    guidance = _clamp_float(data.get("guidance_scale"), DEFAULT_GUIDANCE, 6.0, 7.0)
    steps = 30
    controlnet = data.get("controlnet") if isinstance(data.get("controlnet"), dict) else {}
    conditioning_scale = _clamp_float(
        controlnet.get("conditioning_scale", 0.8),
        0.8,
        0.1,
        1.5,
    )

    print(
        f"Generating SDXL ControlNet img2img "
        f"(strength={strength}, guidance={guidance}, steps={steps}, control={conditioning_scale})"
    )
    result = pipe(
        prompt=prompt,
        negative_prompt=negative_prompt,
        image=base_image,
        control_image=control_image,
        strength=strength,
        guidance_scale=guidance,
        num_inference_steps=steps,
        controlnet_conditioning_scale=conditioning_scale,
    )
    return result.images[0]


# =========================================================
# SUPABASE STORAGE + DB
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
        return public_url.get("publicUrl") or public_url.get("public_url") or ""
    return public_url


def _is_valid_uuid(value):
    try:
        uuid.UUID(str(value).strip())
        return True
    except Exception:
        return False


def _storage_file_prefix(user_id):
    s = str(user_id or "").strip()
    if _is_valid_uuid(s):
        return s
    return f"guest_{uuid.uuid4().hex[:12]}"


def save_generation(data):
    supabase.table("ai_generations").insert(data).execute()


# =========================================================
# HANDLER
# =========================================================
def handler(event):
    data = (event or {}).get("input") or {}

    if data.get("diagnose_only") or data.get("health_check"):
        return {
            "status": "success",
            "mode": "diagnostics",
            "bucket_expected": BUCKET_ID,
            "diagnostics": {
                "rest_storage": diagnose_supabase_rest(),
                "rest_db": diagnose_db_rest(),
            },
        }

    step = "init"
    try:
        step = "load_base_image"
        base_image = load_base_image(data)
        if base_image is None:
            return {
                "status": "error",
                "message": "base_image or init_image_base64 is required",
                "step": step,
            }

        print(f"Base image loaded: {base_image.width}x{base_image.height}px")

        step = "build_prompt"
        prompt = build_prompt(data)
        negative_prompt = build_negative_prompt(data)
        print("PROMPT:", prompt[:500])
        print("NEGATIVE:", negative_prompt[:300])

        step = "generate_image"
        generated_image = generate_event_design(
            base_image,
            prompt,
            negative_prompt,
            data,
        )

        step = "upload_storage"
        user_id = data.get("user_id", "anonymous")
        filename = f"{_storage_file_prefix(user_id)}_{random.randint(0, 999999)}.png"
        image_url = upload_image(generated_image, filename)

        step = "insert_db"
        record = {
            "prompt": prompt,
            "image_url": image_url,
        }
        for key in ("event_type", "style", "mood", "formality"):
            value = data.get(key)
            if value not in (None, ""):
                record[key] = value
        if _is_valid_uuid(user_id):
            record["user_id"] = str(user_id).strip()
        else:
            print(f"Skipping user_id in ai_generations (not a UUID): {user_id!r}")

        try:
            save_generation(record)
            db_saved = True
            db_warning = None
        except Exception as db_exc:
            print("DB insert failed; returning image URL anyway:", db_exc)
            db_saved = False
            db_warning = str(db_exc)

        return {
            "status": "success",
            "image_url": image_url,
            "prompt_used": prompt,
            "negative_prompt_used": negative_prompt,
            "generation_mode": "controlnet_img2img",
            "db_saved": db_saved,
            **({"db_warning": db_warning} if db_warning else {}),
        }

    except Exception as e:
        print("ERROR:", str(e))
        traceback.print_exc()
        return {
            "status": "error",
            "message": str(e),
            "step": step,
            "diagnostics": {
                "failed_step": step,
                "exception": format_exception_detail(e),
                "traceback": _preview(traceback.format_exc(), 2000),
                "rest_storage": diagnose_supabase_rest(),
                "rest_db": diagnose_db_rest(),
            },
        }


# =========================================================
# START
# =========================================================
print("Starting Event Design AI...")
runpod.serverless.start({"handler": handler})