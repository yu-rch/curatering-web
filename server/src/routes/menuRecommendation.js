import { Router } from "express";
import OpenAI from "openai";

const router = Router();

const DEFAULT_BASE_URL =
  "https://api.runpod.ai/v2/qwen3-32b-awq/openai/v1";
const DEFAULT_MODEL = "Qwen/Qwen3-32B-AWQ";
const MAX_CATALOGUE = 120;

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
8. Return ONLY valid JSON.
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

router.post("/recommend-menu", async (req, res) => {
  try {
    if (!qwenApiKey()) {
      return res.status(503).json({
        error: "Menu recommendation is not configured",
        code: "qwen_not_configured",
      });
    }

    const {
      eventType,
      eventTitle,
      eventSetting,
      guestCount,
      allergens = [],
      dishes = [],
    } = req.body || {};

    if (!eventType) {
      return res.status(400).json({
        error: "eventType is required",
      });
    }

    if (!Number.isInteger(Number(guestCount)) || Number(guestCount) < 1) {
      return res.status(400).json({
        error: "guestCount must be a positive integer",
      });
    }

    if (!Array.isArray(dishes) || dishes.length === 0) {
      return res.status(400).json({
        error: "No available catering dishes were provided",
      });
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
      return res.status(422).json({
        error: "Not enough allergen-safe dishes available for a recommendation",
      });
    }

    const userPrompt = JSON.stringify({
      event: {
        type: eventType,
        title: eventTitle || "",
        setting: eventSetting || "",
        guestCount: Number(guestCount),
        allergens: customerAllergens,
      },
      dishCatalogue,
    });

    const response = await qwenClient().chat.completions.create({
      model: qwenModel(),
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.2,
      max_tokens: 900,
    });

    const raw = response.choices?.[0]?.message?.content || "";
    const recommendation = parseRecommendationJson(raw);

    const validDishIds = new Set(dishCatalogue.map((dish) => dish.id));

    let selectedIds = Array.isArray(recommendation.dishIds)
      ? recommendation.dishIds
          .map(String)
          .filter((id) => validDishIds.has(id))
          .filter((id) => {
            const dish = dishCatalogue.find((d) => d.id === id);
            return dish && !dishHasAllergen(dish.allergens, customerAllergens);
          })
      : [];

    selectedIds = [...new Set(selectedIds)].slice(0, 10);

    if (selectedIds.length < 8) {
      return res.status(422).json({
        error: "AI could not produce enough valid dishes",
        raw: recommendation,
      });
    }

    const selectedDishes = selectedIds.map((id) =>
      dishCatalogue.find((dish) => dish.id === id),
    );

    return res.json({
      success: true,
      dishIds: selectedIds,
      dishes: selectedDishes,
      summary:
        typeof recommendation.summary === "string"
          ? recommendation.summary
          : "",
      notes: Array.isArray(recommendation.notes)
        ? recommendation.notes
            .map((n) => String(n || "").trim())
            .filter(Boolean)
            .slice(0, 5)
        : [],
    });
  } catch (error) {
    console.error("Menu recommendation error:", error);
    if (error?.code === "qwen_not_configured") {
      return res.status(503).json({
        error: "Menu recommendation is not configured",
        code: "qwen_not_configured",
      });
    }
    return res.status(500).json({
      error: "Unable to generate menu recommendation",
    });
  }
});

export default router;
