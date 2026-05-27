# pyright: reportMissingModuleSource=false, reportMissingImports=false, reportPrivateImportUsage=false, reportAttributeAccessIssue=false, reportArgumentType=false, reportOptionalMemberAccess=false, reportAssignmentType=false
import runpod
import base64
import threading
import time
import torch
from io import BytesIO
import os
import json
import random
import traceback
import uuid
from typing import Optional, Tuple

import requests
from diffusers import (
    DPMSolverMultistepScheduler,
    StableDiffusionImg2ImgPipeline,
    StableDiffusionPipeline,
)
try:
    from diffusers import ControlNetModel, StableDiffusionControlNetImg2ImgPipeline
except Exception:
    ControlNetModel = None
    StableDiffusionControlNetImg2ImgPipeline = None
from PIL import Image, ImageFilter, ImageOps
from supabase import create_client

from prompt_engine import (
    compile_generation_payload,
    controlnet_scale_for_denoise,
)

BUCKET_ID = "ai-images"

# ---------------------------
# SUPABASE CONFIG
# ---------------------------
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
    """
    Hit Supabase Storage REST directly so failures can be labeled
    (network/DNS vs 401 vs 404 bucket vs 5xx Supabase).
    """
    base = SUPABASE_URL.rstrip("/")
    out = {"supabase_url_host": base.split("//", 1)[-1].split("/")[0]}

    # List buckets (requires service role or allowed anon — service role expected)
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

    # Single bucket metadata
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
    """Lightweight REST probe for PostgREST / table visibility."""
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
    """Best-effort parse for supabase / httpx style errors."""
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
    # dict-like message (your 500 looked like a stringified dict)
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
_sd_img2img_pipeline = None
_sd_controlnet_img2img_pipeline = None
_sd_pipeline_lock = threading.RLock()

MAX_INIT_IMAGE_BYTES = int(os.getenv("MAX_INIT_IMAGE_BYTES", "6000000"))
SD_IMAGE_SIZE = int(os.getenv("SD_IMAGE_SIZE", "768"))
DEFAULT_INFERENCE_STEPS = int(os.getenv("DEFAULT_INFERENCE_STEPS", "30"))
IMG2IMG_INFERENCE_STEPS = int(os.getenv("IMG2IMG_INFERENCE_STEPS", "30"))
GUIDANCE_SCALE = float(os.getenv("SD_GUIDANCE_SCALE", "7"))
MODEL_ID = os.getenv("SD_MODEL_ID", "runwayml/stable-diffusion-v1-5")
CONTROLNET_MODEL_ID = os.getenv(
    "SD_CONTROLNET_MODEL_ID", "lllyasviel/control_v11p_sd15_canny"
)
HF_CACHE = os.getenv("HF_HOME", "/app/huggingface")
NEGATIVE_PROMPT = os.getenv(
    "SD_NEGATIVE_PROMPT",
    "warped architecture, distorted room, melted surfaces, duplicate objects, blurry, low quality, cartoon, CGI, fisheye",
)


def _configure_pipeline(pipe):
    """Faster scheduler + memory tweaks so jobs finish under RunPod's execution cap."""
    pipe.scheduler = DPMSolverMultistepScheduler.from_config(pipe.scheduler.config)
    pipe.enable_attention_slicing()
    try:
        pipe.enable_vae_slicing()
    except Exception:
        pass
    try:
        pipe.enable_xformers_memory_efficient_attention()
    except Exception:
        pass
    return pipe


def get_sd_pipeline():
    global _sd_pipeline
    if _sd_pipeline is not None:
        return _sd_pipeline
    with _sd_pipeline_lock:
        if _sd_pipeline is not None:
            return _sd_pipeline
        t0 = time.time()
        print("Loading model:", MODEL_ID)
        device = "cuda" if torch.cuda.is_available() else "cpu"
        dtype = torch.float16 if device == "cuda" else torch.float32
        kwargs = {
            "torch_dtype": dtype,
            "cache_dir": HF_CACHE,
            "use_safetensors": True,
        }
        if device == "cuda" and os.getenv("SD_MODEL_VARIANT", "fp16"):
            kwargs["variant"] = os.getenv("SD_MODEL_VARIANT", "fp16")
        _sd_pipeline = StableDiffusionPipeline.from_pretrained(
            MODEL_ID,
            **kwargs,
        ).to(device)
        _configure_pipeline(_sd_pipeline)
        print(f"Model loaded in {time.time() - t0:.1f}s on {device}")
        return _sd_pipeline


