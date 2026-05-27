import re

# =========================================================
# THEME MAP
# =========================================================

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

# =========================================================
# NEGATIVE PROMPT
# =========================================================

NEGATIVE_PROMPT = [
    "warped architecture",
    "distorted room",
    "crooked walls",
    "fisheye",
    "bad perspective",
    "warped ceiling",
    "melted surfaces",
    "cartoon",
    "anime",
    "cgi",
    "illustration",
    "duplicate objects",
    "floating decor",
    "blurry",
    "low quality",
    "watermark",
    "logo",
    "text",
]

# =========================================================
# SAFE HELPERS
# =========================================================

def clean(v):
    if v is None:
        return ""
    if isinstance(v, (list, tuple, set)):
        return ", ".join(clean(x) for x in v if x)
    return str(v).strip()


def as_list(v):
    if isinstance(v, (list, tuple, set)):
        return [clean(x) for x in v if clean(x)]
    v = clean(v)
    if not v:
        return []
    return [x.strip() for x in v.split(",") if x.strip()]


def dedupe(items, limit=30):
    out = []
    seen = set()
    for i in items:
        t = clean(i)
        if not t:
            continue
        k = t.lower()
        if k in seen:
            continue
        seen.add(k)
        out.append(t)
        if len(out) >= limit:
            break
    return out


def clamp(x, a, b):
    return max(a, min(b, x))


# =========================================================
# INTENSITY CONTROL
# =========================================================

def resolve_intensity(data):
    v = data.get("intensity", data.get("transformation_intensity", 0.8))
    try:
        return clamp(float(v), 0, 1)
    except:
        return 0.8


def get_strength(i):
    if i < 0.4:
        return 0.75
    if i < 0.7:
        return 0.82
    return 0.9


def get_controlnet(i):
    if i < 0.4:
        return 0.85
    if i < 0.7:
        return 0.65
    return 0.55


def get_mode(i):
    if i < 0.4:
        return "preserve"
    if i < 0.7:
        return "modify"
    return "rebuild"


def controlnet_scale_for_denoise(strength):
    # compatibility helper used by handler
    if strength < 0.8:
        return 0.3
    if strength < 0.86:
        return 0.55
    return 0.8


# =========================================================
# THEME DECOR
# =========================================================

def theme_decor_tokens(data):
    text = " ".join([
        clean(data.get("theme")),
        clean(data.get("style")),
        clean(data.get("mood")),
        clean(data.get("prompt")),
        clean(data.get("notes")),
    ]).lower()

    tokens = []
    for key, values in THEME_DECOR_MAP.items():
        if key in text:
            tokens.extend(values)

    return dedupe(tokens)


# =========================================================
# PROMPT BUILDING
# =========================================================

def build_prompt(data):
    base = clean(data.get("prompt") or data.get("positive_prompt"))
    theme = clean(data.get("theme") or data.get("style") or "themed event")

    parts = []

    if base:
        parts.append(base)

    parts.append(f"transform venue into {theme} event")
    parts.append("add decor on top of venue photo")
    parts.append("empty floor to be filled with event furniture")

    parts.extend(theme_decor_tokens(data))

    parts.append("round banquet tables")
    parts.append("chairs surrounding tables")
    parts.append("photorealistic architecture, correct scale, realistic lighting")

    return ", ".join(dedupe(parts))


def build_negative_prompt():
    return ", ".join(dedupe(NEGATIVE_PROMPT))


# =========================================================
# MAIN ENTRY
# =========================================================

def compile_generation_payload(data):
    intensity = resolve_intensity(data)

    strength = get_strength(intensity)
    controlnet = get_controlnet(intensity)

    prompt = build_prompt(data)

    return {
        "prompt": prompt,
        "negative_prompt": build_negative_prompt(),
        "strength": strength,
        "cfg_scale": 7,
        "steps": 30,
        "controlnet": {
            "enabled": True,
            "conditioning_scale": controlnet,
            "preprocessor": "depth",
        },
        "mode": get_mode(intensity),
    }