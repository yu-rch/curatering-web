import json
import os
import re
import uuid
from datetime import datetime, timezone

import runpod
from supabase import create_client
from vllm import LLM, SamplingParams

MODEL_NAME = os.getenv("NLP_MODEL_NAME", "mistralai/Mistral-7B-Instruct-v0.2")
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY/SUPABASE_KEY")

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

llm = LLM(
    model=MODEL_NAME,
    dtype="float16",
    gpu_memory_utilization=0.9,
    max_model_len=4096
)

sampling_params = SamplingParams(
    temperature=0.2,
    top_p=0.9,
    max_tokens=512
)


def build_prompt(feedbacks):
    combined = "\n".join([f"- {f}" for f in feedbacks])

    return f"""
[INST] You are a strict JSON generator analyzing customer feedback.

Return ONLY valid JSON. No explanations. No markdown. No extra text.

Schema:

{{
  "sentiment": "positive | negative | neutral | mixed",
  "complaints": ["string"],
  "praises": ["string"],
  "insights": ["string"]
}}

Rules:
- Output MUST be valid JSON
- Output MUST be one JSON object, not an array
- Use double quotes only
- No trailing commas
- complaints, praises, and insights must each be arrays

Feedback:
{combined}
[/INST]
""".strip()


def build_dashboard_prompt(data, alerts, user_prompt=""):
    focus = str(user_prompt or "").strip()
    return f"""
[INST] You are a business analyst AI for a catering and restaurant dashboard.

Analyze this dashboard data and return ONLY valid JSON. No explanations outside JSON. No markdown.

Schema:
{{
  "summary": "string",
  "insights": ["string"],
  "trends": ["string"],
  "problems": ["string"],
  "recommendations": ["string"],
  "alerts": [
    {{
      "type": "string",
      "severity": "info | medium | high",
      "message": "string",
      "explanation": "string"
    }}
  ]
}}

Rules:
- Be concise and structured
- Use double quotes only
- No trailing commas
- Each array should contain at most 5 items
- If an analysis prompt is provided, use it as the main focus while still respecting the dashboard data

Analysis prompt:
{focus if focus else "Use the default dashboard analysis focus."}

Dashboard data:
{json.dumps(data, ensure_ascii=False)}

Detected alerts:
{json.dumps(alerts or [], ensure_ascii=False)}
[/INST]
""".strip()


def build_alert_prompt(alert, data):
    return f"""
[INST] Explain this business alert and return ONLY valid JSON. No markdown.

Schema:
{{
  "summary": "string",
  "insights": ["string"],
  "problems": ["string"],
  "recommendations": ["string"],
  "alerts": [
    {{
      "type": "string",
      "severity": "info | medium | high",
      "message": "string",
      "explanation": "string"
    }}
  ]
}}

Alert:
{alert}

Data:
{json.dumps(data, ensure_ascii=False)}

Provide likely causes, what to check, and recommended actions.
[/INST]
""".strip()


EVENT_THEME_FALLBACKS = {
    "cinderella": {
        "visual_keywords": [
            "royal ballroom",
            "blue and silver palette",
            "glass slipper decor",
            "fairytale lighting",
            "luxury princess aesthetic",
        ],
        "visual_direction": [
            "luxury fairytale princess ballroom",
            "elegant royal blue decor",
            "fairy lights",
            "realistic premium venue styling",
            "Cinderella-inspired centerpiece",
        ],
        "style_tokens": [
            "luxury fairytale princess ballroom",
            "royal blue drapery",
            "silver accents",
            "photorealistic event styling",
        ],
        "lighting_tokens": [
            "fairytale lighting",
            "cinematic lighting",
            "soft elegant glow",
        ],
        "decor_tokens": [
            "glass slipper decor",
            "crystal chandeliers",
            "Cinderella-inspired centerpiece",
            "premium floral centerpieces",
        ],
    },
    "harry potter": {
        "visual_keywords": [
            "floating candles",
            "dark gothic banquet hall",
            "warm magical lighting",
            "castle-inspired decor",
        ],
        "visual_direction": [
            "floating candles",
            "dark gothic banquet hall",
            "warm magical lighting",
            "castle-inspired decor",
        ],
        "style_tokens": [
            "dark academia banquet hall",
            "castle-inspired interior",
            "magical gothic atmosphere",
            "photorealistic event styling",
        ],
        "lighting_tokens": [
            "floating candlelight",
            "warm magical lighting",
            "cinematic shadows",
        ],
        "decor_tokens": [
            "long banquet tables",
            "floating candles",
            "house banners",
            "castle-inspired decor",
        ],
    },
    "garden": {
        "visual_keywords": [
            "lush floral styling",
            "romantic greenery",
            "soft natural lighting",
            "elegant botanical decor",
        ],
        "visual_direction": [
            "romantic garden venue styling",
            "lush floral installations",
            "soft natural lighting",
            "premium botanical decor",
        ],
        "style_tokens": [
            "elegant botanical decor",
            "luxury garden venue",
            "photorealistic event styling",
        ],
        "lighting_tokens": [
            "soft natural lighting",
            "warm ambient glow",
            "cinematic lighting",
        ],
        "decor_tokens": [
            "floral arch",
            "greenery installations",
            "premium floral centerpieces",
        ],
    },
}

