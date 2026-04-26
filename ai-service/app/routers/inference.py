from fastapi import APIRouter, HTTPException, Request

from ..schemas import (
    RecolorRequest,
    RecolorResponse,
    SamInferRequest,
    SamInferResponse,
    YoloInferRequest,
    YoloInferResponse,
    YoloSamInferRequest,
    YoloSamInferResponse,
)
from ..services.pipeline import AiPipeline


router = APIRouter()


@router.post("/infer/yolo", response_model=YoloInferResponse)
def infer_yolo(payload: YoloInferRequest, request: Request):
    pipeline: AiPipeline = request.app.state.pipeline
    if not pipeline.models_loaded:
        raise HTTPException(status_code=503, detail="Models are not ready")
    return pipeline.detect_objects(
        image_base64=payload.image_base64,
        confidence_threshold=payload.confidence_threshold,
        max_detections=payload.max_detections,
    )


@router.post("/infer/sam", response_model=SamInferResponse)
def infer_sam(payload: SamInferRequest, request: Request):
    pipeline: AiPipeline = request.app.state.pipeline
    if not pipeline.models_loaded:
        raise HTTPException(status_code=503, detail="Models are not ready")
    return pipeline.segment_objects(
        image_base64=payload.image_base64,
        prompts=[prompt.model_dump() for prompt in payload.prompts],
        mask_format=payload.mask_format,
    )


@router.post("/infer/yolo-sam", response_model=YoloSamInferResponse)
def infer_yolo_sam(payload: YoloSamInferRequest, request: Request):
    pipeline: AiPipeline = request.app.state.pipeline
    if not pipeline.models_loaded:
        raise HTTPException(status_code=503, detail="Models are not ready")
    return pipeline.detect_and_segment(
        image_base64=payload.image_base64,
        confidence_threshold=payload.confidence_threshold,
        max_detections=payload.max_detections,
        mask_format=payload.mask_format,
    )


@router.post("/edit/recolor", response_model=RecolorResponse)
def recolor(payload: RecolorRequest, request: Request):
    pipeline: AiPipeline = request.app.state.pipeline
    if not pipeline.models_loaded:
        raise HTTPException(status_code=503, detail="Models are not ready")
    return pipeline.recolor_image(
        image_base64=payload.image_base64,
        masks=[mask.model_dump() for mask in payload.masks],
        edits=[edit.model_dump() for edit in payload.edits],
    )

