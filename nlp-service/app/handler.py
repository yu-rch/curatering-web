import gc
import json
import os
import traceback
import time
from datetime import datetime, timezone

# =========================================================
# ENV
# =========================================================

os.environ["CUDA_MODULE_LOADING"] = "LAZY"
os.environ["VLLM_WORKER_MULTIPROC_METHOD"] = "spawn"
os.environ["TOKENIZERS_PARALLELISM"] = "false"
os.environ["VLLM_LOGGING_LEVEL"] = "ERROR"
os.environ["CUDA_LAUNCH_BLOCKING"] = "0"

# =========================================================
# IMPORTS
# =========================================================

import runpod
import torch
from supabase import create_client
from vllm import LLM, SamplingParams

# =========================================================
# PERFORMANCE
# =========================================================

torch.backends.cuda.matmul.allow_tf32 = True
torch.set_float32_matmul_precision("high")

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
    raise ValueError("Missing Supabase credentials")

supabase = create_client(
    SUPABASE_URL,
    SUPABASE_KEY
)

# =========================================================
# MODEL
# =========================================================

llm = None

def get_llm():

    global llm

    if llm is None:

        print("====================================")
        print("Loading Mistral model...")
        print("MODEL:", MODEL_NAME)
        print("CUDA:", torch.cuda.is_available())

        if torch.cuda.is_available():
            print("GPU:", torch.cuda.get_device_name(0))

        print("====================================")

        llm = LLM(
            model=MODEL_NAME,
            dtype="float16",
            gpu_memory_utilization=0.75,
            max_model_len=2048,
            trust_remote_code=True,
            enforce_eager=False,
        )

        warmup()

        print("Model loaded successfully")

    return llm

# =========================================================
# SAMPLING
# =========================================================

sampling_params = SamplingParams(
    temperature=0.15,
    top_p=0.9,
    max_tokens=300,
)

# =========================================================
# HELPERS
# =========================================================

def cleanup():

    gc.collect()

    if torch.cuda.is_available():

        try:
            torch.cuda.empty_cache()
            torch.cuda.synchronize()
        except Exception:
            pass


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

    start = text.find("{")
    end = text.rfind("}")

    if start != -1 and end != -1:

        try:
            return json.loads(
                text[start:end + 1]
            )

        except Exception:
            return None

    return None


# =========================================================
# WARMUP
# =========================================================

def warmup():

    try:

        print("Warming up model...")

        get_llm().generate(
            ['Return JSON: {"status":"ok"}'],
            sampling_params
        )

        print("Warmup complete")

    except Exception as e:

        print("Warmup failed:", e)


# =========================================================
# GENERATION
# =========================================================

def generate_json(prompt):

    model = get_llm()

    start = time.time()

    outputs = model.generate(
        [prompt],
        sampling_params
    )

    elapsed = time.time() - start

    if elapsed > 25:
        print(f"Slow generation: {elapsed:.2f}s")

    raw = outputs[0].outputs[0].text.strip()

    parsed = extract_json(raw)

    cleanup()

    return raw, parsed


# =========================================================
# FEEDBACK
# =========================================================

def build_feedback_prompt(feedbacks):

    combined = "\n".join([
        f"- {x}"
        for x in feedbacks
    ])

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
# DASHBOARD
# =========================================================

def build_dashboard_prompt(data):

    return f"""
[INST]
You are an AI business intelligence assistant.

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

Dashboard Data:
{json.dumps(data, ensure_ascii=False)}
[/INST]
""".strip()


def normalize_dashboard(parsed):

    if not isinstance(parsed, dict):
        return None

    return {
        "summary": clean_text(parsed.get("summary")),
        "insights": safe_list(parsed.get("insights")),
        "trends": safe_list(parsed.get("trends")),
        "problems": safe_list(parsed.get("problems")),
        "recommendations": safe_list(parsed.get("recommendations")),
        "alerts": parsed.get("alerts") or [],
    }


# =========================================================
# EVENT PROMPT
# =========================================================

def fallback_prompt(data):

    return ", ".join([
        clean_text(data.get("event_type")),
        clean_text(data.get("theme")),
        clean_text(data.get("mood")),
        "luxury event",
        "cinematic lighting",
        "photorealistic"
    ])


def build_event_prompt(data):

    return f"""
[INST]
You are an SDXL prompt engineer.

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

Event Data:
{json.dumps(data, ensure_ascii=False)}
[/INST]
""".strip()


def normalize_event(parsed, data):

    if not isinstance(parsed, dict):

        return {
            "positive_prompt": fallback_prompt(data),
            "negative_prompt": (
                "distorted room, blurry, cartoon, "
                "text, watermark"
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
        ),

        "theme_tokens": safe_list(
            parsed.get("theme_tokens")
        ),

        "style_tokens": safe_list(
            parsed.get("style_tokens")
        ),

        "lighting_tokens": safe_list(
            parsed.get("lighting_tokens")
        ),

        "decor_tokens": safe_list(
            parsed.get("decor_tokens")
        ),

        "recommended_strength": float(
            parsed.get(
                "recommended_strength",
                0.58
            )
        ),
    }


# =========================================================
# SUPABASE
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
