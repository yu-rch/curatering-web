import OpenAI from "openai";

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
  if (!client) {
    client = new OpenAI({ apiKey });
  }
  return client;
}

export function isOpenAiConfigured() {
  return Boolean(String(process.env.OPENAI_API_KEY || "").trim());
}

export function openAiModel() {
  return String(process.env.OPENAI_MODEL || DEFAULT_MODEL).trim() || DEFAULT_MODEL;
}

function parseJson(content) {
  if (content && typeof content === "object") return content;
  const text = String(content || "").trim();
  if (!text) {
    const err = new Error("OpenAI returned an empty response");
    err.code = "invalid_ai_response";
    err.status = 502;
    throw err;
  }
  try {
    return JSON.parse(text);
  } catch {
    const start = text.indexOf("{");
    const end = text.lastIndexOf("}");
    if (start >= 0 && end > start) {
      return JSON.parse(text.slice(start, end + 1));
    }
    const err = new Error("OpenAI returned invalid JSON");
    err.code = "invalid_ai_response";
    err.status = 502;
    throw err;
  }
}

async function createJsonCompletion({
  system = "Return only valid JSON.",
  user,
  temperature = 0.2,
  maxTokens = 900,
}) {
  const response = await openAiClient().chat.completions.create({
    model: openAiModel(),
    response_format: { type: "json_object" },
    messages: [
      { role: "system", content: system },
      { role: "user", content: user },
    ],
    temperature,
    max_tokens: maxTokens,
  });
  return parseJson(response.choices?.[0]?.message?.content);
}

function stringList(value, max = 8) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => String(item || "").trim())
    .filter(Boolean)
    .slice(0, max);
}

function compactSdxlPrompt(value, maxWords = 70) {
  const text = String(value || "")
    .replace(/\s+/g, " ")
    .replace(/[.;]\s*/g, ", ")
    .trim();
  if (!text) return "";

  const seen = new Set();
  const phrases = text
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean)
    .filter((part) => {
      const key = part.toLowerCase();
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });

  const out = [];
  let words = 0;
  for (const phrase of phrases) {
    const count = phrase.split(/\s+/).filter(Boolean).length;
    if (out.length > 0 && words + count > maxWords) break;
    out.push(phrase);
    words += count;
  }

  return out.join(", ");
}

export async function analyzeFeedback(feedbacks) {
  const list = (Array.isArray(feedbacks) ? feedbacks : [feedbacks])
    .map((item) => String(item || "").trim())
    .filter(Boolean);

  const prompt = `
You are a customer feedback analysis AI.

Return ONLY valid JSON.

Schema:
{
  "sentiment": "positive | negative | neutral | mixed",
  "complaints": ["string"],
  "praises": ["string"],
  "insights": ["string"],
  "recommendations": ["string"]
}

Feedback:
${list.map((x) => `- ${x}`).join("\n")}
`.trim();

  const json = await createJsonCompletion({
    system: "You are a customer feedback analysis AI.",
    user: prompt,
    temperature: 0.2,
  });

  return {
    sentiment: String(json.sentiment || "mixed").trim().toLowerCase(),
    complaints: stringList(json.complaints),
    praises: stringList(json.praises),
    insights: stringList(json.insights),
    recommendations: stringList(json.recommendations),
  };
}

export async function analyzeSingleFeedback(feedback) {
  const result = await analyzeFeedback([feedback]);
  const keyTopics = [
    ...result.complaints,
    ...result.praises,
    ...result.insights,
  ]
    .map((item) => item.split(/[.;:]/)[0].trim())
    .filter(Boolean)
    .slice(0, 5);
  return {
    sentiment: result.sentiment,
    key_topics: keyTopics,
    summary:
      result.insights[0] ||
      result.complaints[0] ||
      result.praises[0] ||
      "Feedback analyzed.",
    complaints: result.complaints,
    praises: result.praises,
    insights: result.insights,
    recommendations: result.recommendations,
  };
}

export async function analyzeFeedbackBatch(feedbacks) {
  const result = await analyzeFeedback(feedbacks);
  const total = Math.max(1, feedbacks.length);
  const sentiment = result.sentiment;
  const distribution = {
    positive: sentiment === "positive" ? total : 0,
    neutral: sentiment === "neutral" || sentiment === "mixed" ? total : 0,
    negative: sentiment === "negative" ? total : 0,
  };
  return {
    overall_sentiment: sentiment,
    sentiment_distribution: distribution,
    top_topics: [
      ...result.complaints,
      ...result.praises,
      ...result.insights,
    ]
      .map((item) => item.split(/[.;:]/)[0].trim())
      .filter(Boolean)
      .slice(0, 5),
    summary:
      result.insights[0] ||
      result.recommendations[0] ||
      `Analyzed ${feedbacks.length} feedback item(s).`,
    complaints: result.complaints,
    praises: result.praises,
    insights: result.insights,
    recommendations: result.recommendations,
  };
}

