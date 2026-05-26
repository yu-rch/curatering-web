import gc
import json
import os
import re
import traceback
from datetime import datetime, timezone

os.environ["CUDA_MODULE_LOADING"] = "LAZY"
os.environ["VLLM_WORKER_MULTIPROC_METHOD"] = "spawn"
os.environ["TOKENIZERS_PARALLELISM"] = "false"

import runpod
import torch
from supabase import create_client
from vllm import LLM, SamplingParams

# =========================================================
# PERFORMANCE SETTINGS
# =========================================================

torch.backends.cuda.matmul.allow_tf32 = True
torch.set_float32_matmul_precision("high")

# =========================================================
# CONFIG
# =========================================================

MODEL_NAME = os.getenv(
    "NLP_MODEL_NAME",
    "microsoft/Phi-3-mini-4k-instruct"
)

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = (
    os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    or os.getenv("SUPABASE_KEY")
)

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError(
        "Missing SUPABASE credentials"
    )

supabase = create_client(
    SUPABASE_URL,
    SUPABASE_KEY
)

# =========================================================
# LOAD MODEL
# =========================================================

print("====================================")
print("Loading NLP model...")
print("MODEL:", MODEL_NAME)
print("CUDA:", torch.cuda.is_available())

if torch.cuda.is_available():
    print("GPU:", torch.cuda.get_device_name(0))

print("====================================")

llm = LLM(
    model=MODEL_NAME,
    dtype="float16",
    gpu_memory_utilization=0.60,
    max_model_len=1024,
    trust_remote_code=True,
    enforce_eager=True,
)

sampling_params = SamplingParams(
    temperature=0.15,
    top_p=0.9,
    max_tokens=300,
)

print("NLP model loaded successfully.")

# =========================================================
# HELPERS
# =========================================================

def clean_text(value):

    return str(value or "").strip()


def safe_list(value, limit=20):

    if not isinstance(value, list):
        return []

    output = []

    for item in value:

        text = clean_text(item)

        if text:
            output.append(text)

    return output[:limit]


def make_json_safe(data):

    return json.loads(
        json.dumps(data)
    )


def extract_json(text):

    text = str(text or "").strip()

    try:
        return json.loads(text)
    except Exception:
        pass

    try:

        match = re.search(
            r"\{.*\}",
            text,
            re.DOTALL
        )

        if match:
            return json.loads(match.group(0))

    except Exception:
        pass

    return None


def cleanup():

    gc.collect()

    if torch.cuda.is_available():

        try:
            torch.cuda.empty_cache()
        except Exception:
            pass


# =========================================================
# MODEL GENERATION
# =========================================================

def generate_json(prompt):

    outputs = llm.generate(
        [prompt],
        sampling_params
    )

    raw = outputs[0].outputs[0].text.strip()

    parsed = extract_json(raw)

    cleanup()

    return raw, parsed


# =========================================================
# FEEDBACK ANALYSIS
# =========================================================

def build_feedback_prompt(feedbacks):

    combined = "\n".join([
        f"- {x}"
        for x in feedbacks
    ])

    return f"""
<|user|>
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

<|assistant|>
""".strip()


def normalize_feedback(parsed):

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
        "complaints": safe_list(
            parsed.get("complaints")
        ),
        "praises": safe_list(
            parsed.get("praises")
        ),
        "insights": safe_list(
            parsed.get("insights")
        ),
        "recommendations": safe_list(
            parsed.get("recommendations")
        ),
    }


# =========================================================
# DASHBOARD ANALYSIS
# =========================================================

def build_dashboard_prompt(data):

    return f"""
<|user|>
You are an AI business intelligence assistant.

Analyze:
- sales
- operations
- order trends
- customer behavior
- revenue trends
- risks
- opportunities

Return ONLY valid JSON.

Schema:
{{
  "summary": "string",
  "insights": ["string"],
  "trends": ["string"],
  "problems": ["string"],
  "recommendations": ["string"],
  "alerts": [
    {{
      "severity": "info | medium | high",
      "message": "string"
    }}
  ]
}}

Dashboard data:
{json.dumps(data, ensure_ascii=False)}

<|assistant|>
""".strip()


def normalize_dashboard(parsed):

    if not isinstance(parsed, dict):
        return None

    return {
        "summary": clean_text(
            parsed.get("summary")
        ),
        "insights": safe_list(
            parsed.get("insights")
        ),
        "trends": safe_list(
            parsed.get("trends")
        ),
        "problems": safe_list(
            parsed.get("problems")
        ),
        "recommendations": safe_list(
            parsed.get("recommendations")
        ),
        "alerts": parsed.get("alerts") or [],
    }


# =========================================================
# EVENT PROMPT EXPANSION
# =========================================================

