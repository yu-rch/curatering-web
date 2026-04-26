from __future__ import annotations

import base64
import logging
from dataclasses import dataclass, field
from io import BytesIO
from pathlib import Path
from typing import Any

import cv2
import numpy as np
from PIL import Image, ImageDraw
from segment_anything import SamPredictor, sam_model_registry
from ultralytics import YOLO


logger = logging.getLogger("ai-service.pipeline")


@dataclass
class AiPipeline:
    yolo_model_path: str
    sam_model_path: str
    sam_model_type: str = "vit_b"
    model_device: str = "cpu"
    max_detections: int = 30
    models_loaded: bool = False
    _yolo_model: YOLO | None = field(default=None, init=False, repr=False)
    _sam_predictor: SamPredictor | None = field(default=None, init=False, repr=False)

    def load_models(self) -> None:
        if not self.yolo_model_path:
            raise ValueError("YOLO_MODEL_PATH is required")

        model_path = Path(self.yolo_model_path)
        if not model_path.exists():
            raise FileNotFoundError(f"YOLO model file not found: {model_path}")

        self._yolo_model = YOLO(str(model_path))

        if self.sam_model_path:
            sam_path = Path(self.sam_model_path)
            if not sam_path.exists():
                logger.warning(
                    "SAM model file not found at %s; segmentation endpoint will be unavailable",
                    sam_path,
                )
            else:
                sam_builder = sam_model_registry.get(self.sam_model_type)
                if sam_builder is None:
                    raise ValueError(
                        f"Unsupported SAM_MODEL_TYPE: {self.sam_model_type}. "
                        "Supported values include vit_b, vit_l, vit_h."
                    )
                sam_model = sam_builder(checkpoint=str(sam_path))
                sam_model.to(device=self.model_device)
                self._sam_predictor = SamPredictor(sam_model)
                logger.info(
                    "SAM model loaded from %s (type=%s, device=%s)",
                    sam_path,
                    self.sam_model_type,
                    self.model_device,
                )
        else:
            logger.warning("SAM_MODEL_PATH is not configured; segmentation endpoint will be unavailable")

        self.models_loaded = True
        logger.info("YOLO model loaded from %s", model_path)

    def detect_objects(
        self,
        *,
        image_base64: str,
        confidence_threshold: float,
        max_detections: int,
    ) -> dict[str, Any]:
        limit = min(max_detections, self.max_detections)
        image = self._decode_image(image_base64)
        image_width = int(image.shape[1])
        image_height = int(image.shape[0])

        if self._yolo_model is None:
            raise RuntimeError("YOLO model is not initialized")

        result = self._yolo_model.predict(
            source=image,
            conf=float(confidence_threshold),
            max_det=int(limit),
            device=self.model_device,
            verbose=False,
        )[0]

        names = result.names or {}
        detections: list[dict[str, Any]] = []
        for idx, box in enumerate(result.boxes[:limit]):
            xyxy = box.xyxy[0].tolist()
            x1, y1, x2, y2 = [float(v) for v in xyxy]
            class_id = int(box.cls.item())
            label = str(names.get(class_id, f"class_{class_id}"))
            score = float(box.conf.item())

            # Return normalized box coordinates for existing frontend overlays.
            norm_x = max(0.0, min(1.0, x1 / image_width))
            norm_y = max(0.0, min(1.0, y1 / image_height))
            norm_w = max(0.0, min(1.0, (x2 - x1) / image_width))
            norm_h = max(0.0, min(1.0, (y2 - y1) / image_height))

            detections.append(
                {
                    "id": f"{label}_{idx + 1}",
                    "label": label,
                    "confidence": score,
                    "box": {"x": norm_x, "y": norm_y, "width": norm_w, "height": norm_h},
                }
            )

        return {
            "detections": detections,
            "image_width": image_width,
            "image_height": image_height,
        }

    def segment_objects(
        self,
        *,
        image_base64: str,
        prompts: list[dict[str, Any]],
        mask_format: str,
    ) -> dict[str, Any]:
        image = self._decode_image(image_base64)
        image_height = int(image.shape[0])
        image_width = int(image.shape[1])
        use_sam = self._sam_predictor is not None
        if use_sam:
            self._sam_predictor.set_image(image)
        else:
            logger.warning(
                "SAM model is not configured. Falling back to YOLO box polygons for segmentation."
            )
        objects: list[dict[str, Any]] = []

        for prompt in prompts:
            x = float(prompt["box"]["x"])
            y = float(prompt["box"]["y"])
            w = float(prompt["box"]["width"])
            h = float(prompt["box"]["height"])

            x1 = self._clamp(x * image_width, 0, image_width - 1)
            y1 = self._clamp(y * image_height, 0, image_height - 1)
            x2 = self._clamp((x + w) * image_width, x1 + 1, image_width)
            y2 = self._clamp((y + h) * image_height, y1 + 1, image_height)

            polygon_points: list[dict[str, float]] = []
            mask_base64 = ""
            score = 0.0
            if use_sam:
                masks, scores, _ = self._sam_predictor.predict(
                    box=np.array([x1, y1, x2, y2], dtype=np.float32),
                    multimask_output=False,
                )
                if len(masks) > 0:
                    mask_bool = masks[0]
                    score = float(scores[0]) if len(scores) > 0 else 0.0
                    mask_arr = (mask_bool.astype(np.uint8) * 255).astype(np.uint8)
                    polygon_points = self._mask_to_polygon_points(
                        mask_arr,
                        image_width=image_width,
                        image_height=image_height,
                    )

                    if mask_format == "alpha_png":
                        mask_base64 = self._encode_png_base64(mask_arr)
                    else:
                        mask_base64 = ""
            else:
                # Fallback: rectangle polygon from YOLO box so editing flow remains usable.
                polygon_points = [
                    {"x": self._clamp(x, 0.0, 1.0), "y": self._clamp(y, 0.0, 1.0)},
                    {"x": self._clamp(x + w, 0.0, 1.0), "y": self._clamp(y, 0.0, 1.0)},
                    {"x": self._clamp(x + w, 0.0, 1.0), "y": self._clamp(y + h, 0.0, 1.0)},
                    {"x": self._clamp(x, 0.0, 1.0), "y": self._clamp(y + h, 0.0, 1.0)},
                ]
                score = float(prompt.get("confidence", 0.0))
                if mask_format == "alpha_png":
                    mask_arr = np.zeros((image_height, image_width), dtype=np.uint8)
                    xi1 = int(round(x1))
                    yi1 = int(round(y1))
                    xi2 = int(round(x2))
                    yi2 = int(round(y2))
                    mask_arr[max(0, yi1):min(image_height, yi2), max(0, xi1):min(image_width, xi2)] = 255
                    mask_base64 = self._encode_png_base64(mask_arr)

            objects.append(
                {
                    "id": prompt["id"],
                    "label": prompt["label"],
                    "score": score,
                    "box": {"x": x, "y": y, "width": w, "height": h},
                    "polygon_points": polygon_points,
                    "mask_base64": mask_base64,
                }
            )
        return {"objects": objects}

    def detect_and_segment(
        self,
        *,
        image_base64: str,
        confidence_threshold: float,
        max_detections: int,
        mask_format: str,
    ) -> dict[str, Any]:
        yolo_result = self.detect_objects(
            image_base64=image_base64,
            confidence_threshold=confidence_threshold,
            max_detections=max_detections,
        )
        prompts = [
            {
                "id": detection["id"],
                "label": detection["label"],
                "box": detection["box"],
            }
            for detection in yolo_result["detections"]
        ]
        sam_result = self.segment_objects(
            image_base64=image_base64,
            prompts=prompts,
            mask_format=mask_format,
        )
        return {
            "detections": yolo_result["detections"],
            "objects": sam_result["objects"],
            "image_width": yolo_result["image_width"],
            "image_height": yolo_result["image_height"],
        }

    def recolor_image(
        self,
        *,
        image_base64: str,
        masks: list[dict[str, Any]],
        edits: list[dict[str, Any]],
    ) -> dict[str, Any]:
        image = self._decode_image(image_base64).astype(np.float32)
        image_height = int(image.shape[0])
        image_width = int(image.shape[1])

        edit_map = {
            str(row["object_id"]): {
                "target_hex": str(row["target_hex"]),
                "intensity": float(row.get("intensity", 1.0)),
            }
            for row in edits
            if row.get("object_id") and row.get("target_hex")
        }

        applied: list[dict[str, str]] = []
        skipped: list[dict[str, str]] = []

        for mask in masks:
            object_id = str(mask.get("object_id", ""))
            if not object_id:
                continue

            if object_id not in edit_map:
                skipped.append({"object_id": object_id, "reason": "No matching color edit"})
                continue

            edit = edit_map[object_id]
            target_hex = edit["target_hex"]
            intensity = self._clamp(edit["intensity"], 0.0, 1.0)

            try:
                target_rgb = self._hex_to_rgb(target_hex)
            except ValueError:
                skipped.append({"object_id": object_id, "reason": f"Invalid target_hex: {target_hex}"})
                continue

            alpha_mask = self._resolve_alpha_mask(mask, image_width=image_width, image_height=image_height)
            if alpha_mask is None or not np.any(alpha_mask > 0):
                skipped.append({"object_id": object_id, "reason": "Mask is empty or invalid"})
                continue

            blend_alpha = (alpha_mask / 255.0) * intensity
            target_layer = np.zeros_like(image)
            target_layer[..., 0] = float(target_rgb[0])
            target_layer[..., 1] = float(target_rgb[1])
            target_layer[..., 2] = float(target_rgb[2])

            image = image * (1.0 - blend_alpha[..., None]) + target_layer * blend_alpha[..., None]
            applied.append({"object_id": object_id, "target_hex": target_hex})

        output_base64 = self._encode_rgb_png_base64(np.clip(image, 0, 255).astype(np.uint8))
        return {"image_base64": output_base64, "applied": applied, "skipped": skipped}

    def _decode_image(self, image_base64: str) -> np.ndarray:
        payload = image_base64.strip()
        if payload.startswith("data:image"):
            _, _, payload = payload.partition(",")
        image_bytes = base64.b64decode(payload)
        image = Image.open(BytesIO(image_bytes)).convert("RGB")
        return np.array(image)

    def _resolve_alpha_mask(
        self,
        mask: dict[str, Any],
        *,
        image_width: int,
        image_height: int,
    ) -> np.ndarray | None:
        polygon_points = mask.get("polygon_points")
        if isinstance(polygon_points, list) and polygon_points:
            poly_mask = self._polygon_to_mask(polygon_points, image_width=image_width, image_height=image_height)
            if poly_mask is not None:
                return poly_mask

        mask_base64 = str(mask.get("mask_base64", "")).strip()
        if mask_base64:
            b64_payload = mask_base64.partition(",")[2] if mask_base64.startswith("data:image") else mask_base64
            try:
                mask_img = Image.open(BytesIO(base64.b64decode(b64_payload))).convert("L")
                if mask_img.size != (image_width, image_height):
                    mask_img = mask_img.resize((image_width, image_height), Image.Resampling.BILINEAR)
                return np.array(mask_img, dtype=np.uint8)
            except Exception:
                return None

        return None

    def _polygon_to_mask(
        self,
        polygon_points: list[dict[str, Any]],
        *,
        image_width: int,
        image_height: int,
    ) -> np.ndarray | None:
        points: list[tuple[float, float]] = []
        for point in polygon_points:
            try:
                px = float(point["x"])
                py = float(point["y"])
            except (KeyError, TypeError, ValueError):
                continue
            points.append(
                (
                    self._clamp(px * image_width, 0.0, image_width - 1.0),
                    self._clamp(py * image_height, 0.0, image_height - 1.0),
                )
            )
        if len(points) < 3:
            return None

        mask_img = Image.new("L", (image_width, image_height), 0)
        ImageDraw.Draw(mask_img).polygon(points, fill=255)
        return np.array(mask_img, dtype=np.uint8)

    def _encode_png_base64(self, mask_arr: np.ndarray) -> str:
        image = Image.fromarray(mask_arr, mode="L")
        output = BytesIO()
        image.save(output, format="PNG")
        return base64.b64encode(output.getvalue()).decode("utf-8")

    def _mask_to_polygon_points(
        self,
        mask_arr: np.ndarray,
        *,
        image_width: int,
        image_height: int,
    ) -> list[dict[str, float]]:
        contours, _ = cv2.findContours(mask_arr, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if not contours:
            return []
        contour = max(contours, key=cv2.contourArea)
        if cv2.contourArea(contour) <= 0:
            return []

        epsilon = 0.003 * cv2.arcLength(contour, True)
        approx = cv2.approxPolyDP(contour, epsilon, True)
        return [
            {
                "x": self._clamp(float(point[0][0]) / image_width, 0.0, 1.0),
                "y": self._clamp(float(point[0][1]) / image_height, 0.0, 1.0),
            }
            for point in approx
        ]

    def _encode_rgb_png_base64(self, rgb_arr: np.ndarray) -> str:
        image = Image.fromarray(rgb_arr, mode="RGB")
        output = BytesIO()
        image.save(output, format="PNG")
        return base64.b64encode(output.getvalue()).decode("utf-8")

    def _hex_to_rgb(self, hex_color: str) -> tuple[int, int, int]:
        cleaned = str(hex_color).strip()
        if cleaned.startswith("#"):
            cleaned = cleaned[1:]
        if len(cleaned) != 6:
            raise ValueError("Expected RRGGBB format")
        return (int(cleaned[0:2], 16), int(cleaned[2:4], 16), int(cleaned[4:6], 16))

    def _clamp(self, value: float, min_value: float, max_value: float) -> float:
        return max(min_value, min(max_value, value))

