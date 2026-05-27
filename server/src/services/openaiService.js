import OpenAI from "openai";
import {
  autoSceneCorrector,
  compileScenePrompt,
  resolveIntensity,
  getStrength,
  getControlNet,
  getMode,
  buildNegativePrompt,
} from "./prompt_engine.js";

const DEFAULT_MODEL = "gpt-4.1-mini";
let client = null;

function openAiClient() {
  const apiKey = String(process.env.OPENAI_API_KEY || "").trim();
  if (!apiKey) {
    const err = new Error("OPENAI_API_KEY is not configured");
    err.code = "openai_not_configured";
    err.status = 503;
    throw err;
  }
  if (!client) client = new OpenAI({ apiKey });
  return client;
}

export function isOpenAiConfigured() {
  return Boolean(String(process.env.OPENAI_API_KEY || "").trim());
}

export function openAiModel() {
  return String(process.env.OPENAI_MODEL || DEFAULT_MODEL).trim() || DEFAULT_MODEL;
}

/* -----------------------------
   OPENAI CALL WRAPPER
----------------------------- */

async function chatJson(system, user) {
  const res = await openAiClient().chat.completions.create({
    model: openAiModel(),
    response_format: { type: "json_object" },
    messages: [
      { role: "system", content: system },
      { role: "user", content: user },
    ],
    temperature: 0.3,
  });

  return JSON.parse(res.choices[0].message.content);
}

function stringList(value, max = 8) {
  const fromObject = (item) => {
    if (!item || typeof item !== "object" || Array.isArray(item)) return "";
    return String(
      item.message ||
        item.summary ||
        item.title ||
        item.insight ||
        item.trend ||
        item.problem ||
        item.recommendation ||
        item.action ||
        item.description ||
        "",
    ).trim();
  };
  const normalize = (item) =>
    typeof item === "string" || typeof item === "number"
      ? String(item).trim()
      : fromObject(item);
  if (Array.isArray(value)) {
    return value.map(normalize).filter(Boolean).slice(0, max);
  }
  if (typeof value === "string") {
    return value
      .split(/\n+|;\s*|(?:^|\s)\d+\.\s+/)
      .map((item) => item.replace(/^[-*•]\s*/, "").trim())
      .filter(Boolean)
      .slice(0, max);
  }
  if (value && typeof value === "object") {
    return Object.values(value).flatMap((item) => stringList(item, max)).slice(0, max);
  }
  return [];
}

export async function analyzeSingleFeedback(feedback) {
  const json = await chatJson(
    "You analyze customer feedback for a catering and restaurant operation. Return JSON only.",
    `Return JSON with sentiment, summary, key_topics, complaints, praises, insights, recommendations.\nFeedback:\n${JSON.stringify(feedback)}`,
  );
  return {
    sentiment: String(json.sentiment || "mixed").toLowerCase(),
    summary: String(json.summary || "").trim(),
    key_topics: stringList(json.key_topics || json.top_topics, 8),
    complaints: stringList(json.complaints, 8),
    praises: stringList(json.praises, 8),
    insights: stringList(json.insights, 8),
    recommendations: stringList(json.recommendations, 8),
  };
}

export async function analyzeFeedbackBatch(feedbacks) {
  const json = await chatJson(
    "You analyze customer feedback batches for a catering and restaurant operation. Return JSON only.",
    `Return JSON with overall_sentiment, sentiment_distribution, top_topics, summary, complaints, praises, insights, recommendations.\nFeedbacks:\n${JSON.stringify(feedbacks)}`,
  );
  return {
    overall_sentiment: String(json.overall_sentiment || json.sentiment || "mixed").toLowerCase(),
    sentiment_distribution: json.sentiment_distribution || {},
    top_topics: stringList(json.top_topics || json.key_topics, 8),
    summary: String(json.summary || "").trim(),
    complaints: stringList(json.complaints, 8),
    praises: stringList(json.praises, 8),
    insights: stringList(json.insights, 8),
    recommendations: stringList(json.recommendations, 8),
  };
}

