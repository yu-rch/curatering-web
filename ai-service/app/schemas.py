from typing import Literal

from pydantic import BaseModel, Field, field_validator


class BoxDto(BaseModel):
    x: float = Field(ge=0)
    y: float = Field(ge=0)
    width: float = Field(ge=0)
    height: float = Field(ge=0)


class YoloInferRequest(BaseModel):
    image_base64: str = Field(min_length=1)
    confidence_threshold: float = Field(default=0.25, ge=0, le=1)
    max_detections: int = Field(default=30, ge=1, le=100)


class YoloDetectionDto(BaseModel):
    id: str
    label: str
    confidence: float
    box: BoxDto


class YoloInferResponse(BaseModel):
    detections: list[YoloDetectionDto]
    image_width: int
    image_height: int


class SamPromptDto(BaseModel):
    id: str
    label: str
    box: BoxDto


class SamInferRequest(BaseModel):
    image_base64: str = Field(min_length=1)
    prompts: list[SamPromptDto] = Field(min_length=1)
    mask_format: Literal["polygon", "rle", "alpha_png"] = "polygon"


class PolygonPointDto(BaseModel):
    x: float
    y: float


class SamObjectDto(BaseModel):
    id: str
    label: str
    score: float
    box: BoxDto
    polygon_points: list[PolygonPointDto] = Field(default_factory=list)
    mask_rle: str | None = None
    mask_base64: str | None = None


class SamInferResponse(BaseModel):
    objects: list[SamObjectDto]


class YoloSamInferRequest(BaseModel):
    image_base64: str = Field(min_length=1)
    confidence_threshold: float = Field(default=0.25, ge=0, le=1)
    max_detections: int = Field(default=30, ge=1, le=100)
    mask_format: Literal["polygon", "rle", "alpha_png"] = "polygon"


class YoloSamInferResponse(BaseModel):
    detections: list[YoloDetectionDto]
    objects: list[SamObjectDto]
    image_width: int
    image_height: int


class RecolorMaskDto(BaseModel):
    object_id: str
    polygon_points: list[PolygonPointDto] | None = None
    mask_rle: str | None = None
    mask_base64: str | None = None


class RecolorEditDto(BaseModel):
    object_id: str
    target_hex: str
    intensity: float = Field(default=1.0, ge=0, le=1)

    @field_validator("target_hex")
    @classmethod
    def validate_hex(cls, value: str):
        cleaned = value.strip()
        if not cleaned.startswith("#"):
            cleaned = f"#{cleaned}"
        if len(cleaned) != 7:
            raise ValueError("target_hex must be #RRGGBB")
        return cleaned.lower()


class RecolorRequest(BaseModel):
    image_base64: str = Field(min_length=1)
    masks: list[RecolorMaskDto] = Field(min_length=1)
    edits: list[RecolorEditDto] = Field(min_length=1)


class RecolorAppliedDto(BaseModel):
    object_id: str
    target_hex: str


class RecolorSkippedDto(BaseModel):
    object_id: str
    reason: str


class RecolorResponse(BaseModel):
    image_base64: str
    applied: list[RecolorAppliedDto] = Field(default_factory=list)
    skipped: list[RecolorSkippedDto] = Field(default_factory=list)