EVENT_DECOR_FALLBACKS = {
    ("birthday", "luxurious"): [
        "crystal chandeliers",
        "premium floral centerpieces",
        "elegant stage backdrop",
    ],
    ("wedding", "romantic"): [
        "floral aisle styling",
        "soft candlelit tables",
        "elegant ceremony backdrop",
    ],
}

EVENT_NEGATIVE_TOKENS = [
    "cartoon",
    "anime",
    "warped architecture",
    "warped room",
    "blurry",
    "distorted room",
    "distorted architecture",
    "melted surfaces",
    "duplicate objects",
    "low quality",
    "fisheye",
]

EVENT_TYPE_TEMPLATES = {
    "wedding": {
        "theme_tokens": [
            "elegant wedding reception",
            "symmetrical luxury styling",
            "romantic floral venue",
        ],
        "decor_tokens": [
            "premium floral centerpieces",
            "draped ceiling fabric",
            "crystal chandeliers",
            "elegant ceremony backdrop",
        ],
        "lighting_tokens": [
            "warm candle lighting",
            "soft romantic glow",
            "luxury ambient lighting",
        ],
    },
    "birthday": {
        "theme_tokens": [
            "celebration focal styling",
            "playful luxury event design",
            "centerpiece-focused party venue",
        ],
        "decor_tokens": [
            "statement stage backdrop",
            "premium photo booth",
            "themed centerpiece",
            "balloon and floral accents",
        ],
        "lighting_tokens": [
            "festive cinematic lighting",
            "warm magical glow",
            "spotlit centerpiece",
        ],
    },
    "corporate": {
        "theme_tokens": [
            "modern corporate event venue",
            "minimal premium branding",
            "clean executive styling",
        ],
        "decor_tokens": [
            "branded stage backdrop",
            "minimal floral accents",
            "sleek lounge seating",
            "premium signage",
        ],
        "lighting_tokens": [
            "clean professional lighting",
            "soft neutral illumination",
            "modern stage lighting",
        ],
    },
}

SEMANTIC_DECOR_RECOMMENDATIONS = {
    "luxury wedding": {
        "decor_tokens": [
            "crystal chandeliers",
            "premium floral centerpieces",
            "draped ceiling fabric",
            "warm candle lighting",
        ],
        "lighting_tokens": ["warm candle lighting", "soft romantic glow"],
    },
    "luxurious wedding": {
        "decor_tokens": [
            "crystal chandeliers",
            "premium floral centerpieces",
            "draped ceiling fabric",
            "warm candle lighting",
        ],
        "lighting_tokens": ["warm candle lighting", "soft romantic glow"],
    },
    "luxury birthday": {
        "decor_tokens": [
            "premium backdrop",
            "luxury floral centerpieces",
            "spotlit themed centerpiece",
        ],
        "lighting_tokens": ["festive cinematic lighting", "warm magical glow"],
    },
    "corporate gala": {
        "decor_tokens": [
            "premium branded backdrop",
            "sleek stage design",
            "minimal floral accents",
        ],
        "lighting_tokens": ["clean professional lighting", "modern stage lighting"],
    },
}

