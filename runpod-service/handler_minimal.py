import runpod
import base64
from io import BytesIO
import os
import json
import random
import traceback

import requests
from supabase import create_client

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

    try:
        from PIL import Image
        import numpy as np

        img_array = np.random.randint(0, 255, (512, 512, 3), dtype=np.uint8)
        image = Image.fromarray(img_array)

        buffer = BytesIO()
        image.save(buffer, format="PNG")

        return buffer.getvalue()
    except Exception as e:
        print("Error generating mock image:", e)
        return b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00sRGB\x00\xae\xce\x1c\xe9\x00\x00\x00\x00pHYs\x00\x00\x0b\x13\x00\x00\x00\x09p\x08\x00\x00\x00\x09\x1c\x1c\x1c\x9c\x18\x00\x00\x00\x1cIDATx\x9cc\xf8\x0f\x00\x00\x01\x00\x01'


# ---------------------------
# SUPABASE UPLOAD
# ---------------------------
def upload_to_supabase(image_bytes, filename):
    bucket = supabase.storage.from_(BUCKET_ID)
    file_obj = BytesIO(image_bytes)
    file_obj.seek(0)

    bucket.upload(
        path=filename,
        file=file_obj,
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
            "user_id": user_id,
            "prompt": prompt,
            "image_url": url,
            "event_type": data.get("event_type"),
            "theme": data.get("theme"),
            "formality": data.get("formality"),
        }

        try:
            save_to_db(record)
        except Exception as db_exc:
            diagnostics_on_error = {
                "failed_step": step,
                "exception": format_exception_detail(db_exc),
                "image_uploaded": True,
                "public_url": url,
                "rest_db": diagnose_db_rest(),
                "rest_storage": diagnose_supabase_rest(),
            }
            return {
                "status": "error",
                "message": str(db_exc),
                "step": step,
                "diagnostics": diagnostics_on_error,
            }

        return {"status": "success", "image_url": url}

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


# ---------------------------
# START SERVERLESS
# ---------------------------
print("Starting minimal RunPod serverless handler...")
runpod.serverless.start({"handler": handler})