def get_sd_img2img_pipeline():
    """Img2img pipeline shares weights with txt2img to save VRAM."""
    global _sd_img2img_pipeline
    if _sd_img2img_pipeline is not None:
        return _sd_img2img_pipeline
    with _sd_pipeline_lock:
        if _sd_img2img_pipeline is not None:
            return _sd_img2img_pipeline
        t0 = time.time()
        print("Building img2img pipeline from txt2img weights...")
        txt = get_sd_pipeline()
        _sd_img2img_pipeline = StableDiffusionImg2ImgPipeline(**txt.components)
        _configure_pipeline(_sd_img2img_pipeline)
        print(f"Img2img pipeline ready in {time.time() - t0:.1f}s")
        return _sd_img2img_pipeline


def get_sd_controlnet_img2img_pipeline():
    """ControlNet img2img pipeline for venue edge preservation."""
    global _sd_controlnet_img2img_pipeline
    if _sd_controlnet_img2img_pipeline is not None:
        return _sd_controlnet_img2img_pipeline
    if ControlNetModel is None or StableDiffusionControlNetImg2ImgPipeline is None:
        raise RuntimeError("ControlNet SD 1.5 pipeline is unavailable in this image")
    with _sd_pipeline_lock:
        if _sd_controlnet_img2img_pipeline is not None:
            return _sd_controlnet_img2img_pipeline
        t0 = time.time()
        txt = get_sd_pipeline()
        device = "cuda" if torch.cuda.is_available() else "cpu"
        dtype = torch.float16 if device == "cuda" else torch.float32
        print("Loading ControlNet model:", CONTROLNET_MODEL_ID)
        controlnet = ControlNetModel.from_pretrained(
            CONTROLNET_MODEL_ID,
            torch_dtype=dtype,
            cache_dir=HF_CACHE,
            use_safetensors=True,
        )
        _sd_controlnet_img2img_pipeline = StableDiffusionControlNetImg2ImgPipeline(
            **txt.components,
            controlnet=controlnet,
        ).to(device)
        _configure_pipeline(_sd_controlnet_img2img_pipeline)
        print(f"ControlNet img2img pipeline ready in {time.time() - t0:.1f}s")
        return _sd_controlnet_img2img_pipeline


def _decode_init_image(data) -> Optional[Image.Image]:
    """Decode optional venue/reference photo from base64 input fields."""
    raw = (
        data.get("init_image_base64")
        or data.get("image_base64")
        or data.get("venue_image_base64")
        or data.get("venuePhotoBase64")
    )
    if raw is None:
        return None
    s = str(raw).strip()
    if not s:
        return None
    if s.startswith("data:"):
        s = s.split(",", 1)[-1]
    try:
        img_bytes = base64.b64decode(s, validate=False)
    except Exception as exc:
        raise ValueError(f"Invalid init_image_base64: {exc}") from exc
    if len(img_bytes) > MAX_INIT_IMAGE_BYTES:
        raise ValueError(
            f"Init image too large ({len(img_bytes)} bytes; max {MAX_INIT_IMAGE_BYTES})"
        )
    try:
        img = Image.open(BytesIO(img_bytes)).convert("RGB")
    except Exception as exc:
        raise ValueError(f"Could not read init image: {exc}") from exc
    return img


