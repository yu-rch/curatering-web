import gc
import json
import os
import re
import traceback
import uuid
from collections import Counter
from datetime import datetime, timezone

os.environ["VLLM_WORKER_MULTIPROC_METHOD"] = "spawn"
os.environ["TOKENIZERS_PARALLELISM"] = "false"

import runpod
import torch
from supabase import create_client
from vllm import LLM, SamplingParams

# =========================================================
# CONFIG
# =========================================================

MODEL_NAME = os.getenv(
    "NLP_MODEL_NAME",
    "mistralai/Mistral-7B-Instruct-v0.2"
)

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = (
    os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    or os.getenv("SUPABASE_KEY")
)

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError(
        "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY"
    )

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# =========================================================
# VLLM
# =========================================================

print("Loading NLP model...")

llm = LLM(
    model=MODEL_NAME,
    dtype="float16",
    gpu_memory_utilization=0.72,
    max_model_len=2048,
    enforce_eager=True,
    trust_remote_code=True,
)

sampling_params = SamplingParams(
    temperature=0.2,
    top_p=0.9,
    max_tokens=350,
)

print("NLP model loaded.")

# =========================================================
# HELPERS
# =========================================================

def clean_text(value):
    return str(value or "").strip()


def string_list(value, max_items=20):

    if not isinstance(value, list):
        return []

    return [
        str(v).strip()
        for v in value
        if str(v).strip()
    ][:max_items]


def extract_json(text):

    text = str(text or "").strip()

    try:
        return json.loads(text)
    except Exception:
        pass

    try:
        match = re.search(r"\{.*\}", text, re.DOTALL)

        if match:
            return json.loads(match.group(0))
    except Exception:
        pass

    return None


def make_json_safe(data):
    return json.loads(json.dumps(data))


def generate_json(prompt):

    outputs = llm.generate([prompt], sampling_params)

    raw = outputs[0].outputs[0].text.strip()

    parsed = extract_json(raw)

    gc.collect()
    torch.cuda.empty_cache()

    return raw, parsed


# =========================================================
# FEEDBACK ANALYSIS
# =========================================================

def build_feedback_prompt(feedbacks):

    combined = "\n".join(
        [f"- {f}" for f in feedbacks]
    )

    return f"""
[INST]
You are a customer feedback analysis AI.

Return ONLY valid JSON.

Schema:
{{
  "sentiment": "positive | negative | neutral | mixed",
  "complaints": ["string"],
  "praises": ["string"],
  "insights": ["string"],
  "recommendations": ["string"]
}}

Feedback:
{combined}
[/INST]
""".strip()


# =========================================================
# DASHBOARD ANALYSIS
# =========================================================

def build_dashboard_prompt(data):

    return f"""
[INST]
You are a business intelligence AI for a catering and restaurant platform.

Analyze:
- sales trends
- customer behavior
- order trends
- operations
- business opportunities
- risks
- popular dishes

Return ONLY valid JSON.

Schema:
{{
  "summary": "string",
  "explainability": ["specific detected factor, metric, or change"],
  "insights": ["string"],
  "trends": ["string"],
  "problems": ["string"],
  "recommendations": ["string"],
  "alerts": [
    {{
      "severity": "info | medium | high",
      "message": "string",
      "explanation": "string"
    }}
  ]
}}

Dashboard Data:
{json.dumps(data, ensure_ascii=False)}
[/INST]
""".strip()


# =========================================================
# DISH TREND ANALYSIS
# =========================================================

def aggregate_dish_trends(rows):

    counter = {}
    revenue = {}

    for row in rows:

        dish = clean_text(
            row.get("dish_name")
        )

        if not dish:
            continue

        qty = float(row.get("quantity") or 1)
        price = float(row.get("price") or 0)

        counter[dish] = (
            counter.get(dish, 0) + qty
        )

        revenue[dish] = (
            revenue.get(dish, 0.0)
            + (qty * price)
        )

    sorted_dishes = sorted(
        counter.items(),
        key=lambda x: x[1],
        reverse=True
    )

    top_dishes = []

    for dish, count in sorted_dishes[:10]:

        top_dishes.append({
            "dish": dish,
            "orders": round(count, 2),
            "revenue": round(
                revenue.get(dish, 0.0),
                2
            )
        })

    return {
        "top_dishes": top_dishes,
        "dish_count": len(counter)
    }