STYLE_CONFLICTS = [
    {"cartoon", "anime", "cgi", "illustration"},
    {"minimal", "maximalist", "ornate"},
    {"rustic", "futuristic", "cyberpunk"},
    {"gothic", "pastel garden"},
]

INSTRUCTION_PATTERNS = [
    r"\bplease\b",
    r"\bmake\b",
    r"\bcreate\b",
    r"\bgenerate\b",
    r"\bdesign\b",
    r"\buse\b",
    r"\badd\b",
    r"\bremove\b",
    r"\bshould\b",
    r"\bmust\b",
    r"\bprompt\b",
    r"\bnegative prompt\b",
    r"\bsdxl\b",
    r"\bcontrolnet\b",
]

ARCHITECTURE_HINT_PATTERNS = [
    r"\bpreserve (the )?(room|venue|architecture|geometry|layout)\b",
    r"\bkeep (the )?(room|venue|architecture|geometry|layout)\b",
    r"\bdo not change (the )?(room|venue|architecture|geometry|layout)\b",
    r"\bcorrect architecture\b",
    r"\bstable venue preservation\b",
]


def _clean_text(value):
    return str(value or "").strip()


def _as_list(value, max_items=12):
    if isinstance(value, list):
        items = value
    elif isinstance(value, str):
        items = re.split(r"[,;\n]+", value)
    else:
        items = []
    return [str(item).strip() for item in items if str(item).strip()][:max_items]


def _dedupe(items, max_items=12):
    out = []
    seen = set()
    for item in items:
        text = str(item or "").strip()
        key = text.lower()
        if not text or key in seen:
            continue
        seen.add(key)
        out.append(text)
        if len(out) >= max_items:
            break
    return out


def _sanitize_phrase(value):
    text = _clean_text(value)
    if not text:
        return ""
    text = re.sub(r"[\[\]\{\}\"`]", " ", text)
    text = re.sub(r"\s+", " ", text).strip(" .,:;-")
    lowered = text.lower()
    for pattern in ARCHITECTURE_HINT_PATTERNS:
        lowered = re.sub(pattern, "", lowered, flags=re.IGNORECASE)
    for pattern in INSTRUCTION_PATTERNS:
        lowered = re.sub(pattern, "", lowered, flags=re.IGNORECASE)
    lowered = re.sub(r"\s+", " ", lowered).strip(" .,:;-")
    if not lowered:
        return ""
    return lowered


def _sanitize_list(values, max_items=12):
    return _dedupe([_sanitize_phrase(item) for item in _as_list(values, max_items * 2)], max_items)


def _remove_conflicting_aesthetics(items, max_items=12):
    picked = []
    blocked = set()
    for item in items:
        key = item.lower()
        if any(term in key for term in blocked):
            continue
        picked.append(item)
        for group in STYLE_CONFLICTS:
            matches = [term for term in group if term in key]
            if matches:
                blocked.update(group - set(matches))
        if len(picked) >= max_items:
            break
    return picked


def _event_theme_data(theme, style=""):
    lookup = f"{theme} {style}".strip().lower()
    for key, data in EVENT_THEME_FALLBACKS.items():
        if key in lookup:
            return data
    return {}


def _template_for_event(event_type, prompt=""):
    lookup = f"{event_type} {prompt}".lower()
    for key, data in EVENT_TYPE_TEMPLATES.items():
        if key in lookup:
            return data
    return {}


def _semantic_recommendations(text):
    lookup = text.lower()
    merged = {"decor_tokens": [], "lighting_tokens": []}
    for key, data in SEMANTIC_DECOR_RECOMMENDATIONS.items():
        if key in lookup:
            merged["decor_tokens"].extend(data.get("decor_tokens", []))
            merged["lighting_tokens"].extend(data.get("lighting_tokens", []))
    return merged


def _limit_prompt_tokens(parts, min_tokens=50, max_tokens=120):
    clean = _remove_conflicting_aesthetics(_dedupe(parts, 32), 32)
    filler = [
        "photorealistic interior photography",
        "realistic premium venue styling",
        "elegant event styling",
        "high-end event photography",
        "cinematic lighting",
        "ultra detailed",
    ]
    prompt_parts = _dedupe(clean + filler, 32)
    selected = []
    token_count = 0
    for part in prompt_parts:
        count = len(part.split())
        if selected and token_count + count > max_tokens:
            continue
        selected.append(part)
        token_count += count
        if token_count >= min_tokens:
            break
    if not selected:
        selected = prompt_parts[:8]
    return ", ".join(selected)