export async function analyzeCustomerFeedbackOverview(feedbacks) {
  const list = (Array.isArray(feedbacks) ? feedbacks : [])
    .map((item) => ({
      orderNo: item?.orderNo,
      stars: item?.stars,
      remarks: String(item?.remarks || "").trim(),
      customerName: item?.customerName,
      submittedAt: item?.submittedAt,
    }))
    .filter((item) => item.remarks || item.stars != null)
    .slice(0, 120);

  const prompt = `
Analyze these ${feedbacks.length} restaurant customer feedback entries for a catering operations team.

Return ONLY valid JSON.

Schema:
{
  "summary": "string, 2-3 sentences",
  "interpretation": "string, 2-4 sentences on themes and sentiment",
  "recommendations": ["3-5 short actionable strings for management"],
  "sentiment": "positive | negative | neutral | mixed",
  "key_topics": ["string"]
}

Feedback entries:
${JSON.stringify(list)}
`.trim();

  const json = await createJsonCompletion({
    system: "You analyze restaurant customer order feedback for a catering business operations team.",
    user: prompt,
    temperature: 0.25,
    maxTokens: 900,
  });

  return {
    summary: String(json.summary || "").trim(),
    interpretation: String(json.interpretation || "").trim(),
    recommendations: stringList(json.recommendations, 8),
    sentiment: String(json.sentiment || "mixed").trim().toLowerCase(),
    key_topics: stringList(json.key_topics || json.top_topics, 8),
  };
}

export async function analyzeDashboard(data) {
  const prompt = `
Analyze this business dashboard.

Return ONLY valid JSON.

Schema:
{
  "summary": "string",
  "insights": ["string"],
  "trends": ["string"],
  "problems": ["string"],
  "recommendations": ["string"],
  "alerts": [{"type":"string","severity":"info | medium | high","message":"string","explanation":"string"}],
  "explainability": ["string"]
}

Dashboard:
${JSON.stringify(data)}
`.trim();

  const json = await createJsonCompletion({
    system: "You are a business dashboard analyst for a catering and restaurant operation.",
    user: prompt,
    temperature: 0.2,
    maxTokens: 1200,
  });

  return {
    summary: String(json.summary || "").trim(),
    insights: stringList(json.insights),
    trends: stringList(json.trends),
    problems: stringList(json.problems),
    recommendations: stringList(json.recommendations),
    alerts: Array.isArray(json.alerts) ? json.alerts.slice(0, 8) : [],
    explainability: stringList(json.explainability || json.explanation_points, 10),
  };
}

export async function analyzeDishTrends(data) {
  const prompt = `
Analyze restaurant dish ordering trends.

Return ONLY valid JSON.

Schema:
{
  "summary": "string",
  "popular_dishes": ["string"],
  "declining_dishes": ["string"],
  "seasonal_patterns": ["string"],
  "recommendations": ["string"]
}

Dish data:
${JSON.stringify(data)}
`.trim();

  const json = await createJsonCompletion({
    system: "You analyze menu performance and demand trends.",
    user: prompt,
    temperature: 0.2,
  });

  return {
    summary: String(json.summary || "").trim(),
    popular_dishes: stringList(json.popular_dishes),
    declining_dishes: stringList(json.declining_dishes),
    seasonal_patterns: stringList(json.seasonal_patterns),
    recommendations: stringList(json.recommendations),
  };
}

export async function expandEventPrompt(input) {
  const prompt = `
Transform this event design request into SDXL img2img editing prompt JSON.

Return ONLY valid JSON.

Schema:
{
  "positive_prompt": "concise comma-separated SDXL img2img edit prompt, under 60 meaningful tokens",
  "negative_prompt": "concise comma-separated negative prompt",
  "theme_tokens": ["string"],
  "decor_tokens": ["string"],
  "lighting_tokens": ["string"],
  "recommended_strength": 0.5
}

Rules:
- You are an SDXL prompt engineer.
- Generate concise SDXL img2img editing prompts.
- Focus on what should be ADDED.
- Focus on what should be REPLACED.
- Focus on what should be TRANSFORMED.
- Avoid generic environment descriptions.
- Avoid repeating existing venue details.
- Keep prompts under 60 meaningful tokens.
- Avoid repetition.
- Prioritize requested visual edits, decor, props, palette, focal pieces, and surface transformations.
- Use cinematic descriptors.
- Keep architecture realistic.
- Preserve room geometry.
- Avoid redundant lighting/style terms.
- Optimize for photorealism.
- Remove prose, explanations, and instructions.
- Return comma-separated edit concepts only.
- Normalize themes and remove conflicting aesthetics.

Event config:
${JSON.stringify(input)}
`.trim();

  const json = await createJsonCompletion({
    system:
      "You are an SDXL prompt engineer. Generate concise SDXL img2img editing prompts focused on added, replaced, and transformed elements.",
    user: prompt,
    temperature: 0.25,
    maxTokens: 450,
  });

  return {
    positive_prompt: compactSdxlPrompt(json.positive_prompt || json.prompt, 60),
    negative_prompt: compactSdxlPrompt(json.negative_prompt, 35),
    theme_tokens: stringList(json.theme_tokens),
    decor_tokens: stringList(json.decor_tokens),
    lighting_tokens: stringList(json.lighting_tokens),
    recommended_strength:
      Number.isFinite(Number(json.recommended_strength))
        ? Number(json.recommended_strength)
        : 0.55,
  };
}
