from PIL import Image
from pathlib import Path

web = Path(__file__).resolve().parent.parent / "web"
for name in ("splash-customer.png", "splash-staff.png"):
    src = web / name
    img = Image.open(src)
    print(name, img.size, img.mode, src.stat().st_size)
    webp_out = web / name.replace(".png", ".webp")
    img.save(webp_out, "WEBP", quality=82, method=6)
    print("  webp", webp_out.stat().st_size)
