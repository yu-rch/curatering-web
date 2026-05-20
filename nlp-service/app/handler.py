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
  "sentiment": "positive | negative | mixed",
  "complaints": ["string"],
  "praises": ["string"],
  "insights": ["string"]
}}

Rules:
- Output MUST be valid JSON
- Use double quotes only
- No trailing commas
- complaints, praises, and insights must each be arrays

Feedback:
{combined}
[/INST]
""".strip()


def extract_json(text):
    try:
        return json.loads(text)
    except Exception:
        match = re.search(r"\{.*\}", text, re.DOTALL)
        if match:
            try:
                return json.loads(match.group())
            except Exception:
                return None
    return None


def _string_list(value, max_items=10):
    if not isinstance(value, list):
        return []
    return [str(item).strip() for item in value if str(item).strip()][:max_items]


def normalize_analysis(parsed):
    if not isinstance(parsed, dict):
        return None
    sentiment = str(parsed.get("sentiment") or "mixed").strip().lower()
    if sentiment not in ("positive", "negative", "mixed"):
        sentiment = "mixed"
    return {
        "sentiment": sentiment,
        "complaints": _string_list(parsed.get("complaints")),
        "praises": _string_list(parsed.get("praises")),
        "insights": _string_list(parsed.get("insights")),
    }


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
    original_feedback = "\n".join(feedbacks)

    supabase.table("feedback_analysis").insert({
        "batch_id": batch_id,
        "feedback_ids": feedback_ids,
        "original_feedback": original_feedback,
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

    outputs = llm.generate([prompt], sampling_params)
    raw_output = outputs[0].outputs[0].text.strip()

    parsed = normalize_analysis(extract_json(raw_output))
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