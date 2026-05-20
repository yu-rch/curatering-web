import logging
import os
import io
import torch
from PIL import Image
from fastapi import FastAPI, Request, UploadFile, File, Form
from fastapi.responses import StreamingResponse
from diffusers import DPMSolverMultistepScheduler, StableDiffusionXLPipeline

app = FastAPI()

# Configure logging
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=LOG_LEVEL)
logger = logging.getLogger("runpod-ai-service")

# Load model ONCE (important)
device = "cuda" if torch.cuda.is_available() else "cpu"
logger.info(f"Loading models on device: {device}")

try:
    model_id = os.getenv("SD_MODEL_ID", "stabilityai/stable-diffusion-xl-base-1.0")
    dtype = torch.float16 if device == "cuda" else torch.float32
    kwargs = {
        "torch_dtype": dtype,
        "use_safetensors": True,
    }
    if device == "cuda" and os.getenv("SD_MODEL_VARIANT", "fp16"):
        kwargs["variant"] = os.getenv("SD_MODEL_VARIANT", "fp16")

    pipe = StableDiffusionXLPipeline.from_pretrained(
        model_id,
        **kwargs,
    )
    pipe.scheduler = DPMSolverMultistepScheduler.from_config(pipe.scheduler.config)
    
    # Performance optimizations
    if device == "cuda":
        pipe.to(device)
    pipe.enable_attention_slicing()
    pipe.vae.enable_slicing()
    
    logger.info("SDXL model loaded successfully")
except Exception as e:
    logger.error(f" Failed to load models: {e}")
    raise


@app.get("/health")
def health():
    return {"status": "healthy", "device": device}

@app.post("/generate")
async def generate(request: Request):
    token = request.headers.get("x-internal-token")
    
    if token != os.getenv("INTERNAL_API_TOKEN"):
        return {"error": "unauthorized"}
    
    # For now, return a simple result
    # TODO: Implement actual AI inference here
    return {"result": "image_url"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8888)
