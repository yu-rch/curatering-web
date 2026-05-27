# Shared image transformation engine utilities.
import re

THEME_DECOR_MAP = {
    "cinderella": [
        "princess figure wearing royal blue dress",
        "royal blue drapery",
        "glass slipper centerpiece",
        "castle arch backdrop",
        "crystal chandeliers",
    ],
    "rustic": [
        "wooden tables",
        "warm string lights",
        "greenery centerpieces",
    ],
    "modern luxury": [
        "gold accents",
        "marble decor",
        "minimalist floral arrangements",
    ],
    "luxury": [
        "crystal chandeliers",
        "white floral centerpieces",
        "gold accents",
        "cream drapery",
    ],
}

GEOMETRY_NEGATIVE = [
    "warped architecture",
    "distorted room",
    "crooked walls",
    "fisheye",
    "bad perspective",
    "warped ceiling",
    "melted surfaces",
]

STYLE_NEGATIVE = [
    "cartoon",
    "anime",
    "cgi",
    "illustration",
]

ARTIFACT_NEGATIVE = [
    "duplicate objects",
    "floating decor",
    "blurry",
    "low quality",
    "watermark",
    "logo",
    "text",
]


def clean(value):
    if value is None:
        return ""
    if isinstance(value, (list, tuple, set)):
        return ", ".join(str(v).strip() for v in value if str(v).strip())
    return str(value).strip()


def as_list(value):
    if isinstance(value, (list, tuple, set)):
        return [str(v).strip() for v in value if str(v).strip()]
    text = clean(value)
    if not text:
        return []
    return [x.strip() for x in text.split(",") if x.strip()]


def dedupe(items, limit=32):
    out = []
    seen = set()
    for item in items:
        text = str(item or "").strip()
        if not text:
            continue
        key = text.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(text)
        if len(out) >= limit:
            break
    return out


def theme_decor_tokens(data):
    lookup = " ".join([
        clean(data.get("theme")),
        clean(data.get("style")),
        clean(data.get("mood")),
        clean(data.get("positive_prompt") or data.get("prompt")),
        clean(data.get("custom_instructions") or data.get("notes")),
    ]).lower()
    tokens = []
    for key, values in THEME_DECOR_MAP.items():
        if key in lookup:
            tokens.extend(values)
    return dedupe(tokens)


def controlnet_scale_for_denoise(denoise):
    return get_controlnet(_intensity_from_strength(denoise))


def get_strength(intensity):
    value = _clamp(float(intensity), 0, 1)
    if value < 0.4:
        return 0.75
    if value < 0.7:
        return 0.82
    return 0.9


def get_controlnet(intensity):
    value = _clamp(float(intensity), 0, 1)
    if value < 0.4:
        return 0.85
    if value < 0.7:
        return 0.65
    return 0.55


def get_preprocessor(intensity):
    # Current RunPod image is intentionally reverted to SD 1.5 + Canny ControlNet.
    return "canny"


def get_mode(intensity):
    value = _clamp(float(intensity), 0, 1)
    if value < 0.4:
        return "preserve"
    if value < 0.7:
        return "modify"
    return "rebuild"


def _clamp(value, lower, upper):
    return max(lower, min(value, upper))


def _intensity_from_strength(strength):
    value = float(strength)
    if value < 0.8:
        return 0.3
    if value < 0.86:
        return 0.55
    return 0.8


def resolve_intensity(data):
    for key in ("intensity", "transformation_intensity"):
        try:
            if data.get(key) is not None:
                return _clamp(float(data.get(key)), 0, 1)
        except Exception:
            pass
    try:
        if data.get("strength") is not None:
            return _intensity_from_strength(data.get("strength"))
    except Exception:
        pass
    return 0.8


def _contains_phrase(parts, phrase):
    needle = phrase.lower()
    return any(needle in part.lower() for part in parts)


def _append_items(parts, values):
    for value in values:
        text = clean(value)
        if text and not _contains_phrase(parts, text):
            parts.append(text)


SPATIAL_TOKENS = [
    "center of room",
    "floor area filled with",
    "main hall placement",
    "foreground seating area",
]


