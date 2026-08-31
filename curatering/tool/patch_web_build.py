#!/usr/bin/env python3
"""Post-build patches for Flutter web release output."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "build" / "web"


def patch_loader_js(text: str) -> str:
    text = text.replace(
        "typeof Intl.v8BreakIterator<\"u\"&&typeof Intl.Segmenter<\"u\"",
        "typeof Intl.Segmenter<\"u\"",
    )
    return text.replace("Intl.v8BreakIterator", "Intl.Segmenter")


def patch_main_dart_js(text: str) -> str:
    text = text.replace(
        "s.Intl.v8BreakIterator!=null&&s.Intl.Segmenter!=null",
        "s.Intl.Segmenter!=null",
    )
    text = text.replace("Intl.v8BreakIterator", "Intl.Segmenter")
    text = text.replace('"v8BreakIterator"', '"Segmenter"')
    text = text.replace(
        "v8BreakIterator is not supported.",
        "Segmenter is not supported.",
    )
    return text


def patch_v8_break_iterator(text: str, *, is_main: bool = False) -> str:
    if is_main:
        return patch_main_dart_js(text)
    return patch_loader_js(text)


def patch_flutter_bootstrap(text: str) -> str:
    # Keep local CanvasKit/skwasm assets for both dart2wasm and dart2js builds.
    text = re.sub(
        r"_flutter\.loader\.load\(\{[\s\S]*?\}\);",
        '_flutter.loader.load({config:{canvasKitBaseUrl:"/canvaskit/"}});',
        text,
        count=1,
    )
    return text


def ensure_source_mapping_urls() -> None:
    for js_path in sorted(ROOT.glob("*.js")):
        map_path = js_path.with_suffix(js_path.suffix + ".map")
        if not map_path.exists():
            continue
        text = js_path.read_text(encoding="utf-8")
        marker = f"//# sourceMappingURL={map_path.name}"
        if marker in text:
            continue
        if not text.endswith("\n"):
            text += "\n"
        text += marker + "\n"
        js_path.write_text(text, encoding="utf-8")


def main() -> None:
    if not ROOT.is_dir():
        raise SystemExit(f"Build output not found: {ROOT}")

    for path in ROOT.rglob("*.js"):
        if path.name in {"boot.js", "console_filter.js"}:
            continue
        original = path.read_text(encoding="utf-8")
        is_main_bundle = path.name == "main.dart.js" or path.name.startswith(
            "main.dart.js_"
        )
        patched = patch_v8_break_iterator(
            original,
            is_main=is_main_bundle,
        )
        if path.name == "flutter_bootstrap.js":
            patched = patch_flutter_bootstrap(patched)
        if patched != original:
            path.write_text(patched, encoding="utf-8")

    ensure_source_mapping_urls()
    print(f"Patched web build in {ROOT}")


if __name__ == "__main__":
    main()
