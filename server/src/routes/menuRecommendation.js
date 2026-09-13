import crypto from "node:crypto";
import { Router } from "express";
import OpenAI from "openai";

const router = Router();

const DEFAULT_BASE_URL =
  "https://api.runpod.ai/v2/qwen3-32b-awq/openai/v1";
const DEFAULT_MODEL = "Qwen/Qwen3-32B-AWQ";
const MAX_CATALOGUE = 120;
const QWEN_TIMEOUT_MS = Number(process.env.QWEN_TIMEOUT_MS || 180_000);
const JOB_TTL_MS = 15 * 60 * 1000;

/** @type {Map<string, { status: string, createdAt: number, error?: string, result?: object }>} */
const jobs = new Map();

function qwenApiKey() {
  return String(process.env.RUNPOD_API_KEY_QWEN || "").trim();
}

function qwenClient() {
  const apiKey = qwenApiKey();
  if (!apiKey) {
    const err = new Error("RUNPOD_API_KEY_QWEN is not configured");
    err.code = "qwen_not_configured";
    err.status = 503;
    throw err;
  }
  return new OpenAI({
    apiKey,
    baseURL: String(
      process.env.RUNPOD_QWEN_BASE_URL || DEFAULT_BASE_URL,
    ).trim(),
    timeout: QWEN_TIMEOUT_MS,
    maxRetries: 0,
  });
}

function qwenModel() {
  return (
    String(process.env.RUNPOD_QWEN_MODEL || DEFAULT_MODEL).trim() ||
    DEFAULT_MODEL
  );
}

function normalizeAllergenList(value) {
  if (!Array.isArray(value)) return [];
  return [
    ...new Set(
      value
        .map((a) => String(a || "").trim().toLowerCase())
        .filter(Boolean),
    ),
  ];
}

function dishHasAllergen(dishAllergens, customerAllergens) {
  if (!customerAllergens.length || !dishAllergens.length) return false;
  const set = new Set(
    dishAllergens.map((a) => String(a || "").trim().toLowerCase()).filter(Boolean),
  );
  return customerAllergens.some((a) => set.has(a));
}

function stripModelJson(raw) {
  let text = String(raw || "").trim();
  text = text.replace(/<think>[\s\S]*?<\/think>/gi, "").trim();
  text = text.replace(/<think>[\s\S]*$/gi, "").trim();
  text = text.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "").trim();
  return text;
}

function parseRecommendationJson(raw) {
  const cleaned = stripModelJson(raw);
  try {
    return JSON.parse(cleaned);
  } catch (_) {
    const match = cleaned.match(/\{[\s\S]*\}/);
    if (!match) {
      throw new Error("Qwen returned invalid JSON");
    }
    return JSON.parse(match[0]);
  }
}

function gcJobs() {
  const now = Date.now();
  for (const [id, job] of jobs) {
    if (now - job.createdAt > JOB_TTL_MS) jobs.delete(id);
  }
}

const SYSTEM_PROMPT = `You are Macrina Catering's menu recommendation assistant.

Your job is to recommend a balanced catering menu for an event.

IMPORTANT RULES:

1. You may ONLY recommend dishes whose IDs appear in the supplied dish catalogue.
2. Never invent a dish.
3. Never modify a dish name.
4. Never recommend a dish containing an allergen listed by the customer.
5. Consider:
   - event type
   - event title
   - indoor/outdoor setting
   - guest count
   - allergens
6. Prefer a balanced menu rather than several very similar dishes.
7. Recommend between 8 and 10 dishes.
8. Return ONLY valid JSON. Do not use chain-of-thought or <think> tags.
9. The "dishId" values must exactly match IDs from the catalogue.

Return this structure:

{
  "dishIds": ["id1", "id2"],
  "summary": "Short explanation of why this menu fits the event.",
  "notes": [
    "Short consideration 1",
    "Short consideration 2"
  ]
}`;

function validateRecommendBody(body) {
  const {
    eventType,
    eventTitle,
    eventSetting,
    guestCount,
    allergens = [],
    dishes = [],
  } = body || {};

  if (!eventType) {
    const err = new Error("eventType is required");
    err.status = 400;
    throw err;
  }

  if (!Number.isInteger(Number(guestCount)) || Number(guestCount) < 1) {
    const err = new Error("guestCount must be a positive integer");
    err.status = 400;
    throw err;
  }

  if (!Array.isArray(dishes) || dishes.length === 0) {
    const err = new Error("No available catering dishes were provided");
    err.status = 400;
    throw err;
  }

  const customerAllergens = normalizeAllergenList(allergens);

  const dishCatalogue = dishes
    .slice(0, MAX_CATALOGUE)
    .map((dish) => ({
      id: String(dish?.id ?? ""),
      name: String(dish?.name || ""),
      description: String(dish?.description || ""),
      category: String(dish?.category || ""),
      allergens: Array.isArray(dish?.allergens)
        ? dish.allergens.map((a) => String(a || "").trim()).filter(Boolean)
        : [],
    }))
    .filter((dish) => dish.id)
    .filter((dish) => !dishHasAllergen(dish.allergens, customerAllergens));

  if (dishCatalogue.length < 8) {
    const err = new Error(
      "Not enough allergen-safe dishes available for a recommendation",
    );
    err.status = 422;
    throw err;
  }

  return {
    eventType,
    eventTitle,
    eventSetting,
    guestCount: Number(guestCount),
    customerAllergens,
    dishCatalogue,
  };
}

