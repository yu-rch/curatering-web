#!/usr/bin/env python3
"""Rebuild index.html early scripts as CSP-hash-allowed inline blocks.

Keeps Lighthouse Performance (no render-blocking external JS) while staying
CSP-compliant for Best Practices.
"""
from __future__ import annotations

import base64
import hashlib
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "web"
BUILD_WEB = ROOT / "build" / "web"
INDEX = WEB / "index.html"
VERCEL = ROOT / "vercel.json"
CONSOLE = WEB / "console_filter.js"
SPLASH = WEB / "splash_preload.js"


def sha256_csp(content: str) -> str:
    digest = hashlib.sha256(content.encode("utf-8")).digest()
    return "sha256-" + base64.b64encode(digest).decode("ascii")


def build_index(console_js: str, splash_js: str) -> str:
    # Keep script bodies exact (no extra whitespace) so CSP hashes match browsers.
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <base href="$FLUTTER_BASE_HREF">

  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="viewport" content="width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=5, user-scalable=yes">
  <meta name="description" content="Macrina's Kitchen and Catering - restaurant orders, catering menus, and event inquiries.">

  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="Macrina's Kitchen">
  <link rel="apple-touch-icon" href="favicon.png">
  <link rel="icon" type="image/png" href="favicon.png"/>

  <title>Home - Macrina's Kitchen and Catering</title>
  <link rel="manifest" href="manifest.json">
  <link rel="dns-prefetch" href="https://curatering.up.railway.app">
  <link rel="preconnect" href="https://curatering.up.railway.app" crossorigin>
  <script>{console_js}</script>
  <link id="app-fonts" rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Pacifico&family=Playfair+Display:wght@400;700&family=Poppins:wght@400;500;600;700;800&family=Scheherazade+New:wght@400;700&display=swap" media="print">
  <noscript><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Pacifico&family=Playfair+Display:wght@400;700&family=Poppins:wght@400;500;600;700;800&family=Scheherazade+New:wght@400;700&display=swap"></noscript>
  <script>{splash_js}</script>

  <style>
    html, body {{
      margin: 0;
      padding: 0;
      background: #000000;
      overscroll-behavior-x: none;
      overscroll-behavior-y: auto;
    }}
    flt-glass-pane, flutter-view {{
      overscroll-behavior-x: none;
    }}
    #app-splash {{
      position: fixed;
      inset: 0;
      z-index: 9999;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      background: #000000;
      color: #ffffff;
      font-family: Georgia, 'Times New Roman', serif;
      text-align: center;
      padding: clamp(12px, 4vw, 24px);
      transition: opacity 120ms ease;
      overflow: hidden;
    }}
    #app-splash.app-splash-shell {{
      justify-content: flex-end;
      align-items: stretch;
      padding: 0;
      background: #1a120c;
    }}
    #app-splash-hero {{
      display: none;
      position: absolute;
      inset: 0;
      width: 100%;
      height: 100%;
      object-fit: cover;
    }}
    #app-splash.app-splash-shell #app-splash-hero {{
      display: block;
    }}
    #app-splash-scrim {{
      display: none;
      position: absolute;
      inset: 0;
      background: linear-gradient(180deg, rgba(0,0,0,.25) 0%, rgba(20,12,8,.72) 55%, rgba(20,12,8,.92) 100%);
    }}
    #app-splash.app-splash-shell #app-splash-scrim {{
      display: block;
    }}
    #app-splash-copy {{
      position: relative;
      z-index: 1;
      display: none;
      flex-direction: column;
      align-items: flex-start;
      gap: 10px;
      padding: clamp(24px, 6vw, 56px);
      max-width: 720px;
      text-align: left;
    }}
    #app-splash.app-splash-shell #app-splash-copy {{
      display: flex;
    }}
    #app-splash.app-splash-shell #app-splash-logo {{
      width: min(70vw, 280px);
      max-height: none;
      margin-bottom: 8px;
    }}
    #app-splash-title {{
      margin: 0;
      color: #fff8f0;
      font-size: clamp(28px, 6vw, 48px);
      line-height: 1.15;
      font-weight: 700;
      letter-spacing: -0.02em;
    }}
    #app-splash-sub {{
      margin: 0;
      color: rgba(255,248,240,.88);
      font-family: system-ui, -apple-system, Segoe UI, sans-serif;
      font-size: clamp(14px, 2.6vw, 18px);
      line-height: 1.45;
      max-width: 34ch;
    }}
    #app-splash.app-splash-hide {{
      opacity: 0;
      pointer-events: none;
    }}
    #app-splash-logo {{
      display: block;
      width: min(90vw, 320px);
      height: auto;
      max-height: min(45vw, 160px);
      object-fit: contain;
    }}
    #app-splash-error {{
      display: none;
      margin-top: 20px;
      max-width: 420px;
      color: #d0d0d0;
      font-size: 15px;
      line-height: 1.4;
      position: relative;
      z-index: 2;
    }}
    #app-splash.has-error #app-splash-error {{
      display: block;
    }}
  </style>
  <script src="boot.js" defer></script>