def build_dish_trend_prompt(data):

    return f"""
[INST]
You are a restaurant analytics AI.

Analyze dish ordering trends.

Return ONLY valid JSON.

Schema:
{{
  "summary": "string",
  "popular_dishes": ["string"],
  "declining_dishes": ["string"],
  "seasonal_patterns": ["string"],
  "recommendations": ["string"]
}}

Dish trend data:
{json.dumps(data, ensure_ascii=False)}
[/INST]
""".strip()


# =========================================================
# EVENT PROMPT EXPANSION
# =========================================================

def token_list(*values, max_items=12):

    items = []

    for value in values:

        if isinstance(value, list):
            items.extend(value)
        elif clean_text(value):
            items.append(value)

    normalized = []

    for item in items:

        text = clean_text(item)

        if text and text not in normalized:
            normalized.append(text)

    return normalized[:max_items]


def fallback_event_prompt(data):

    event_type = clean_text(data.get("event_type") or "event")
    theme = clean_text(data.get("theme") or data.get("style"))
    mood = clean_text(data.get("mood"))
    colors = token_list(data.get("colors"), data.get("color_palette"))
    decor = token_list(data.get("decor"), data.get("decor_elements"))
    notes = clean_text(data.get("notes") or data.get("custom_instructions"))

    parts = [
        f"{event_type} event venue",
        f"{theme} theme" if theme else "",
        f"{mood} atmosphere" if mood else "",
        f"{', '.join(colors)} color palette" if colors else "",
        f"{', '.join(decor)} decorations" if decor else "",
        notes,
        "photorealistic luxury event styling",
        "realistic venue decorations",
        "cinematic lighting",
    ]

    return ", ".join([p for p in parts if p])


def build_event_prompt_expansion_prompt(data):

    return f"""
[INST]
You expand structured event design data into stable SDXL prompts.

Return ONLY valid JSON.

Schema:
{{
  "positive_prompt": "string",
  "negative_prompt": "string",
  "theme_tokens": ["string"],
  "style_tokens": ["string"],
  "lighting_tokens": ["string"],
  "decor_tokens": ["string"],
  "decor_elements": ["string"],
  "visual_keywords": ["string"],
  "recommended_strength": 0.58
}}

Rules:
- Preserve the venue layout and realistic architecture.
- Use the event type, theme, mood, colors, decor, and notes as semantic tokens.
- Keep positive_prompt concise but detailed enough for SDXL.
- Avoid text, logos, watermarks, distorted rooms, and cartoon rendering.

Event config:
{json.dumps(data, ensure_ascii=False)}
[/INST]
""".strip()


def normalize_event_prompt_expansion(parsed, data):

    source = parsed if isinstance(parsed, dict) else {}
    fallback_prompt = fallback_event_prompt(data)
    try:
        recommended_strength = float(source.get("recommended_strength") or 0.58)
    except Exception:
        recommended_strength = 0.58
    positive_prompt = clean_text(
        source.get("positive_prompt")
        or source.get("prompt")
        or fallback_prompt
    )
    negative_prompt = clean_text(
        source.get("negative_prompt")
        or "warped architecture, distorted room, melted surfaces, duplicate objects, blurry, low quality, cartoon, CGI, fisheye, text, watermark"
    )
    theme = clean_text(data.get("theme") or data.get("style"))
    mood = clean_text(data.get("mood"))

    return {
        "positive_prompt": positive_prompt,
        "negative_prompt": negative_prompt,
        "theme_tokens": string_list(
            source.get("theme_tokens"),
            12
        ) or token_list(data.get("event_type"), theme),
        "style_tokens": string_list(
            source.get("style_tokens"),
            12
        ) or token_list(theme),
        "lighting_tokens": string_list(
            source.get("lighting_tokens"),
            12
        ) or token_list(mood),
        "decor_tokens": string_list(
            source.get("decor_tokens"),
            12
        ) or token_list(data.get("decor"), data.get("decor_elements")),
        "decor_elements": string_list(
            source.get("decor_elements"),
            12
        ) or token_list(data.get("decor"), data.get("decor_elements")),
        "visual_keywords": string_list(
            source.get("visual_keywords") or source.get("visual_direction"),
            12
        ),
        "recommended_strength": min(
            0.65,
            max(
                0.50,
                recommended_strength
            )
        ),
    }