def _resize_for_sd(img: Image.Image, size: int = SD_IMAGE_SIZE) -> Image.Image:
    """Fit inside size×size and center on a square canvas (SD expects multiples of 8)."""
    img = img.copy()
    img.thumbnail((size, size), Image.Resampling.LANCZOS)
    w, h = img.size
    if w == size and h == size:
        return img
    canvas = Image.new("RGB", (size, size), (32, 32, 32))
    canvas.paste(img, ((size - w) // 2, (size - h) // 2))
    return canvas


def _controlnet_enabled(config) -> bool:
    if not isinstance(config, dict):
        return False
    return config.get("enabled") is True


def _controlnet_condition_image(img: Image.Image) -> Image.Image:
    """Lightweight Canny-style edge map without adding OpenCV to the worker image."""
    edges = img.convert("L").filter(ImageFilter.FIND_EDGES)
    edges = ImageOps.autocontrast(edges)
    return edges.convert("RGB")


def _controlnet_conditioning_scale(config) -> float:
    if isinstance(config, dict) and "denoise_strength" in config:
        return controlnet_scale_for_denoise(float(config["denoise_strength"]))
    if not isinstance(config, dict):
        return 0.5
    try:
        scale = float(config.get("conditioning_scale", 0.5))
    except Exception:
        scale = 0.5
    return max(0.4, min(scale, 0.6))


# ---------------------------
# INPUT HELPERS
# ---------------------------
def _clean_field(value) -> str:
    if value is None:
        return ""
    if isinstance(value, (list, tuple)):
        return ", ".join(str(v).strip() for v in value if v is not None and str(v).strip())
    return str(value).strip()


# ---------------------------
# IMAGE GENERATION (txt2img + img2img)
# ---------------------------
def generate(
    prompt: str,
    *,
    init_image: Optional[Image.Image] = None,
    strength: float = 0.85,
    num_inference_steps: Optional[int] = None,
    guidance_scale: Optional[float] = None,
    negative_prompt: Optional[str] = None,
    controlnet: Optional[dict] = None,
) -> Tuple[bytes, str]:
    if init_image is not None:
        default_steps = IMG2IMG_INFERENCE_STEPS
        strength = max(0.75, min(float(strength), 0.9))
    else:
        default_steps = DEFAULT_INFERENCE_STEPS
    steps = num_inference_steps if num_inference_steps is not None else default_steps
    steps = max(25, min(int(steps), 35))
    guidance = GUIDANCE_SCALE
    if guidance_scale is not None:
        try:
            guidance = max(1.0, min(float(guidance_scale), 12.0))
        except Exception:
            guidance = GUIDANCE_SCALE
    neg = negative_prompt.strip() if isinstance(negative_prompt, str) and negative_prompt.strip() else NEGATIVE_PROMPT

    t0 = time.time()
    with torch.inference_mode():
        if init_image is not None:
            print(
                f"Img2img (strength={strength}, guidance={guidance}, steps={steps}, size={SD_IMAGE_SIZE}):",
                prompt[:200],
            )
            prepared = _resize_for_sd(init_image)
            dynamic_controlnet = controlnet_scale_for_denoise(strength)
            if _controlnet_enabled(controlnet):
                try:
                    pipe = get_sd_controlnet_img2img_pipeline()
                    control_image = _controlnet_condition_image(prepared)
                    controlnet_config = dict(controlnet or {})
                    controlnet_config["conditioning_scale"] = dynamic_controlnet
                    result = pipe(
                        prompt=prompt,
                        image=prepared,
                        control_image=control_image,
                        strength=strength,
                        num_inference_steps=steps,
                        guidance_scale=guidance,
                        negative_prompt=neg,
                        controlnet_conditioning_scale=_controlnet_conditioning_scale(controlnet_config),
                    )
                    mode = "controlnet_img2img"
                except Exception as exc:
                    print("ControlNet unavailable; falling back to SD 1.5 img2img:", exc)
                    pipe = get_sd_img2img_pipeline()
                    result = pipe(
                        prompt=prompt,
                        image=prepared,
                        strength=strength,
                        num_inference_steps=steps,
                        guidance_scale=guidance,
                        negative_prompt=neg,
                    )
                    mode = "img2img"
            else:
                pipe = get_sd_img2img_pipeline()
                result = pipe(
                    prompt=prompt,
                    image=prepared,
                    strength=strength,
                    num_inference_steps=steps,
                    guidance_scale=guidance,
                    negative_prompt=neg,
                )
                mode = "img2img"
        else:
            print(f"Txt2img (guidance={guidance}, steps={steps}, size={SD_IMAGE_SIZE}):", prompt[:200])
            pipe = get_sd_pipeline()
            result = pipe(
                prompt=prompt,
                width=SD_IMAGE_SIZE,
                height=SD_IMAGE_SIZE,
                num_inference_steps=steps,
                guidance_scale=guidance,
                negative_prompt=neg,
            )
            mode = "txt2img"

    print(f"Inference finished in {time.time() - t0:.1f}s ({mode})")
    image = result.images[0]
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    buffer.seek(0)
    return buffer.getvalue(), mode


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
def _is_valid_uuid(value) -> bool:
    try:
        uuid.UUID(str(value).strip())
        return True
    except (ValueError, AttributeError, TypeError):
        return False


def _storage_file_prefix(user_id: str) -> str:
    """Safe filename prefix (storage path is text; not the DB uuid column)."""
    s = str(user_id or "").strip()
    if _is_valid_uuid(s):
        return s
    return f"guest_{uuid.uuid4().hex[:12]}"


def save_to_db(data):
    supabase.table("ai_generations").insert(data).execute()


# ---------------------------
# HANDLER
# ---------------------------
def handler(event):
    inp = (event or {}).get("input") or {}

    if inp.get("diagnose_only") or inp.get("health_check"):
        diagnostics = {
            "rest_storage": diagnose_supabase_rest(),
            "rest_db": diagnose_db_rest(),
        }
        return {
            "status": "success",
            "mode": "diagnostics",
            "bucket_expected": BUCKET_ID,
            "diagnostics": diagnostics,
        }

    step = "init"
    diagnostics_on_error = {}

    try:
        data = inp

        compiled = compile_generation_payload(data)
        data = {**data, **compiled}
        prompt = compiled["prompt"]
        user_id = data.get("user_id", "anonymous")

        step = "decode_init_image"
        init_b64 = _clean_field(
            data.get("init_image_base64")
            or data.get("image_base64")
            or data.get("venue_image_base64")
            or data.get("venuePhotoBase64")
        )
        print(
            f"init_image_base64 in request: {bool(init_b64)} ({len(init_b64)} chars)"
        )
        init_image = _decode_init_image(data)
        if init_image is not None:
            print(f"Init image decoded: {init_image.width}x{init_image.height}px")
        else:
            print("No venue/init image — txt2img only")

        strength = data.get("strength", data.get("img2img_strength", 0.85))
        steps = data.get("num_inference_steps") or data.get("steps")
        if steps is None:
            steps = IMG2IMG_INFERENCE_STEPS if init_image is not None else DEFAULT_INFERENCE_STEPS
        guidance_scale = data.get("guidance_scale") or data.get("cfg_scale") or GUIDANCE_SCALE
        negative_prompt = data.get("negative_prompt", NEGATIVE_PROMPT)
        controlnet = data.get("controlnet")

        mode = "img2img" if init_image is not None else "txt2img"
        print(
            f"Prompt ({mode}, steps={steps}, strength={strength}, guidance={guidance_scale}, controlnet={_controlnet_enabled(controlnet)}):",
            prompt[:280],
        )

        step = "generate_image"
        img_bytes, generation_mode = generate(
            prompt,
            init_image=init_image,
            strength=strength,
            num_inference_steps=steps,
            guidance_scale=guidance_scale,
            negative_prompt=negative_prompt,
            controlnet=controlnet,
        )

        step = "upload_storage"
        file_prefix = _storage_file_prefix(user_id)
        filename = f"{file_prefix}_{random.randint(0, 999999)}.png"
        try:
            url = upload_to_supabase(img_bytes, filename)
        except Exception as upload_exc:
            diagnostics_on_error = {
                "failed_step": step,
                "exception": format_exception_detail(upload_exc),
                "rest_storage": diagnose_supabase_rest(),
            }
            return {
                "status": "error",
                "message": str(upload_exc),
                "step": step,
                "diagnostics": diagnostics_on_error,
            }

        step = "insert_db"
        record = {
            "prompt": prompt,
            "image_url": url,
            "negative_prompt": negative_prompt,
            "design_meta": {
                "mode": compiled["mode"],
                "controlnet": compiled["controlnet"],
                "transformation_plan": compiled["transformation_plan"],
            },
        }
        if _is_valid_uuid(user_id):
            record["user_id"] = str(user_id).strip()
        else:
            print(
                f"Skipping user_id in ai_generations (not a UUID): {user_id!r}"
            )

        try:
            save_to_db(record)
        except Exception as db_exc:
            print("DB insert failed; returning image URL anyway:", db_exc)
            return {
                "status": "success",
                "image_url": url,
                "generation_mode": generation_mode,
                "mode": compiled["mode"],
                "controlnet": compiled["controlnet"],
                "db_saved": False,
                "db_warning": str(db_exc),
            }

        return {
            "status": "success",
            "image_url": url,
            "generation_mode": generation_mode,
            "mode": compiled["mode"],
            "controlnet": compiled["controlnet"],
            "db_saved": True,
        }

    except Exception as e:
        print("ERROR:", str(e))
        traceback.print_exc()
        diagnostics_on_error = {
            "failed_step": step,
            "exception": format_exception_detail(e),
            "traceback": _preview(traceback.format_exc(), 2000),
            "rest_storage": diagnose_supabase_rest(),
            "rest_db": diagnose_db_rest(),
        }
        return {
            "status": "error",
            "message": str(e),
            "step": step,
            "diagnostics": diagnostics_on_error,
        }


def _warmup_worker():
    """Load weights when the worker process starts (avoids 600s timeout on first job)."""
    if os.getenv("SD_PRELOAD_ON_START", "true").lower() not in ("1", "true", "yes"):
        return
    try:
        t0 = time.time()
        get_sd_pipeline()
        if os.getenv("SD_PRELOAD_IMG2IMG", "true").lower() in ("1", "true", "yes"):
            get_sd_img2img_pipeline()
        print(f"Worker warmup completed in {time.time() - t0:.1f}s")
    except Exception as exc:
        print("Worker warmup failed (first job will load model):", exc)


# ---------------------------
# START SERVERLESS
# ---------------------------
print("Starting minimal RunPod serverless handler...")
_warmup_worker()
runpod.serverless.start({"handler": handler})
