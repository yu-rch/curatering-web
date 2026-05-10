import logging
import os
import requests
from fastapi import FastAPI, Request, Header, HTTPException
from pydantic import BaseModel

app = FastAPI()

# Configure logging
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=LOG_LEVEL)
logger = logging.getLogger("ai-service")

# Environment variables
RUNPOD_URL = os.getenv("RUNPOD_URL", "https://jlkopaaa0g50dg-8888.proxy.runpod.net/")
INTERNAL_TOKEN = os.getenv("INTERNAL_API_TOKEN")

logger.info(f"RunPod URL: {RUNPOD_URL}")
logger.info(f"Internal token configured: {bool(INTERNAL_TOKEN)}")

class GeneratePayload(BaseModel):
    # Define your payload structure here
    event_type: str
    theme: str
    mood: str
    colors: str
    extra: str = ""

@app.get("/health/live")
def health_live():
    return {"ok": True}

@app.get("/health/ready")
def health_ready():
    try:
        response = requests.get(f"{RUNPOD_URL}/health", timeout=5)
        runpod_healthy = response.status_code == 200
    except:
        runpod_healthy = False
    
    return {
        "ok": True,
        "runpod_connected": runpod_healthy,
        "runpod_url": RUNPOD_URL,
        "service": "api-gateway",
    }

@app.post("/generate")
async def generate(payload: dict, x_internal_token: str = Header(None)):
    # 1. Validate Flutter request (optional auth layer)
    if not x_internal_token:
        raise HTTPException(status_code=401, detail="Missing token")

    # 2. Forward to RunPod (IMPORTANT PART)
    response = requests.post(
        f"{RUNPOD_URL}/generate",
        json=payload,
        headers={
            "x-internal-token": INTERNAL_TOKEN
        }
    )

    return response.json()

@app.post("/generate-theme")
async def generate_theme_legacy(
    image: str = None,
    event_type: str = None,
    theme: str = None,
    mood: str = None,
    colors: str = None,
    extra: str = ""
):
    """Legacy endpoint for Flutter compatibility"""
    if not all([image, event_type, theme, mood, colors]):
        raise HTTPException(status_code=400, detail="Missing required fields")
    
    payload = {
        "event_type": event_type,
        "theme": theme,
        "mood": mood,
        "colors": colors,
        "extra": extra,
        "image": image
    }
    
    response = requests.post(
        f"{RUNPOD_URL}/generate",
        json=payload,
        headers={
            "x-internal-token": INTERNAL_TOKEN
        }
    )

    return response.json()