# =========================================================
# ALERT DETECTION
# =========================================================

def detect_dashboard_alerts(data):

    alerts = []

    sales_today = float(
        data.get("sales_today") or 0
    )

    sales_yesterday = float(
        data.get("sales_yesterday") or 0
    )

    if sales_yesterday > 0:

        diff = (
            (
                sales_today - sales_yesterday
            )
            / sales_yesterday
        ) * 100

        if diff <= -30:

            alerts.append({
                "severity": "high",
                "message": "Sales dropped significantly",
                "explanation": f"Sales decreased by {round(abs(diff), 1)}%"
            })

    pending_orders = int(
        data.get("pending_orders") or 0
    )

    if pending_orders >= 30:

        alerts.append({
            "severity": "medium",
            "message": "High pending orders",
            "explanation": "Kitchen operations may be overloaded"
        })

    low_stock_items = (
        data.get("low_stock_items") or []
    )

    if len(low_stock_items) >= 5:

        alerts.append({
            "severity": "medium",
            "message": "Low stock warning",
            "explanation": "Several ingredients are running low"
        })

    return alerts


# =========================================================
# SUPABASE HELPERS
# =========================================================

def fetch_pending_feedback(limit=50):

    limit = max(
        1,
        min(int(limit), 100)
    )

    response = (
        supabase.table("feedback")
        .select("id, message")
        .eq("status", "pending")
        .limit(limit)
        .execute()
    )

    return response.data or []


def mark_feedback(rows, status):

    timestamp = (
        datetime.now(timezone.utc)
        .isoformat()
    )

    payload = {
        "status": status,
        "analyzed_at": timestamp,
    }

    for row in rows:

        supabase.table("feedback").update(
            payload
        ).eq(
            "id",
            row["id"]
        ).execute()


# =========================================================
# ORDER DATA
# =========================================================

def fetch_dish_orders():

    catering_rows = (
        supabase.table("catering_order_items")
        .select("*")
        .execute()
    )

    restaurant_rows = (
        supabase.table("restaurant_order_items")
        .select("*")
        .execute()
    )

    return (
        (catering_rows.data or [])
        + (restaurant_rows.data or [])
    )


# =========================================================
# NORMALIZERS
# =========================================================

def normalize_dashboard_result(parsed):

    if not isinstance(parsed, dict):
        return None

    return {
        "summary": clean_text(
            parsed.get("summary")
        ),
        "explainability": string_list(
            parsed.get("explainability")
            or parsed.get("explanation_points")
            or parsed.get("detected_factors"),
            10
        ),
        "insights": string_list(
            parsed.get("insights"),
            5
        ),
        "trends": string_list(
            parsed.get("trends"),
            5
        ),
        "problems": string_list(
            parsed.get("problems"),
            5
        ),
        "recommendations": string_list(
            parsed.get("recommendations"),
            5
        ),
        "alerts": parsed.get("alerts") or [],
    }


def normalize_dish_trend_result(parsed):

    if not isinstance(parsed, dict):
        return None

    return {
        "summary": clean_text(
            parsed.get("summary")
        ),
        "popular_dishes": string_list(
            parsed.get("popular_dishes"),
            10
        ),
        "declining_dishes": string_list(
            parsed.get("declining_dishes"),
            10
        ),
        "seasonal_patterns": string_list(
            parsed.get("seasonal_patterns"),
            10
        ),
        "recommendations": string_list(
            parsed.get("recommendations"),
            10
        ),
    }


def normalize_feedback_result(parsed):

    if not isinstance(parsed, dict):
        return None

    sentiment = clean_text(
        parsed.get("sentiment")
    ).lower()

    if sentiment not in (
        "positive",
        "negative",
        "neutral",
        "mixed"
    ):
        sentiment = "mixed"

    return {
        "sentiment": sentiment,
        "complaints": string_list(
            parsed.get("complaints"),
            20
        ),
        "praises": string_list(
            parsed.get("praises"),
            20
        ),
        "insights": string_list(
            parsed.get("insights"),
            20
        ),
        "recommendations": string_list(
            parsed.get("recommendations"),
            20
        ),
    }