def build_event_prompt_expansion_prompt(data):
    return f"""
[INST] You are a semantic planning AI for photorealistic event venue design.

Convert structured event data into SDXL-ready prompt tokens. Return ONLY valid JSON.
No markdown. No explanations. No trailing commas.

Schema:
{{
  "positive_prompt": "string",
  "negative_prompt": "string",
  "theme_tokens": ["string"],
  "decor_tokens": ["string"],
  "lighting_tokens": ["string"],
  "recommended_strength": 0.35
}}

Rules:
- Remove prose, instructions, and non-visual wording.
- Keep dense visual concepts only, like "luxury ballroom, elegant drapery, crystal lighting".
- Do not over-emphasize "preserve room geometry"; use negative_prompt for architecture failures.
- Normalize themes and remove conflicting aesthetics.
- Use event-specific semantics: wedding=elegance/symmetry/florals/luxury lighting; birthday=focal decor/playful styling/centerpiece emphasis; corporate=modern/minimal/premium branding/clean lighting.
- positive_prompt must be comma-separated and roughly 50-120 tokens.
- recommended_strength should normally be 0.35 for venue img2img.

Input:
{json.dumps(data, ensure_ascii=False)}
[/INST]
""".strip()


def normalize_event_prompt_expansion(parsed, source):
    parsed = parsed if isinstance(parsed, dict) else {}
    event_type = _clean_text(source.get("event_type")).lower()
    theme = _clean_text(source.get("theme") or source.get("style"))
    style = _clean_text(source.get("style"))
    mood = _clean_text(source.get("mood")).lower()
    prompt_text = _clean_text(source.get("prompt"))
    notes = _clean_text(
        source.get("notes")
        or source.get("custom_instructions")
        or source.get("prompt")
    )
    colors = _as_list(source.get("colors") or source.get("color_palette"), 8)
    decor = _as_list(source.get("decor") or source.get("decor_elements"), 8)
    theme_data = _event_theme_data(theme, style)
    template = _template_for_event(event_type, f"{theme} {style} {mood} {prompt_text}")
    semantic = _semantic_recommendations(f"{theme} {style} {mood} {prompt_text} {notes}")

    decor_fallback = EVENT_DECOR_FALLBACKS.get((event_type, mood), [])
    theme_tokens = _remove_conflicting_aesthetics(
        _dedupe(
            _sanitize_list(parsed.get("theme_tokens") or parsed.get("style_tokens"), 8)
            + _sanitize_list(parsed.get("visual_direction"), 8)
            + _sanitize_list(parsed.get("visual_keywords"), 8)
            + theme_data.get("style_tokens", [])
            + theme_data.get("visual_keywords", [])
            + template.get("theme_tokens", [])
            + ([f"{event_type} event venue"] if event_type else [])
            + ([f"{mood} atmosphere"] if mood else []),
            8,
        ),
        8,
    )
    lighting_tokens = _dedupe(
        _sanitize_list(parsed.get("lighting_tokens"), 8)
        + theme_data.get("lighting_tokens", [])
        + template.get("lighting_tokens", [])
        + semantic.get("lighting_tokens", [])
        + ["cinematic lighting"],
        8,
    )
    decor_tokens = _dedupe(
        _sanitize_list(parsed.get("decor_tokens") or parsed.get("decor_elements"), 8)
        + decor
        + theme_data.get("decor_tokens", [])
        + template.get("decor_tokens", [])
        + semantic.get("decor_tokens", [])
        + decor_fallback,
        8,
    )
    negative_tokens = _dedupe(
        _as_list(parsed.get("negative_tokens"), 10) + EVENT_NEGATIVE_TOKENS,
        10,
    )

    positive_parts = (
        _sanitize_list(parsed.get("positive_prompt"), 16)
        + theme_tokens
        + ([f"{', '.join(colors)} color palette"] if colors else [])
        + decor_tokens
        + lighting_tokens
        + [
            "realistic premium venue styling",
            "luxury interior photography",
            "photorealistic interior photography",
        ]
    )
    positive_prompt = _limit_prompt_tokens(positive_parts)
    negative_prompt = ", ".join(negative_tokens)
    try:
        strength = float(parsed.get("recommended_strength", 0.35))
    except Exception:
        strength = 0.35
    strength = max(0.30, min(strength, 0.42))

    return {
        "positive_prompt": positive_prompt,
        "negative_prompt": negative_prompt,
        "theme_tokens": theme_tokens,
        "decor_tokens": decor_tokens,
        "lighting_tokens": lighting_tokens,
        "recommended_strength": strength,
    }