def normalize_location(value):
    text = clean(value).lower()
    if not text:
        return ""
    if any(word in text for word in ("middle", "center", "centre")):
        return "center"
    if "side wall" in text or "wall" in text or "side" in text:
        return "side wall"
    if "floor" in text:
        return "floor area"
    if "front" in text or "foreground" in text:
        return "foreground seating area"
    if "main hall" in text or "hall" in text:
        return "main hall"
    return text


def as_insert_objects(value):
    if not isinstance(value, list):
        return []
    out = []
    for item in value:
        if not isinstance(item, dict):
            continue
        obj = clean(item.get("object") or item.get("item") or item.get("name"))
        if not obj:
            continue
        out.append({
            "object": obj,
            "location": normalize_location(
                item.get("location") or item.get("position") or item.get("placement")
            ),
        })
    return out


def location_for_object(obj, data):
    lookup = " ".join([
        clean(data.get("prompt")),
        clean(data.get("notes")),
        clean(data.get("custom_instructions")),
        clean(data.get("theme")),
        clean(obj),
    ]).lower()
    if any(word in lookup for word in ("middle", "center", "centre")):
        return "center"
    if "photo booth" in lookup:
        return "side wall"
    if any(word in lookup for word in ("table", "chair", "seating", "floor")):
        return "floor area"
    if any(word in lookup for word in ("backdrop", "arch", "stage")):
        return "main hall"
    return ""


def compile_insert_object(item):
    obj = clean(item.get("object") if isinstance(item, dict) else "")
    loc = normalize_location(item.get("location") if isinstance(item, dict) else "")
    if not obj:
        return ""
    if loc == "center":
        return f"center {obj} centerpiece"
    if loc == "side wall":
        return f"add {obj} near side wall"
    if loc == "floor area":
        return f"add {obj} on floor area"
    if loc == "foreground seating area":
        return f"add {obj} in foreground seating area"
    if loc == "main hall":
        return f"add {obj} in main hall placement"
    return f"add {obj}"


def build_transformation_plan(data):
    existing = data.get("transformation_plan")
    if isinstance(existing, dict):
        insert_objects = as_insert_objects(existing.get("insert_objects"))
        objects_to_add = dedupe(as_list(existing.get("objects_to_add")), 12)
        if not insert_objects:
            insert_objects = [
                {"object": obj, "location": location_for_object(obj, data)}
                for obj in dedupe(objects_to_add, 8)
            ]
        return {
            "global_style": clean(existing.get("global_style")),
            "theme": clean(existing.get("theme") or data.get("theme") or data.get("style")),
            "insert_objects": insert_objects,
            "objects_to_add": objects_to_add,
            "objects_to_replace": dedupe(as_list(existing.get("objects_to_replace")), 8),
            "decor": dedupe(as_list(existing.get("decor")), 12),
            "lighting_style": clean(existing.get("lighting_style")),
            "mood": clean(existing.get("mood")),
        }

    theme = clean(data.get("theme") or data.get("style") or data.get("event_type"))
    objects = []
    objects.extend(as_list(data.get("objects_to_add")))
    objects.extend(as_list(data.get("decor_elements") or data.get("decor")))
    objects.extend(as_list(data.get("theme_tokens")))
    objects.extend(as_list(data.get("decor_tokens")))
    objects.extend(theme_decor_tokens(data))
    if not any("table" in item.lower() for item in objects):
        objects.insert(0, "round banquet tables")

    insert_objects = as_insert_objects(data.get("insert_objects"))
    if not insert_objects:
        insert_objects = [
            {"object": obj, "location": location_for_object(obj, data)}
            for obj in dedupe(objects, 8)
        ]

    replacements = as_list(data.get("objects_to_replace"))
    colors = as_list(data.get("color_palette") or data.get("colors"))
    if colors:
        replacements.append(f"plain accents with {', '.join(colors)} accents")

    lighting = as_list(data.get("lighting_tokens"))
    lighting_style = lighting[0] if lighting else clean(data.get("lighting_style"))

    return {
        "global_style": clean(data.get("global_style")),
        "theme": theme,
        "insert_objects": insert_objects,
        "objects_to_add": dedupe(objects, 12),
        "objects_to_replace": dedupe(replacements, 8),
        "decor": dedupe(as_list(data.get("decor")), 12),
        "lighting_style": lighting_style,
        "mood": clean(data.get("mood")),
    }


