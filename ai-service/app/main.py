import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path
from urllib.request import urlretrieve

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from .routers.inference import router as inference_router
from .services.pipeline import AiPipeline


LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=LOG_LEVEL)
logger = logging.getLogger("ai-service")


def ensure_sam_checkpoint() -> None:
    sam_model_path = os.getenv("SAM_MODEL_PATH", "").strip()
    if not sam_model_path:
        return

    sam_path = Path(sam_model_path)
    if sam_path.exists():
        return

    default_url = "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth"
    sam_url = os.getenv("SAM_MODEL_URL", default_url).strip()
    try:
        sam_path.parent.mkdir(parents=True, exist_ok=True)
        logger.info("SAM checkpoint not found at %s. Downloading from %s", sam_path, sam_url)
        urlretrieve(sam_url, sam_path)
        logger.info("SAM checkpoint downloaded to %s", sam_path)
    except Exception as exc:
        logger.warning("Failed to download SAM checkpoint to %s: %s", sam_path, exc)


@asynccontextmanager
async def lifespan(app: FastAPI):
    ensure_sam_checkpoint()
    pipeline = AiPipeline(
        yolo_model_path=os.getenv("YOLO_MODEL_PATH", ""),
        sam_model_path=os.getenv("SAM_MODEL_PATH", ""),
        sam_model_type=os.getenv("SAM_MODEL_TYPE", "vit_b"),
        model_device=os.getenv("MODEL_DEVICE", "cpu"),
        max_detections=int(os.getenv("MAX_DETECTIONS", "30")),
    )
    pipeline.load_models()
    app.state.pipeline = pipeline
    logger.info("AI pipeline initialized")
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
    pipeline: AiPipeline = request.app.state.pipeline
    return {
        "ok": True,
        "modelsLoaded": pipeline.models_loaded,
        "device": pipeline.model_device,
    }