def _json_from_substring(text, opener, closer):
    start = text.find(opener)
    end = text.rfind(closer)
    if start < 0 or end <= start:
        return None
    try:
        return json.loads(text[start:end + 1])
    except Exception:
        return None


def extract_json(text):
    text = str(text or "").strip()
    try:
        return json.loads(text)
    except Exception:
        parsed = _json_from_substring(text, "{", "}")
        if parsed is not None:
            return parsed
        parsed = _json_from_substring(text, "[", "]")
        if parsed is not None:
            return parsed
    return None


def _string_list(value, max_items=10):
    if not isinstance(value, list):
        return []
    return [str(item).strip() for item in value if str(item).strip()][:max_items]


def _dashboard_alerts(value):
    if not isinstance(value, list):
        return []
    alerts = []
    for item in value[:8]:
        if isinstance(item, dict):
            message = str(item.get("message") or item.get("summary") or "").strip()
            if not message:
                continue
            alerts.append({
                "type": str(item.get("type") or "alert").strip() or "alert",
                "severity": str(item.get("severity") or "info").strip() or "info",
                "message": message,
                "explanation": str(item.get("explanation") or "").strip(),
            })
        else:
            message = str(item).strip()
            if message:
                alerts.append({
                    "type": "alert",
                    "severity": "info",
                    "message": message,
                    "explanation": "",
                })
    return alerts


def normalize_dashboard_analysis(parsed):
    if not isinstance(parsed, dict):
        return None
    return {
        "summary": str(parsed.get("summary") or "").strip(),
        "insights": _string_list(parsed.get("insights"), 5),
        "trends": _string_list(parsed.get("trends"), 5),
        "problems": _string_list(parsed.get("problems"), 5),
        "recommendations": _string_list(parsed.get("recommendations"), 5),
        "alerts": _dashboard_alerts(parsed.get("alerts")),
    }


def generate_json(prompt):
    outputs = llm.generate([prompt], sampling_params)
    raw_output = outputs[0].outputs[0].text.strip()
    return raw_output, extract_json(raw_output)


def _normalize_analysis_item(parsed):
    if not isinstance(parsed, dict):
        return None
    sentiment = str(parsed.get("sentiment") or "mixed").strip().lower()
    if sentiment not in ("positive", "negative", "neutral", "mixed"):
        sentiment = "mixed"
    return {
        "sentiment": sentiment,
        "complaints": _string_list(parsed.get("complaints")),
        "praises": _string_list(parsed.get("praises")),
        "insights": _string_list(parsed.get("insights")),
    }


def _overall_sentiment(items):
    counts = {"positive": 0, "negative": 0, "neutral": 0, "mixed": 0}
    for item in items:
        counts[item["sentiment"]] = counts.get(item["sentiment"], 0) + 1
    if counts["negative"] > counts["positive"] and counts["negative"] >= counts["neutral"]:
        return "negative"
    if counts["positive"] > counts["negative"] and counts["positive"] >= counts["neutral"]:
        return "positive"
    if counts["neutral"] and counts["neutral"] == len(items):
        return "neutral"
    return "mixed"


def normalize_analysis(parsed):
    if isinstance(parsed, list):
        items = [_normalize_analysis_item(item) for item in parsed]
        items = [item for item in items if item]
        if not items:
            return None
        return {
            "sentiment": _overall_sentiment(items),
            "complaints": _string_list(
                [entry for item in items for entry in item["complaints"]],
                40,
            ),
            "praises": _string_list(
                [entry for item in items for entry in item["praises"]],
                40,
            ),
            "insights": _string_list(
                [entry for item in items for entry in item["insights"]],
                40,
            ),
        }
    return _normalize_analysis_item(parsed)


