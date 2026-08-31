"""Compress homepage JPG assets under lib/assets/home/."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

assets = Path(__file__).resolve().parent.parent / "lib" / "assets" / "home"
if not assets.is_dir():
    raise SystemExit(f"Missing {assets}")

for src in sorted(assets.glob("*.jpg")):
    before = src.stat().st_size
    img = Image.open(src)
    if img.mode not in ("RGB", "L"):
        img = img.convert("RGB")
    tmp = src.with_suffix(".opt.jpg")
    img.save(tmp, "JPEG", quality=80, optimize=True, progressive=True)
    after = tmp.stat().st_size
    if after < before:
        tmp.replace(src)
        print(f"{src.name}: {before} -> {after} bytes")
    else:
        tmp.unlink(missing_ok=True)
        print(f"{src.name}: kept {before} bytes")