def compile_prompt(plan):
    parts = []
    theme = clean(plan.get("theme"))
    if theme:
        parts.append(f"transform venue into {theme} event")
    else:
        parts.append("transform venue into themed event")
    parts.append("add decor on top of venue photo")
    parts.append("empty floor to be filled with event furniture")
    _append_items(parts, SPATIAL_TOKENS)

    _append_items(parts, [compile_insert_object(item) for item in plan.get("insert_objects", [])])
    _append_items(parts, as_list(plan.get("objects_to_add")))
    _append_items(parts, as_list(plan.get("decor")))
    for item in as_list(plan.get("objects_to_replace")):
        text = clean(item)
        if text:
            parts.append(f"replace {text}")
    lighting = clean(plan.get("lighting_style"))
    if lighting:
        parts.append(lighting)
    parts.append("photorealistic")
    return clean_prompt(", ".join(dedupe(parts, 18)))


def clean_prompt(prompt):
    text = clean(prompt)
    text = re.sub(r"\(([^:()]+):\d+(?:\.\d+)?\)", r"\1", text)
    banned = [
        "ultra detailed",
        "cinematic lighting",
        "luxury interior photography",
        "masterpiece",
        "beautiful",
        "luxury vibe",
        "cinematic atmosphere",
    ]
    for phrase in banned:
        text = re.sub(re.escape(phrase), "", text, flags=re.IGNORECASE)
    parts = [part.strip(" ,") for part in text.split(",")]
    return ", ".join(dedupe(parts, 18)).strip(" ,")


def build_prompt(data):
    contract_prompt = clean(data.get("prompt"))
    if contract_prompt and not any(
        data.get(key)
        for key in (
            "positive_prompt",
            "decor_elements",
            "decor",
            "theme_tokens",
            "decor_tokens",
            "objects_to_add",
            "transformation_plan",
        )
    ):
        return clean_prompt(f"{contract_prompt}, add decor on top of venue photo")

    plan = build_transformation_plan(data)
    compiled = compile_prompt(plan)
    if compiled:
        return compiled

    base = clean(data.get("positive_prompt") or data.get("prompt"))
    parts = []
    if base:
        parts.append(base)

    if not _contains_phrase(parts, "transform venue"):
        target = " ".join(
            x
            for x in [
                clean(data.get("theme") or data.get("style")),
                clean(data.get("event_type")),
                "reception",
            ]
            if x
        ).strip()
        if target:
            parts.insert(0, f"transform venue into {target}")

    if not _contains_phrase(parts, "banquet tables"):
        parts.append("round banquet tables")

    _append_items(parts, as_list(data.get("decor_elements") or data.get("decor")))
    _append_items(parts, as_list(data.get("theme_tokens")))
    _append_items(parts, as_list(data.get("decor_tokens")))
    _append_items(parts, theme_decor_tokens(data))

    colors = as_list(data.get("color_palette") or data.get("colors"))
    if colors and not any("accent" in p.lower() for p in parts):
        parts.append(f"{', '.join(colors)} accents")

    _append_items(parts, as_list(data.get("lighting_tokens")))

    notes = clean(data.get("custom_instructions") or data.get("notes"))
    if notes:
        _append_items(parts, [notes])

    if not any("photorealistic" in p.lower() for p in parts):
        parts.append("photorealistic")

    return clean_prompt(", ".join(dedupe(parts, 18)))


def build_negative_prompt(data):
    return ", ".join(
        dedupe(GEOMETRY_NEGATIVE + STYLE_NEGATIVE + ARTIFACT_NEGATIVE, 32)
    )


def compile_generation_payload(data):
    intensity = resolve_intensity(data)
    plan = build_transformation_plan(data)
    prompt = compile_prompt(plan)
    strength = get_strength(intensity)
    controlnet = get_controlnet(intensity)
    preprocessor = get_preprocessor(intensity)
    return {
        "prompt": prompt,
        "negative_prompt": build_negative_prompt(data),
        "strength": strength,
        "cfg_scale": 7,
        "steps": 30,
        "controlnet": {
            "enabled": True,
            "conditioning_scale": controlnet,
            "preprocessor": preprocessor,
        },
        "mode": get_mode(intensity),
        "transformation_plan": plan,
    }
