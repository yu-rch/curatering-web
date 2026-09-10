#!/usr/bin/env python3
"""Post-build patches for Flutter web release output."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "build" / "web"


def patch_loader_break_iterator_check(text: str) -> str:
    """Only touch Flutter *loader* feature detection.

    Do NOT rewrite main.dart.js: the engine still calls the V8 BreakIterator
    API (adoptText, etc.). Replacing it with Intl.Segmenter blanks the UI.
    """
    replacements = [
        (
            'typeof Intl.v8BreakIterator<"u"&&typeof Intl.Segmenter<"u"',
            'typeof Intl.Segmenter<"u"',
        ),
        (
            'typeof Intl.v8BreakIterator!=="undefined"&&typeof Intl.Segmenter!=="undefined"',
            'typeof Intl.Segmenter!=="undefined"',
        ),
    ]
    for old, new in replacements:
        text = text.replace(old, new)
    return text


def patch_flutter_bootstrap(text: str) -> str:
    # Prefer local CanvasKit so cold load does not pull ~1.6MB from gstatic.
    # Do not force canvasKitVariant — let Flutter pick auto/chromium/full.
    text = re.sub(
        r"_flutter\.loader\.load\(\{[\s\S]*?\}\);",
        '_flutter.loader.load({config:{canvasKitBaseUrl:"/canvaskit/"}});',
        text,
        count=1,
    )
    return text


def ensure_source_mapping_urls() -> None:
    """Attach sourceMappingURL comments when matching .map files exist."""
    for js_path in sorted(ROOT.glob("*.js")):
        if path_should_skip_patch(js_path):
            continue
        map_path = Path(str(js_path) + ".map")
        if not map_path.is_file():
            # Also accept foo.js.map beside foo.js
            map_path = js_path.with_suffix(js_path.suffix + ".map")
        if not map_path.is_file():
            continue
        text = js_path.read_text(encoding="utf-8")
        marker = f"//# sourceMappingURL={map_path.name}"
        # Remove any stale mapping comments first.
        text = re.sub(r"\n?//[#@]\s*sourceMappingURL=[^\s]+", "", text)
        if not text.endswith("\n"):
            text += "\n"
        text += marker + "\n"
        js_path.write_text(text, encoding="utf-8")


def strip_broken_source_mapping_urls() -> None:
    """Remove sourceMappingURL comments that point at missing / SPA-rewritten maps."""
    for js_path in ROOT.rglob("*.js"):
        if path_should_skip_patch(js_path):
            continue
        text = js_path.read_text(encoding="utf-8")
        matches = list(
            re.finditer(r"//[#@]\s*sourceMappingURL=([^\s]+)", text)
        )
        if not matches:
            continue
        changed = False
        for match in reversed(matches):
            map_name = match.group(1).strip()
            if map_name.startswith("http://") or map_name.startswith("https://"):
                continue
            map_path = (js_path.parent / map_name).resolve()
            if map_path.is_file():
                continue
            text = text[: match.start()] + text[match.end() :]
            changed = True
        if changed:
            js_path.write_text(text, encoding="utf-8")


def path_should_skip_patch(path: Path) -> bool:
    name = path.name
    if name in {"boot.js", "console_filter.js", "splash_preload.js"}:
        return True
    parts = {p.lower() for p in path.parts}
    if "canvaskit" in parts:
        return True
    return False


def main() -> None:
    if not ROOT.is_dir():
        raise SystemExit(f"Build output not found: {ROOT}")

    for path in ROOT.rglob("*.js"):
        if path_should_skip_patch(path):
            continue
        original = path.read_text(encoding="utf-8")
        patched = original
        # Never rewrite the app bundle — BreakIterator API must stay intact.
        if path.name in {"flutter.js", "flutter_bootstrap.js"} or path.name.startswith(
            "flutter."
        ):
            patched = patch_loader_break_iterator_check(patched)
        if path.name == "flutter_bootstrap.js":
            patched = patch_flutter_bootstrap(patched)
        if patched != original:
            path.write_text(patched, encoding="utf-8")

    ensure_source_mapping_urls()
    strip_broken_source_mapping_urls()
    print(f"Patched web build in {ROOT}")


if __name__ == "__main__":
    main()