</head>
<body>
  <div id="app-splash" class="app-splash-shell" aria-busy="true" aria-live="polite">
    <img id="app-splash-hero" alt="" width="1280" height="720" sizes="100vw" decoding="async" fetchpriority="high" />
    <div id="app-splash-scrim" aria-hidden="true"></div>
    <div id="app-splash-copy">
      <img id="app-splash-logo" alt="Loading" width="320" height="160" sizes="280px" decoding="async" fetchpriority="high" />
      <p id="app-splash-title">Macrina's Kitchen and Catering</p>
      <p id="app-splash-sub">Restaurant orders, catering menus, and event inquiries.</p>
    </div>
    <p id="app-splash-error"></p>
  </div>
</body>
</html>
"""


def patch_vercel_csp(hashes: list[str]) -> None:
    data = json.loads(VERCEL.read_text(encoding="utf-8"))
    hash_list = " ".join(f"'{h}'" for h in hashes)
    csp = (
        "default-src 'self'; "
        "script-src 'self' 'unsafe-eval' 'wasm-unsafe-eval' blob: "
        f"https://www.gstatic.com {hash_list}; "
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
        "font-src 'self' data: https://fonts.gstatic.com; "
        "img-src 'self' data: blob: https:; "
        "connect-src 'self' https: wss: blob:; "
        "worker-src 'self' blob:; "
        "child-src 'self' blob:; "
        "frame-ancestors 'none'; "
        "base-uri 'self'; "
        "form-action 'self'; "
        "object-src 'none'"
    )
    for block in data.get("headers", []):
        for header in block.get("headers", []):
            if header.get("key") == "Content-Security-Policy":
                header["value"] = csp
    VERCEL.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def sync_build_output() -> None:
    if not BUILD_WEB.is_dir():
        return
    html = INDEX.read_text(encoding="utf-8").replace("$FLUTTER_BASE_HREF", "/")
    (BUILD_WEB / "index.html").write_text(html, encoding="utf-8", newline="\n")
    shutil.copy2(VERCEL, BUILD_WEB / "vercel.json")
    for name in (
        "boot.js",
        "console_filter.js",
        "splash_preload.js",
        "shell-hero.webp",
        "shell-hero.jpg",
    ):
        src = WEB / name
        if src.is_file():
            shutil.copy2(src, BUILD_WEB / name)


def main() -> None:
    console_js = CONSOLE.read_text(encoding="utf-8").strip()
    splash_js = SPLASH.read_text(encoding="utf-8").strip()
    html = build_index(console_js, splash_js)
    INDEX.write_text(html, encoding="utf-8", newline="\n")

    # Verify extracted bodies match source exactly.
    bodies = re.findall(r"<script>(.*?)</script>", html, flags=re.S)
    if bodies[:2] != [console_js, splash_js]:
        raise SystemExit("Inline script bodies do not match source files")

    hashes = [sha256_csp(console_js), sha256_csp(splash_js)]
    patch_vercel_csp(hashes)
    sync_build_output()
    print("Updated", INDEX.relative_to(ROOT))
    print("Updated", VERCEL.relative_to(ROOT))
    for h in hashes:
        print(" ", h)


if __name__ == "__main__":
    main()