export async function analyzeCustomerFeedbackOverview(feedbacks) {
  const json = await chatJson(
    "You analyze restaurant customer feedback for business operators. Return JSON only.",
    `Return JSON with summary, interpretation, recommendations, sentiment, key_topics.\nFeedback entries:\n${JSON.stringify(feedbacks)}`,
  );
  return {
    summary: String(json.summary || "").trim(),
    interpretation: String(json.interpretation || "").trim(),
    recommendations: stringList(json.recommendations, 8),
    sentiment: String(json.sentiment || "mixed").toLowerCase(),
    key_topics: stringList(json.key_topics || json.top_topics, 8),
  };
}

export async function analyzeDashboard(data) {
  const json = await chatJson(
    [
      "You are a business dashboard analyst for a catering and restaurant operation.",
      "Return JSON only. Use this exact shape:",
      "{",
      '  "summary": "2-4 sentence management summary",',
      '  "insights": ["3-6 concise observations"],',
      '  "trends": ["3-6 sales, order, feedback, or event trends"],',
      '  "problems": ["2-5 operational or data-quality problems; use [] only if none"],',
      '  "recommendations": ["3-6 specific next actions for managers"],',
      '  "alerts": [{"type":"short_key","severity":"info|medium|high","message":"specific alert"}],',
      '  "explainability": ["3-6 data points used"]',
      "}",
      "Always include arrays for trends, problems, recommendations, alerts, and explainability.",
    ].join("\n"),
    `Analyze the dashboard data and fill every section with useful management content.\nDashboard:\n${JSON.stringify(data)}`,
  );
  return {
    summary: String(json.summary || "").trim(),
    insights: stringList(json.insights, 10),
    trends: stringList(json.trends, 10),
    problems: stringList(json.problems, 10),
    recommendations: stringList(json.recommendations, 10),
    alerts: Array.isArray(json.alerts) ? json.alerts.slice(0, 8) : [],
    explainability: stringList(json.explainability || json.explanation_points, 10),
  };
}

export async function analyzeDishTrends(data) {
  const json = await chatJson(
    "You analyze menu performance and dish ordering trends. Return JSON only.",
    `Return JSON with summary, popular_dishes, declining_dishes, seasonal_patterns, recommendations.\nDish data:\n${JSON.stringify(data)}`,
  );
  return {
    summary: String(json.summary || "").trim(),
    popular_dishes: stringList(json.popular_dishes, 10),
    declining_dishes: stringList(json.declining_dishes, 10),
    seasonal_patterns: stringList(json.seasonal_patterns, 10),
    recommendations: stringList(json.recommendations, 10),
  };
}

/* -----------------------------
   SCENE PIPELINE
----------------------------- */

export async function expandEventPrompt(input = {}) {
  const intensity = resolveIntensity(input);

  const planned = await planEventScene(input);
  const corrected = autoSceneCorrector({
    ...input,
    scene_graph: planned,
  });
  const scene = corrected.scene_graph;

  const prompt = compileScenePrompt(scene, {
    globalStyle: [input.theme, input.event_type].filter(Boolean).join(" "),
  });

  return {
    prompt,
    positive_prompt: prompt,
    negative_prompt: buildNegativePrompt(),
    strength: getStrength(intensity),
    cfg_scale: 7,
    steps: 30,
    controlnet: {
      enabled: true,
      conditioning_scale: getControlNet(intensity),
      preprocessor: "depth",
    },
    mode: getMode(intensity),
    scene_graph: scene,
    corrected: corrected.corrected,
  };
}

/* -----------------------------
   OPTIONAL: AI SCENE PLANNER
----------------------------- */

export async function planEventScene(input) {
  const prompt = `
Return JSON only.

Create a scene graph:
{
  "main_centerpiece": "",
  "secondary_objects": [],
  "decor_elements": []
}

Input:
${JSON.stringify(input)}
`;

  return chatJson("You are a spatial scene designer.", prompt);
}