def fallback_prompt(data):

    event_type = clean_text(
        data.get("event_type")
    )

    theme = clean_text(
        data.get("theme")
        or data.get("style")
    )

    mood = clean_text(
        data.get("mood")
    )

    colors = safe_list(
        data.get("colors")
        or data.get("color_palette")
    )

    decor = safe_list(
        data.get("decor")
        or data.get("decor_elements")
    )

    return ", ".join([
        x for x in [
            f"{event_type} luxury venue"
            if event_type else "",

            f"{theme} theme"
            if theme else "",

            f"{mood} atmosphere"
            if mood else "",

            f"{', '.join(colors)} palette"
            if colors else "",

            f"{', '.join(decor)} decorations"
            if decor else "",

            "photorealistic",
            "cinematic lighting",
            "luxury event styling",
        ]
        if x
    ])


def build_event_prompt(data):

    return f"""
<|user|>
You are an SDXL event design prompt engineer.

Generate optimized SDXL prompts.

Return ONLY valid JSON.

Schema:
{{
  "positive_prompt": "string",
  "negative_prompt": "string",
  "theme_tokens": ["string"],
  "style_tokens": ["string"],
  "lighting_tokens": ["string"],
  "decor_tokens": ["string"],
  "recommended_strength": 0.58
}}

Rules:
- Keep architecture realistic
- Preserve venue layout
- Avoid distorted geometry
- Avoid cartoons
- Optimize for SDXL realism

Event Data:
{json.dumps(data, ensure_ascii=False)}

<|assistant|>
""".strip()


def normalize_event(parsed, data):

    if not isinstance(parsed, dict):

        return {
            "positive_prompt": fallback_prompt(data),
            "negative_prompt": (
                "distorted room, warped walls, "
                "blurry, cartoon, text, watermark"
            ),
            "theme_tokens": [],
            "style_tokens": [],
            "lighting_tokens": [],
            "decor_tokens": [],
            "recommended_strength": 0.58,
        }

    return {
        "positive_prompt": clean_text(
            parsed.get("positive_prompt")
        ) or fallback_prompt(data),

        "negative_prompt": clean_text(
            parsed.get("negative_prompt")
        ) or (
            "distorted room, warped walls, "
            "blurry, cartoon, text, watermark"
        ),

        "theme_tokens": safe_list(
            parsed.get("theme_tokens"),
            12
        ),

        "style_tokens": safe_list(
            parsed.get("style_tokens"),
            12
        ),

        "lighting_tokens": safe_list(
            parsed.get("lighting_tokens"),
            12
        ),

        "decor_tokens": safe_list(
            parsed.get("decor_tokens"),
            12
        ),

        "recommended_strength": min(
            0.65,
            max(
                0.50,
                float(
                    parsed.get(
                        "recommended_strength",
                        0.58
                    )
                )
            )
        )
    }


# =========================================================
# SUPABASE HELPERS
# =========================================================

def fetch_pending_feedback(limit=50):

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

    for row in rows:

        (
            supabase.table("feedback")
            .update({
                "status": status,
                "analyzed_at": timestamp,
            })
            .eq("id", row["id"])
            .execute()
        )


# =========================================================
# HANDLER
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

        print("====================================")
        print("TASK:", task)
        print("====================================")

        # =================================================
        # HEALTH CHECK
        # =================================================

        if task == "health_check":

            return {
                "status": "success",
                "model": MODEL_NAME,
                "cuda": torch.cuda.is_available(),
                "gpu": (
                    torch.cuda.get_device_name(0)
                    if torch.cuda.is_available()
                    else None
                )
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
                clean_text(
                    row.get("message")
                )
                for row in rows
            ]

            prompt = build_feedback_prompt(
                feedbacks
            )

            raw, parsed = generate_json(
                prompt
            )

            result = normalize_feedback(
                parsed
            )

            if not result:

                mark_feedback(
                    rows,
                    "error"
                )

                return {
                    "status": "error",
                    "message": "Invalid JSON output",
                    "raw_output": raw,
                }

            mark_feedback(
                rows,
                "analyzed"
            )

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

            prompt = build_dashboard_prompt(
                dashboard_data
            )

            raw, parsed = generate_json(
                prompt
            )

            result = normalize_dashboard(
                parsed
            )

            if not result:

                return {
                    "status": "error",
                    "message": "Invalid JSON output",
                    "raw_output": raw,
                }

            return make_json_safe({
                "status": "success",
                "analysis": result,
            })

        # =================================================
        # EVENT PROMPT EXPANSION
        # =================================================

        if task in (
            "event_prompt_expansion",
            "event_design"
        ):

            prompt = build_event_prompt(
                data
            )

            raw, parsed = generate_json(
                prompt
            )

            result = normalize_event(
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
            "message": f"Unknown task: {task}"
        }

    except Exception as e:

        cleanup()

        return {
            "status": "error",
            "message": str(e),
            "traceback": traceback.format_exc()[-4000:]
        }


# =========================================================
# START
# =========================================================

print("Starting NLP AI Service...")

runpod.serverless.start({
    "handler": handler
})