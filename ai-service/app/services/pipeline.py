from __future__ import annotations

import base64
import gc
import logging
from dataclasses import dataclass, field
from io import BytesIO
from pathlib import Path
from typing import Any

import cv2
import numpy as np
from PIL import Image, ImageDraw
from ultralytics import YOLO


logger = logging.getLogger("ai-service.pipeline")
MIN_DETECTION_SIDE_PX = 16.0
MIN_DETECTION_AREA_RATIO = 0.0025


@dataclass
class AiPipeline:
    yolo_model_path: str
    model_device: str = "cpu"
    max_detections: int = 30
    models_loaded: bool = False
    _yolo_model: YOLO | None = field(default=None, init=False, repr=False)

    def load_models(self) -> None:
        if not self.yolo_model_path:
            print("YOLO not loaded - skipping detection")
            return

        model_path = Path(self.yolo_model_path)
        if not model_path.exists():
            raise FileNotFoundError(f"YOLO model file not found: {model_path}")

        self._yolo_model = YOLO(str(model_path))
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

        conf_threshold = max(0.20, float(confidence_threshold))
        result = self._yolo_model.predict(
            source=image,
            conf=conf_threshold,
            max_det=int(limit),
            device=self.model_device,
            verbose=False,
            iou=0.45,
            agnostic_nms=True,
        )[0]

        names = result.names or {}
        detections: list[dict[str, Any]] = []
        for idx, box in enumerate(result.boxes[:limit]):
            xyxy = box.xyxy[0].tolist()
            x1, y1, x2, y2 = [float(v) for v in xyxy]
            class_id = int(box.cls.item())
            label = str(names.get(class_id, f"class_{class_id}"))
            score = float(box.conf.item())

            box_w = max(0.0, x2 - x1)
            box_h = max(0.0, y2 - y1)
            area_ratio = (box_w * box_h) / max(1.0, float(image_width * image_height))
            if box_w < MIN_DETECTION_SIDE_PX or box_h < MIN_DETECTION_SIDE_PX:
                continue
            if area_ratio < MIN_DETECTION_AREA_RATIO:
                continue

            # Return normalized box coordinates for existing frontend overlays.
            norm_x = max(0.0, min(1.0, x1 / image_width))
            norm_y = max(0.0, min(1.0, y1 / image_height))
            norm_w = max(0.0, min(1.0, box_w / image_width))
            norm_h = max(0.0, min(1.0, box_h / image_height))

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

            # Use rectangle polygon from YOLO box for segmentation
            polygon_points = [
                {"x": self._clamp(x, 0.0, 1.0), "y": self._clamp(y, 0.0, 1.0)},
                {"x": self._clamp(x + w, 0.0, 1.0), "y": self._clamp(y, 0.0, 1.0)},
                {"x": self._clamp(x + w, 0.0, 1.0), "y": self._clamp(y + h, 0.0, 1.0)},
                {"x": self._clamp(x, 0.0, 1.0), "y": self._clamp(y + h, 0.0, 1.0)},
            ]
            score = float(prompt.get("confidence", 0.0))
            mask_base64 = ""
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

    def detect_segment_extract(
        self,
        *,
        image_base64: str,
        confidence_threshold: float,
        max_detections: int,
    ) -> dict[str, Any]:
        result = self.detect_and_segment(
            image_base64=image_base64,
            confidence_threshold=confidence_threshold,
            max_detections=max_detections,
            mask_format="alpha_png",
        )
        image = self._decode_image(image_base64)
        image_h, image_w = image.shape[0], image.shape[1]

        extracted_objects: list[dict[str, Any]] = []
        for obj in result["objects"]:
            mask_b64 = str(obj.get("mask_base64", "")).strip()
            alpha_mask = None
            if mask_b64:
                try:
                    mask_img = Image.open(BytesIO(base64.b64decode(mask_b64))).convert("L")
                    if mask_img.size != (image_w, image_h):
                        mask_img = mask_img.resize((image_w, image_h), Image.Resampling.BILINEAR)
                    alpha_mask = np.array(mask_img, dtype=np.uint8)
                    del mask_img
                except Exception:
                    alpha_mask = None
            if alpha_mask is None:
                alpha_mask = self._resolve_alpha_mask(
                    {"polygon_points": obj.get("polygon_points", [])},
                    image_width=image_w,
                    image_height=image_h,
                )
            obj_image = self._extract_object_cutout_base64(image, alpha_mask)
            if obj_image:  # Only add if extraction succeeded
                extracted_objects.append(
                    {
                        **obj,
                        "object_image_base64": obj_image,
                    }
                )
            del alpha_mask
            gc.collect()

        return {
            "detections": result["detections"],
            "objects": extracted_objects,
            "image_width": result["image_width"],
            "image_height": result["image_height"],
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

    def compose_image(
        self,
        *,
        base_image_base64: str,
        objects: list[dict[str, Any]],
    ) -> dict[str, Any]:
        base_rgb = self._decode_image(base_image_base64)
        base = Image.fromarray(base_rgb, mode="RGB").convert("RGBA")

        def _z(row: dict[str, Any]) -> int:
            try:
                return int(row.get("z_index", 0))
            except Exception:
                return 0

        for row in sorted(objects, key=_z):
            payload = str(row.get("object_image_base64", "")).strip()
            if not payload:
                continue
            if payload.startswith("data:image"):
                payload = payload.partition(",")[2]
            try:
                object_img = Image.open(BytesIO(base64.b64decode(payload))).convert("RGBA")
            except Exception:
                continue

            width_raw = float(row.get("width", object_img.width))
            height_raw = float(row.get("height", object_img.height))
            x_raw = float(row.get("x", 0))
            y_raw = float(row.get("y", 0))

            # Accept either normalized (0..1) or pixel coordinates.
            # Auto-place currently returns normalized values, while manual drag
            # from the editor sends pixel values.
            if 0.0 <= width_raw <= 1.0:
                width_raw *= float(base.width)
            if 0.0 <= height_raw <= 1.0:
                height_raw *= float(base.height)
            if 0.0 <= x_raw <= 1.0:
                x_raw *= float(base.width)
            if 0.0 <= y_raw <= 1.0:
                y_raw *= float(base.height)

            width = max(1, int(width_raw))
            height = max(1, int(height_raw))
            x = int(x_raw)
            y = int(y_raw)
            rotation = float(row.get("rotation", 0.0))
            target_hex = row.get("target_hex")
            intensity = self._clamp(float(row.get("intensity", 1.0)), 0.0, 1.0)

            object_img = object_img.resize((width, height), Image.Resampling.LANCZOS)
            if target_hex:
                try:
                    object_img = self._tint_rgba(object_img, str(target_hex), intensity)
                except Exception:
                    pass
            if abs(rotation) > 0.01:
                object_img = object_img.rotate(rotation, expand=True, resample=Image.Resampling.BICUBIC)

            base.alpha_composite(object_img, dest=(x, y))

        output = BytesIO()
        base.convert("RGB").save(output, format="PNG")
        return {"image_base64": base64.b64encode(output.getvalue()).decode("utf-8")}

    def _decode_image(self, image_base64: str) -> np.ndarray:
        payload = image_base64.strip()
        if payload.startswith("data:image"):
            _, _, payload = payload.partition(",")
        image_bytes = base64.b64decode(payload)
        image = Image.open(BytesIO(image_bytes)).convert("RGB")
        return np.array(image)

    def _extract_object_cutout_base64(
        self,
        image_rgb: np.ndarray,
        alpha_mask: np.ndarray | None,
    ) -> str:
        if alpha_mask is None or not np.any(alpha_mask > 0):
            return ""
        y_idx, x_idx = np.where(alpha_mask > 0)
        if len(x_idx) == 0 or len(y_idx) == 0:
            return ""
        x1, x2 = int(np.min(x_idx)), int(np.max(x_idx))
        y1, y2 = int(np.min(y_idx)), int(np.max(y_idx))
        rgb_crop = image_rgb[y1:y2 + 1, x1:x2 + 1]
        alpha_crop = alpha_mask[y1:y2 + 1, x1:x2 + 1]
        rgba = np.dstack((rgb_crop, alpha_crop)).astype(np.uint8)
        image = Image.fromarray(rgba, mode="RGBA")
        output = BytesIO()
        image.save(output, format="PNG")
        return base64.b64encode(output.getvalue()).decode("utf-8")

    def _tint_rgba(self, image: Image.Image, target_hex: str, intensity: float) -> Image.Image:
        arr = np.array(image).astype(np.float32)
        if arr.shape[-1] != 4:
            return image
        target_rgb = self._hex_to_rgb(target_hex)
        alpha = (arr[..., 3] / 255.0) * intensity
        for channel, value in enumerate(target_rgb):
            arr[..., channel] = arr[..., channel] * (1.0 - alpha) + float(value) * alpha
        return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), mode="RGBA")

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

