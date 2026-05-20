import runpod
import threading
import torch
import os
import random
import traceback

import requests
from io import BytesIO
from diffusers import DPMSolverMultistepScheduler, StableDiffusionXLPipeline, StableDiffusionXLImg2ImgPipeline
from supabase import create_client

BUCKET_ID = "ai-images"

# ---------------------------
# SUPABASE CONFIG
# ---------------------------
# Set SUPABASE_URL and SUPABASE_KEY via RunPod (endpoint Secrets / Environment).
# SUPABASE_KEY must be the service role key — treat it as a secret; never commit it.
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError(
        "Missing SUPABASE_URL or SUPABASE_KEY. Configure both in RunPod endpoint secrets."
    )

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

print("SUPABASE_URL configured:", bool(SUPABASE_URL))
print("SUPABASE_KEY configured:", bool(SUPABASE_KEY))


def _storage_headers():
    return {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
    }


def _preview(text: str, limit: int = 800) -> str:
    if not text:
        return ""
    text = text.strip()
    return text if len(text) <= limit else text[:limit] + "…"


def diagnose_supabase_rest() -> dict:
    base = SUPABASE_URL.rstrip("/")
    out = {"supabase_url_host": base.split("//", 1)[-1].split("/")[0]}
    url_list = f"{base}/storage/v1/bucket"
    try:
        r = requests.get(url_list, headers=_storage_headers(), timeout=45)
        out["storage_list_buckets"] = {
            "ok": r.ok,
            "status_code": r.status_code,
            "body_preview": _preview(r.text),
        }
        if r.ok:
            try:
                buckets = r.json()
                names = [b.get("id") for b in buckets if isinstance(b, dict)]
                out["bucket_ids"] = names
                out["bucket_ai_images_present"] = BUCKET_ID in names
            except Exception as e:
                out["bucket_ids_parse_error"] = str(e)
    except requests.RequestException as e:
        out["storage_list_buckets"] = {"ok": False, "error": repr(e)}

    url_bucket = f"{base}/storage/v1/bucket/{BUCKET_ID}"
    try:
        r2 = requests.get(url_bucket, headers=_storage_headers(), timeout=45)
        out["storage_get_bucket"] = {
            "bucket": BUCKET_ID,
            "ok": r2.ok,
            "status_code": r2.status_code,
            "body_preview": _preview(r2.text),
        }
    except requests.RequestException as e:
        out["storage_get_bucket"] = {"bucket": BUCKET_ID, "ok": False, "error": repr(e)}
    return out


def diagnose_db_rest() -> dict:
    base = SUPABASE_URL.rstrip("/")
    url = f"{base}/rest/v1/ai_generations?select=id&limit=1"
    try:
        r = requests.get(
            url,
            headers={
                **_storage_headers(),
                "Accept": "application/json",
                "Prefer": "count=exact",
            },
            timeout=45,
        )
        return {
            "ai_generations_head_ok": r.ok,
            "status_code": r.status_code,
            "body_preview": _preview(r.text),
        }
    except requests.RequestException as e:
        return {"ok": False, "error": repr(e)}


def format_exception_detail(exc: BaseException) -> dict:
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
    if hasattr(exc, "dict") and callable(exc.dict):
        try:
            detail["dict"] = exc.dict()
        except Exception:
            pass
    return detail


# ---------------------------
# STABLE DIFFUSION (lazy singleton — one load per worker process)
# ---------------------------
_sd_pipeline = None
_sd_pipeline_lock = threading.Lock()
MODEL_ID = os.getenv("SD_MODEL_ID", "stabilityai/stable-diffusion-xl-base-1.0")
HF_CACHE = os.getenv("HF_HOME", "/app/huggingface")
SD_IMAGE_SIZE = int(os.getenv("SD_IMAGE_SIZE", "1024"))
DEFAULT_INFERENCE_STEPS = int(os.getenv("DEFAULT_INFERENCE_STEPS", "28"))
GUIDANCE_SCALE = float(os.getenv("SD_GUIDANCE_SCALE", "7.0"))
NEGATIVE_PROMPT = os.getenv(
    "SD_NEGATIVE_PROMPT",
    "low quality, blurry, distorted, deformed, text, watermark, logo",
)


