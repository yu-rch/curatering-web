import logging
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from .routers.inference import router as inference_router
from .services.pipeline import AiPipeline


LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=LOG_LEVEL)
logger = logging.getLogger("ai-service")


@asynccontextmanager
async def lifespan(app: FastAPI):
    pipeline = AiPipeline(
        yolo_model_path=os.getenv("YOLO_MODEL_PATH", ""),
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

