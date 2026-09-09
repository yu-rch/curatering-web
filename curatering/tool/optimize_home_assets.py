"""Compress and resize homepage assets under lib/assets/home/."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ASSETS = Path(__file__).resolve().parent.parent / "lib" / "assets" / "home"

# (max longest edge, jpeg quality)
SPECS = {
    "home-hero": (800, 58),
    "home-collage": (480, 60),
    "etd-sample": (480, 55),
}


def spec_for(name: str) -> tuple[int, int]:
    stem = Path(name).stem
    for prefix, spec in SPECS.items():
        if stem.startswith(prefix):
            return spec
    return (640, 65)


def optimize(src: Path) -> None:
    before = src.stat().st_size
    edge, quality = spec_for(src.name)
    img = Image.open(src).convert("RGB")
    w, h = img.size
    scale = min(1.0, edge / max(w, h))
    if scale < 1.0:
        img = img.resize(
            (max(1, int(w * scale)), max(1, int(h * scale))),
            Image.Resampling.LANCZOS,
        )

    tmp = src.with_suffix(".opt.jpg")
    img.save(tmp, "JPEG", quality=quality, optimize=True, progressive=True)
    after = tmp.stat().st_size
    if after <= before:
        tmp.replace(src)
        print(f"{src.name}: {before} -> {after} bytes ({img.size[0]}x{img.size[1]})")
    else:
        tmp.unlink(missing_ok=True)
        print(f"{src.name}: kept {before} bytes")


def main() -> None:
    if not ASSETS.is_dir():
        raise SystemExit(f"Missing {ASSETS}")
    for src in sorted(ASSETS.glob("*.jpg")):
        optimize(src)


if __name__ == "__main__":
    main()