# =========================================================
# MAIN HANDLER
# =========================================================

def handler(job):

    try:

        data = (
            (job or {}).get("input")
            or {}
        )

        task = clean_text(
            data.get("task_type")
            or data.get("task")
        )

        print(f"Task: {task}")

        # =================================================
        # HEALTH CHECK
        # =================================================

        if task == "health_check":

            cuda_available = torch.cuda.is_available()
            gpu_name = ""

            if cuda_available:

                try:
                    gpu_name = torch.cuda.get_device_name(0)
                except Exception:
                    gpu_name = ""

            return {
                "status": "success",
                "message": "NLP service healthy",
                "model": MODEL_NAME,
                "cuda": cuda_available,
                "gpu": gpu_name,
                "nlp_online": True,
            }

        # =================================================
        # FEEDBACK ANALYSIS
        # =================================================

        if task == "feedback_analysis":

            rows = fetch_pending_feedback(
                data.get("limit", 50)
            )

            if not rows:

                return {
                    "status": "success",
                    "message": "No pending feedback"
                }

            feedbacks = [
                clean_text(r.get("message"))
                for r in rows
                if clean_text(r.get("message"))
            ]

            prompt = build_feedback_prompt(
                feedbacks
            )

            raw, parsed = generate_json(
                prompt
            )

            result = normalize_feedback_result(
                parsed
            )

            if not result:

                mark_feedback(rows, "error")

                return {
                    "status": "error",
                    "message": "Invalid model JSON",
                    "raw_output": raw,
                }

            mark_feedback(rows, "analyzed")

            return make_json_safe({
                "status": "success",
                "processed": len(feedbacks),
                "analysis": result,
            })

        # =================================================
        # DASHBOARD ANALYSIS
        # =================================================

        if task == "dashboard_analysis":

            dashboard_data = (
                data.get("dashboard_data")
                or {}
            )

            dashboard_data["detected_alerts"] = (
                detect_dashboard_alerts(
                    dashboard_data
                )
            )

            prompt = build_dashboard_prompt(
                dashboard_data
            )

            raw, parsed = generate_json(
                prompt
            )

            result = normalize_dashboard_result(
                parsed
            )

            if not result:

                return {
                    "status": "error",
                    "message": "Invalid model JSON",
                    "raw_output": raw,
                }

            return make_json_safe({
                "status": "success",
                "analysis": result,
            })

        # =================================================
        # DISH TRENDS
        # =================================================

        if task == "dish_trends":

            rows = fetch_dish_orders()

            aggregated = aggregate_dish_trends(
                rows
            )

            prompt = build_dish_trend_prompt(
                aggregated
            )

            raw, parsed = generate_json(
                prompt
            )

            result = normalize_dish_trend_result(
                parsed
            )

            if not result:

                return {
                    "status": "error",
                    "message": "Invalid model JSON",
                    "raw_output": raw,
                }

            return make_json_safe({
                "status": "success",
                "aggregated": aggregated,
                "analysis": result,
            })

        # =================================================
        # EVENT PROMPT EXPANSION
        # =================================================

        if task in (
            "event_prompt_expansion",
            "event_design"
        ):

            prompt = build_event_prompt_expansion_prompt(
                data
            )

            raw, parsed = generate_json(
                prompt
            )

            result = normalize_event_prompt_expansion(
                parsed,
                data
            )

            return make_json_safe({
                "status": "success",
                **result,
                "raw_output": raw,
            })

        # =================================================
        # UNKNOWN TASK
        # =================================================

        return {
            "status": "error",
            "message": f"Unknown task type: {task}"
        }

    except Exception as e:

        gc.collect()

        try:
            torch.cuda.empty_cache()
        except Exception:
            pass

        return {
            "status": "error",
            "message": str(e),
            "traceback": traceback.format_exc()[-4000:]
        }


# =========================================================
# START
# =========================================================

print("Starting NLP Analytics AI...")

runpod.serverless.start({
    "handler": handler
})