function extractMessageText(message) {
  if (!message) return "";
  const parts = [message.content, message.reasoning_content, message.reasoning];
  return parts
    .flatMap((part) => {
      if (typeof part === "string") return [part];
      if (Array.isArray(part)) {
        return part.map((p) =>
          typeof p === "string" ? p : String(p?.text || ""),
        );
      }
      return [];
    })
    .join("\n")
    .trim();
}

async function generateRecommendation(input) {
  const userPrompt = `/no_think\n${JSON.stringify({
    event: {
      type: input.eventType,
      title: input.eventTitle || "",
      setting: input.eventSetting || "",
      guestCount: input.guestCount,
      allergens: input.customerAllergens,
    },
    dishCatalogue: input.dishCatalogue,
  })}`;

  const request = {
    model: qwenModel(),
    messages: [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "user", content: userPrompt },
    ],
    temperature: 0.2,
    max_tokens: 1600,
  };

  let response;
  try {
    response = await qwenClient().chat.completions.create(request, {
      timeout: QWEN_TIMEOUT_MS,
      extraBody: {
        chat_template_kwargs: { enable_thinking: false },
      },
    });
  } catch (error) {
    const msg = String(error?.message || "").toLowerCase();
    if (!msg.includes("extrabody") && !msg.includes("unrecognized")) {
      throw error;
    }
    response = await qwenClient().chat.completions.create(request, {
      timeout: QWEN_TIMEOUT_MS,
    });
  }

  const raw = extractMessageText(response.choices?.[0]?.message);
  const recommendation = parseRecommendationJson(raw);
  const validDishIds = new Set(input.dishCatalogue.map((dish) => dish.id));

  let selectedIds = Array.isArray(recommendation.dishIds)
    ? recommendation.dishIds
        .map(String)
        .filter((id) => validDishIds.has(id))
        .filter((id) => {
          const dish = input.dishCatalogue.find((d) => d.id === id);
          return dish && !dishHasAllergen(dish.allergens, input.customerAllergens);
        })
    : [];

  selectedIds = [...new Set(selectedIds)].slice(0, 10);

  if (selectedIds.length < 8) {
    const err = new Error("AI could not produce enough valid dishes");
    err.status = 422;
    err.raw = recommendation;
    throw err;
  }

  const selectedDishes = selectedIds.map((id) =>
    input.dishCatalogue.find((dish) => dish.id === id),
  );

  return {
    success: true,
    dishIds: selectedIds,
    dishes: selectedDishes,
    summary:
      typeof recommendation.summary === "string" ? recommendation.summary : "",
    notes: Array.isArray(recommendation.notes)
      ? recommendation.notes
          .map((n) => String(n || "").trim())
          .filter(Boolean)
          .slice(0, 5)
      : [],
  };
}

async function runJob(jobId, input) {
  const job = jobs.get(jobId);
  if (!job) return;
  try {
    const result = await generateRecommendation(input);
    job.status = "completed";
    job.result = result;
  } catch (error) {
    console.error("Menu recommendation job error:", jobId, error);
    job.status = "failed";
    job.error =
      error?.status === 422
        ? error.message
        : "Unable to generate menu recommendation";
  }
}

router.post("/recommend-menu", async (req, res) => {
  try {
    if (!qwenApiKey()) {
      return res.status(503).json({
        error: "Menu recommendation is not configured",
        code: "qwen_not_configured",
      });
    }

    const input = validateRecommendBody(req.body);
    gcJobs();

    const jobId = crypto.randomUUID();
    jobs.set(jobId, {
      status: "processing",
      createdAt: Date.now(),
    });

    setImmediate(() => {
      runJob(jobId, input);
    });

    return res.status(202).json({
      jobId,
      status: "processing",
    });
  } catch (error) {
    console.error("Menu recommendation error:", error);
    if (error?.code === "qwen_not_configured") {
      return res.status(503).json({
        error: "Menu recommendation is not configured",
        code: "qwen_not_configured",
      });
    }
    const status = Number(error?.status) || 500;
    return res.status(status).json({
      error:
        status >= 400 && status < 500
          ? error.message
          : "Unable to generate menu recommendation",
    });
  }
});

router.get("/recommend-menu/:jobId", (req, res) => {
  gcJobs();
  const job = jobs.get(String(req.params.jobId || ""));
  if (!job) {
    return res.status(404).json({
      error: "Recommendation job not found",
      status: "failed",
    });
  }

  if (job.status === "completed" && job.result) {
    return res.json({
      jobId: req.params.jobId,
      status: "completed",
      ...job.result,
    });
  }

  if (job.status === "failed") {
    return res.status(422).json({
      jobId: req.params.jobId,
      status: "failed",
      error: job.error || "Unable to generate menu recommendation",
    });
  }

  return res.json({
    jobId: req.params.jobId,
    status: "processing",
  });
});

export default router;