def fetch_pending_feedback(limit):
    limit = max(1, min(int(limit or 50), 100))
    response = (
        supabase.table("feedback")
        .select("id, message")
        .eq("status", "pending")
        .order("created_at", desc=False)
        .limit(limit)
        .execute()
    )
    return response.data or []


def mark_feedback(rows, status):
    timestamp = datetime.now(timezone.utc).isoformat()
    payload = {"status": status}
    if status == "analyzed":
        payload["analyzed_at"] = timestamp
    for row in rows:
        supabase.table("feedback").update(payload).eq("id", row["id"]).execute()


def store_analysis(rows, feedbacks, analysis):
    batch_id = str(uuid.uuid4())
    feedback_ids = [str(row["id"]) for row in rows if row.get("id")]
    message = "\n".join(feedbacks)

    supabase.table("feedback_analysis").insert({
        "batch_id": batch_id,
        "feedback_ids": feedback_ids,
        "message": message,
        "sentiment": analysis["sentiment"],
        "complaints": analysis["complaints"],
        "praises": analysis["praises"],
        "insights": analysis["insights"],
        "ai_response": analysis,
    }).execute()

    return batch_id


def handler(job):
    data = (job or {}).get("input") or {}
    rows = []

    task_type = str(data.get("task_type") or data.get("task") or "").strip()
    if task_type in ("event_design", "event_prompt_expansion"):
        raw_output, parsed = generate_json(build_event_prompt_expansion_prompt(data))
        result = normalize_event_prompt_expansion(parsed, data)
        return {
            "analysis": result,
            "result": result,
            "positive_prompt": result["positive_prompt"],
            "negative_prompt": result["negative_prompt"],
            "theme_tokens": result["theme_tokens"],
            "decor_tokens": result["decor_tokens"],
            "lighting_tokens": result["lighting_tokens"],
            "recommended_strength": result["recommended_strength"],
            "raw_output": raw_output if not isinstance(parsed, dict) else None,
        }

    if isinstance(data.get("dashboard_data"), dict):
        raw_output, parsed = generate_json(
            build_dashboard_prompt(
                data["dashboard_data"],
                data.get("alerts") or [],
                data.get("prompt") or data["dashboard_data"].get("prompt") or "",
            )
        )
        result = normalize_dashboard_analysis(parsed)
        if not result:
            return {"error": "Model did not return valid JSON", "raw_output": raw_output}
        return {"analysis": result, "result": result}

    if data.get("alert"):
        raw_output, parsed = generate_json(
            build_alert_prompt(str(data.get("alert")), data.get("data") or {})
        )
        result = normalize_dashboard_analysis(parsed)
        if not result:
            return {"error": "Model did not return valid JSON", "raw_output": raw_output}
        return {"analysis": result, "result": result}

    direct_feedbacks = data.get("feedbacks")
    if isinstance(direct_feedbacks, list) and direct_feedbacks:
        feedbacks = [str(item).strip() for item in direct_feedbacks if str(item).strip()]
    else:
        rows = fetch_pending_feedback(data.get("limit", 50))
        if not rows:
            return {"processed": 0, "message": "No pending feedback found", "result": None}
        feedbacks = [str(row.get("message") or "").strip() for row in rows]

    feedbacks = [item for item in feedbacks if item]
    if not feedbacks:
        if rows:
            mark_feedback(rows, "error")
        return {"error": "No feedback text found"}

    prompt = build_prompt(feedbacks)

    raw_output, raw_json = generate_json(prompt)
    parsed = normalize_analysis(raw_json)
    if not parsed:
        if rows:
            mark_feedback(rows, "error")
        return {
            "error": "Model did not return valid JSON",
            "raw_output": raw_output
        }

    batch_id = store_analysis(rows, feedbacks, parsed)
    if rows:
        mark_feedback(rows, "analyzed")

    return {
        "batch_id": batch_id,
        "processed": len(feedbacks),
        "analysis": parsed,
        "result": parsed
    }


runpod.serverless.start({"handler": handler})