#!/usr/bin/env python3
"""Post-build patches for Flutter web release output."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "build" / "web"


def patch_v8_break_iterator(text: str) -> str:
    """Rewrite deprecated Intl.v8BreakIterator checks to Intl.Segmenter."""
    replacements = [
        (
            'typeof Intl.v8BreakIterator<"u"&&typeof Intl.Segmenter<"u"',
            'typeof Intl.Segmenter<"u"',
        ),
        (
            'typeof Intl.v8BreakIterator!=="undefined"&&typeof Intl.Segmenter!=="undefined"',
            'typeof Intl.Segmenter!=="undefined"',
        ),
        (
            "s.Intl.v8BreakIterator!=null&&s.Intl.Segmenter!=null",
            "s.Intl.Segmenter!=null",
        ),
        (
            "self.Intl.v8BreakIterator!=null&&self.Intl.Segmenter!=null",
            "self.Intl.Segmenter!=null",
        ),
        ('"v8BreakIterator"', '"Segmenter"'),
        ("'v8BreakIterator'", "'Segmenter'"),
        ("v8BreakIterator is not supported.", "Segmenter is not supported."),
        ("Intl.v8BreakIterator", "Intl.Segmenter"),
    ]
    for old, new in replacements:
        text = text.replace(old, new)
    # Catch any remaining identifier uses in minified bundles.
    text = re.sub(r"\bv8BreakIterator\b", "Segmenter", text)
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
            # Absolute/remote maps are left alone; relative must exist beside the JS.
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
    # Never rewrite CanvasKit/skwasm engine files.
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
        patched = patch_v8_break_iterator(original)
        if path.name == "flutter_bootstrap.js":
            patched = patch_flutter_bootstrap(patched)
        if patched != original:
            path.write_text(patched, encoding="utf-8")

    strip_broken_source_mapping_urls()
    print(f"Patched web build in {ROOT}")


if __name__ == "__main__":
    main()
