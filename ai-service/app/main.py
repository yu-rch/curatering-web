import logging
import os
import requests
import base64
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, UploadFile, File, Form
from fastapi.responses import JSONResponse
from .routers.inference import router as inference_router
from .services.pipeline import AiPipeline

app = FastAPI()

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=LOG_LEVEL)
logger = logging.getLogger("ai-service")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Configure RunPod service URL
    runpod_url = os.getenv("RUNPOD_URL", "https://your-runpod-url.runpod.run")
    app.state.runpod_url = runpod_url
    logger.info(f"Configured RunPod service at: {runpod_url}")
    
    # Test RunPod connection
    try:
        response = requests.get(f"{runpod_url}/health", timeout=10)
        if response.status_code == 200:
            logger.info("Successfully connected to RunPod service")
        else:
            logger.warning(f"RunPod service returned status: {response.status_code}")
    except Exception as e:
        logger.error(f"Failed to connect to RunPod service: {e}")
    
    yield


app = FastAPI(title="Curatering AI Service", version="1.0.0", lifespan=lifespan)
app.include_router(inference_router, prefix="/v1")


@app.middleware("http")
async def internal_auth_middleware(request: Request, call_next):
    if request.url.path.startswith("/health"):
        return await call_next(request)

    expected = os.getenv("INTERNAL_API_TOKEN", "")
    auth_header = request.headers.get("authorization", "")
    if not expected:
        return JSONResponse(
            status_code=500,
            content={"message": "INTERNAL_API_TOKEN is not configured", "code": "missing_internal_token"},
        )
    if auth_header != f"Bearer {expected}":
        return JSONResponse(status_code=401, content={"message": "Unauthorized", "code": "invalid_internal_token"})

    response = await call_next(request)
    return response


@app.get("/health/live")
def health_live():
    return {"ok": True}


@app.get("/health/ready")
def health_ready(request: Request):
    runpod_url = request.app.state.runpod_url
    try:
        response = requests.get(f"{runpod_url}/health", timeout=5)
        runpod_healthy = response.status_code == 200
    except:
        runpod_healthy = False
    
    return {
        "ok": True,
        "runpod_connected": runpod_healthy,
        "runpod_url": runpod_url,
        "service": "api-gateway",
    }

def build_prompt(event_type: str, color_scheme: str, style: str, guest_count: int, custom_prompt: str = "") -> str:
    """Build comprehensive AI prompt for event theme generation"""
    base_prompt = f"Create an elegant {event_type} event theme with {color_scheme} color scheme in {style} style"
    
    if guest_count > 0:
        base_prompt += f", designed for {guest_count} guests"
    
    if custom_prompt:
        base_prompt += f", {custom_prompt}"
    
    base_prompt += ", professional event decoration, high quality, detailed, realistic lighting"
    
    return base_prompt

@app.post("/generate-theme")
async def generate_theme(
    image: UploadFile = File(...),
    event_type: str = Form(...),
    color_scheme: str = Form(...),
    style: str = Form(...),
    guest_count: int = Form(50),
    custom_prompt: str = Form(""),
    negative_prompt: str = Form("blurry, distorted, unrealistic, poor quality"),
    strength: float = Form(0.5),
):
    try:
        runpod_url = app.state.runpod_url
        
        # Build comprehensive prompt
        prompt = build_prompt(event_type, color_scheme, style, guest_count, custom_prompt)
        
        logger.info(f"Forwarding theme generation to RunPod: {prompt[:100]}...")
        
        # Read image and prepare payload
        contents = await image.read()
        
        # Forward request to RunPod
        files = {
            'file': ('image.jpg', contents, 'image/jpeg')
        }
        data = {
            'event_type': eventType,
            'theme': colorScheme,
            'mood': style,
            'colors': f"{colorScheme} palette for {guestCount} guests",
            'extra': customPrompt
        }
        
        response = requests.post(
            f"{runpod_url}/generate",
            files=files,
            data=data,
            timeout=300  # 5 minute timeout
        )
        
        if response.status_code == 200:
            # Handle streaming response (image/png)
            if 'image/png' in response.headers.get('content-type', ''):
                # Convert image to base64
                import base64
                image_data = response.content
                encoded = base64.b64encode(image_data).decode()
                logger.info("Theme generation completed successfully via RunPod")
                return JSONResponse({
                    "image": encoded,
                    "success": True
                })
            else:
                # Handle JSON response
                result = response.json()
                logger.info("Theme generation completed successfully via RunPod")
                return JSONResponse(result)
        else:
            logger.error(f"RunPod error: {response.status_code} - {response.text}")
            return JSONResponse({
                "error": f"RunPod service error: {response.status_code}",
                "success": False
            }, status_code=502)

    except Exception as e:
        logger.error(f"Error forwarding to RunPod: {str(e)}")
        return JSONResponse({
            "error": str(e),
            "success": False
        }, status_code=500)