import logging
import os
import io
import torch
from PIL import Image
from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import StreamingResponse
from diffusers import StableDiffusionControlNetPipeline, ControlNetModel

app = FastAPI()

# Configure logging
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=LOG_LEVEL)
logger = logging.getLogger("runpod-ai-service")

# 🔥 Load model ONCE (important)
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
    ).to(device)

    pipe.enable_xformers_memory_efficient_attention()
    logger.info("Stable Diffusion ControlNet pipeline loaded successfully")
    
except Exception as e:
    logger.error(f"Failed to load models: {e}")
    pipe = None


# 🎯 Prompt builder (backend version)
def build_prompt(event_type, theme, mood, colors, extra):
    return f"""
    {event_type} event, {theme} theme,
    {mood} atmosphere,
    decorated venue, table setup, elegant design,
    color palette {colors},
    {extra},
    realistic, high detail, professional photography
    """


@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "models_loaded": pipe is not None,
        "device": device
    }


@app.post("/generate")
async def generate(
    file: UploadFile = File(...),
    event_type: str = Form(...),
    theme: str = Form(...),
    mood: str = Form(...),
    colors: str = Form(...),
    extra: str = Form("")
):
    try:
        if pipe is None:
            return {"error": "AI pipeline not loaded", "success": False}

        # 📥 Read uploaded image
        image_bytes = await file.read()
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        image = image.resize((512, 512))  # required size

        # 🧠 Build prompt
        prompt = build_prompt(event_type, theme, mood, colors, extra)

        logger.info(f"Generating theme: {prompt[:100]}...")

        # 🎨 Generate image
        result = pipe(
            prompt=prompt,
            image=image,
            num_inference_steps=30
        ).images[0]

        # 📤 Return image
        img_io = io.BytesIO()
        result.save(img_io, format="PNG")
        img_io.seek(0)

        return StreamingResponse(img_io, media_type="image/png")

    except Exception as e:
        logger.error(f"Error generating theme: {str(e)}")
        return {"error": str(e), "success": False}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