def get_sd_pipeline():
    global _sd_pipeline
    if _sd_pipeline is not None:
        return _sd_pipeline
    with _sd_pipeline_lock:
        if _sd_pipeline is not None:
            return _sd_pipeline
        print("Loading SDXL model:", MODEL_ID)
        device = "cuda" if torch.cuda.is_available() else "cpu"
        dtype = torch.float16 if device == "cuda" else torch.float32
        kwargs = {
            "torch_dtype": dtype,
            "cache_dir": HF_CACHE,
            "use_safetensors": True,
        }
        if device == "cuda" and os.getenv("SD_MODEL_VARIANT", "fp16"):
            kwargs["variant"] = os.getenv("SD_MODEL_VARIANT", "fp16")
        _sd_pipeline = StableDiffusionXLPipeline.from_pretrained(
            MODEL_ID,
            **kwargs,
        ).to(device)
        _sd_pipeline.scheduler = DPMSolverMultistepScheduler.from_config(
            _sd_pipeline.scheduler.config
        )
        _sd_pipeline.enable_attention_slicing()
        try:
            _sd_pipeline.enable_vae_slicing()
        except Exception:
            pass
        print("SDXL model loaded")
        return _sd_pipeline


# ---------------------------
# PROMPT ENGINE (IMPORTANT)
# ---------------------------
def build_prompt(data):
    base = data.get("prompt", "")

    event = data.get("event_type", "")
    theme = data.get("style") or data.get("theme", "")
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
    print("Generating image for:", prompt)

    pipe = get_sd_pipeline()
    image = pipe(
        prompt=prompt,
        width=SD_IMAGE_SIZE,
        height=SD_IMAGE_SIZE,
        num_inference_steps=DEFAULT_INFERENCE_STEPS,
        guidance_scale=GUIDANCE_SCALE,
        negative_prompt=NEGATIVE_PROMPT,
    ).images[0]

    buffer = BytesIO()
    image.save(buffer, format="PNG")
    buffer.seek(0)
    return buffer.getvalue()

# ---------------------------
# SUPABASE UPLOAD
# ---------------------------
def upload_to_supabase(image_bytes, filename):
    bucket = supabase.storage.from_(BUCKET_ID)
    # storage-py only treats bytes / BufferedReader / FileIO as in-memory; BytesIO
    # falls through to open(path) and raises TypeError.
    bucket.upload(
        path=filename,
        file=image_bytes,
        file_options={
            "content-type": "image/png",
            "upsert": "true",
        },
    )

    raw = bucket.get_public_url(filename)
    if isinstance(raw, dict):
        return raw.get("publicUrl") or raw.get("public_url") or ""
    return raw
# ---------------------------
# DATABASE SAVE
# ---------------------------
def save_to_db(data):
    supabase.table("ai_generations").insert(data).execute()

# ---------------------------
# HANDLER
# ---------------------------
def handler(event):
    inp = (event or {}).get("input") or {}

    if inp.get("diagnose_only") or inp.get("health_check"):
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
        data = inp

        prompt = build_prompt(data)
        user_id = data.get("user_id", "anonymous")

        print("Prompt:", prompt)

        step = "generate_image"
        img_bytes = generate(prompt)

        step = "upload_storage"
        filename = f"{user_id}_{random.randint(0, 999999)}.png"
        try:
            url = upload_to_supabase(img_bytes, filename)
        except Exception as upload_exc:
            return {
                "status": "error",
                "message": str(upload_exc),
                "step": step,
                "diagnostics": {
                    "failed_step": step,
                    "exception": format_exception_detail(upload_exc),
                    "rest_storage": diagnose_supabase_rest(),
                },
            }

        step = "insert_db"
        # Match public.ai_generations columns (PostgREST rejects unknown keys).
        user_prompt = (data.get("prompt") or "").strip()
        record = {
            "user_id": user_id,
            "prompt": user_prompt or prompt,
            "image_url": url,
        }

        try:
            save_to_db(record)
        except Exception as db_exc:
            return {
                "status": "error",
                "message": str(db_exc),
                "step": step,
                "diagnostics": {
                    "failed_step": step,
                    "exception": format_exception_detail(db_exc),
                    "image_uploaded": True,
                    "public_url": url,
                    "rest_db": diagnose_db_rest(),
                    "rest_storage": diagnose_supabase_rest(),
                },
            }

        return {"status": "success", "image_url": url}

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

# ---------------------------
# START SERVERLESS
# ---------------------------
runpod.serverless.start({"handler": handler})