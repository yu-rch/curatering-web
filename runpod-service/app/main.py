import logging
import os
import io
import torch
from PIL import Image
from fastapi import FastAPI, Request, UploadFile, File, Form
from fastapi.responses import StreamingResponse
from diffusers import StableDiffusionControlNetPipeline, ControlNetModel

app = FastAPI()

# Configure logging
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=LOG_LEVEL)
logger = logging.getLogger("runpod-ai-service")

# Load model ONCE (important)
device = "cuda" if torch.cuda.is_available() else "cpu"
logger.info(f"Loading models on device: {device}")

try:
    controlnet = ControlNetModel.from_pretrained(
        "lllyasviel/sd-controlnet-canny",
        torch_dtype=torch.float16
    )

    pipe = StableDiffusionControlNetPipeline.from_pretrained(
        "runwayml/stable-diffusion-v1-5",
        controlnet=controlnet,
        torch_dtype=torch.float16
    )
    
    # Performance optimizations
    pipe.enable_model_cpu_offload()
    pipe.enable_xformers_memory_efficient_attention()
    pipe.vae.enable_slicing()
    
    logger.info(" Models loaded successfully")
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
    uvicorn.run(app, host="0.0.0.0", port=8000)
