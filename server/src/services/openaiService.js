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

const themeDecorMap = new Map([
  [
    "cinderella",
    [
      "princess figure wearing royal blue dress",
      "royal blue drapery",
      "glass slipper centerpiece",
      "castle arch backdrop",
      "crystal chandeliers",
    ],
  ],
  [
    "rustic",
    [
      "wooden tables",
      "warm string lights",
      "greenery centerpieces",
    ],
  ],
  [
    "modern luxury",
    [
      "gold accents",
      "marble decor",
      "minimalist floral arrangements",
    ],
  ],
  [
    "luxury",
    [
      "crystal chandeliers",
      "white floral centerpieces",
      "gold accents",
      "cream drapery",
    ],
  ],
]);

const fixedNegativePrompt = [
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
].join(", ");

function getStrength(intensity) {
  const value = Math.min(1, Math.max(0, Number(intensity) || 0));
  if (value < 0.4) return 0.75;
  if (value < 0.7) return 0.82;
  return 0.9;
}

function getControlNet(intensity) {
  const value = Math.min(1, Math.max(0, Number(intensity) || 0));
  if (value < 0.4) return 0.85;
  if (value < 0.7) return 0.65;
  return 0.55;
}

function getPreprocessor(intensity) {
  return "canny";
}

function getMode(intensity) {
  const value = Math.min(1, Math.max(0, Number(intensity) || 0));
  if (value < 0.4) return "preserve";
  if (value < 0.7) return "modify";
  return "rebuild";
}

function inputIntensity(input) {
  const raw =
    input?.intensity ??
    input?.transformation_intensity ??
    input?.transformationIntensity;
  const value = Number(raw);
  return Number.isFinite(value) ? Math.min(1, Math.max(0, value)) : 0.8;
}

function cleanPrompt(prompt) {
  const noWeights = String(prompt || "")
    .replace(/\(([^:()]+):\d+(?:\.\d+)?\)/g, "$1")
    .replace(/\bultra detailed\b/gi, "")
    .replace(/\bmasterpiece\b/gi, "")
    .replace(/\bcinematic lighting\b/gi, "")
    .replace(/\bluxury interior photography\b/gi, "")
    .replace(/\bbeautiful\b/gi, "")
    .replace(/\bluxury vibe\b/gi, "")
    .replace(/\bcinematic atmosphere\b/gi, "");
  return compactSdxlPrompt(noWeights, 70);
}

const spatialTokens = [
  "center of room",
  "floor area filled with",
  "main hall placement",
  "foreground seating area",
];

function normalizeLocation(value) {
  const text = String(value || "").trim().toLowerCase();
  if (!text) return "";
  if (/\b(middle|center|centre)\b/.test(text)) return "center";
  if (/\b(side wall|wall|side)\b/.test(text)) return "side wall";
  if (/\b(floor|empty floor|floor area)\b/.test(text)) return "floor area";
  if (/\b(front|foreground)\b/.test(text)) return "foreground seating area";
  if (/\b(main hall|hall)\b/.test(text)) return "main hall";
  return text;
}

function stringFromInsertObject(item) {
  if (!item || typeof item !== "object" || Array.isArray(item)) return null;
  const object = String(item.object || item.item || item.name || "").trim();
  if (!object) return null;
  return {
    object,
    location: normalizeLocation(item.location || item.position || item.placement),
  };
}

function locationForObject(object, input) {
  const text = [
    input?.prompt,
    input?.notes,
    input?.custom_instructions,
    input?.theme,
    object,
  ].map((value) => String(value || "").toLowerCase()).join(" ");
  if (/\b(middle|center|centre)\b/.test(text)) return "center";
  if (/\bphoto booth\b/.test(text)) return "side wall";
  if (/\b(table|chair|seating|floor)\b/.test(text)) return "floor area";
  if (/\b(backdrop|arch|stage)\b/.test(text)) return "main hall";
  return "";
}

function compileInsertedObject(item) {
  const object = String(item?.object || "").trim();
  const location = normalizeLocation(item?.location);
  if (!object) return "";
  if (location === "center") return `center ${object} centerpiece`;
  if (location === "side wall") return `add ${object} near side wall`;
  if (location === "floor area") return `add ${object} on floor area`;
  if (location === "foreground seating area") return `add ${object} in foreground seating area`;
  if (location === "main hall") return `add ${object} in main hall placement`;
  return `add ${object}`;
}

function concreteThemeDecor(input) {
  const lookup = [
    input?.theme,
    input?.style,
    input?.mood,
    input?.prompt,
    input?.custom_instructions,
    input?.notes,
  ]
    .map((value) => String(value || "").toLowerCase())
    .join(" ");
  const out = [];
  for (const [key, values] of themeDecorMap.entries()) {
    if (lookup.includes(key)) out.push(...values);
  }
  return [...new Set(out)];
}

function buildTransformationPlan(input, json = {}) {
  const mappedDecor = concreteThemeDecor(input);
  const explicitInsertObjects = Array.isArray(json.insert_objects)
    ? json.insert_objects.map(stringFromInsertObject).filter(Boolean)
    : [];
  const objectsToAdd = [
    ...stringList(json.objects_to_add, 10),
    ...mappedDecor,
    ...stringList(json.furniture, 5),
    ...stringList(json.materials, 5),
    ...stringList(json.decor_tokens, 8),
  ];
  if (objectsToAdd.length === 0) {
    objectsToAdd.push("round banquet tables", "white floral centerpieces");
  }
  const insertObjects =
    explicitInsertObjects.length > 0
      ? explicitInsertObjects
      : [...new Set(objectsToAdd)].slice(0, 8).map((object) => ({
          object,
          location: locationForObject(object, input),
        }));
  return {
    global_style: String(json.global_style || input?.theme || input?.style || input?.event_type || "themed event").trim(),
    theme: String(json.theme || input?.theme || input?.style || input?.event_type || "themed").trim(),
    insert_objects: insertObjects,
    objects_to_add: [...new Set(objectsToAdd)].slice(0, 10),
    objects_to_replace: stringList(json.objects_to_replace, 8),
    decor: stringList(json.decor, 10),
    lighting_style: String(json.lighting_style || stringList(json.lighting_tokens, 1)[0] || "warm candle lighting").trim(),
    mood: String(json.mood || input?.mood || "").trim(),
  };
}

function buildTransformationPrompt(input, generatedPrompt, decorTokens, plan) {
  const parts = [];
  const eventType = String(input?.event_type || "").trim().toLowerCase();
  const theme = String(plan?.theme || input?.theme || input?.style || "").trim().toLowerCase();
  const target = [theme, eventType, "event"]
    .filter(Boolean)
    .join(" ");
  if (target) {
    parts.push(`transform venue into ${target}`);
  }
  parts.push("add decor on top of venue photo");
  parts.push("empty floor to be filled with event furniture");
  parts.push(...spatialTokens);
  parts.push(...(plan?.insert_objects || []).map(compileInsertedObject));
  parts.push(...(plan?.objects_to_add || decorTokens));
  parts.push(...(plan?.decor || []));
  for (const item of plan?.objects_to_replace || []) {
    parts.push(`replace ${item}`);
  }
  if (plan?.lighting_style) parts.push(plan.lighting_style);
  parts.push("photorealistic");
  return cleanPrompt(parts.filter(Boolean).join(", ") || generatedPrompt);
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
  const intensity = inputIntensity(input);
  const prompt = `
Create a structured SD 1.5 img2img transformation plan and payload.

Return ONLY valid JSON.

Schema:
{
  "global_style": "string",
  "theme": "string",
  "insert_objects": [{"object":"physical object string","location":"center | side wall | floor area | foreground seating area | main hall"}],
  "objects_to_add": ["physical object string"],
  "objects_to_replace": ["physical replacement string"],
  "decor": ["physical decor string"],
  "lighting_style": "physical lighting string",
  "mood": "optional internal string"
}

Rules:
- You are a Transformation Planner for physical environments.
- Output physical objects only.
- Convert themes into physical decor, lighting, materials, and furniture.
- Do not output aesthetic descriptions, weighted tags, emotions, or abstract moods as visible objects.
- Do not write "beautiful", "luxury vibe", "cinematic atmosphere", "ultra detailed", "masterpiece", or "luxury interior photography".
- Use visible scene changes: furniture, drapery, centerpieces, lighting fixtures, backdrops, materials.
- Final prompt must explicitly include "add decor on top of venue photo".
- If user says "middle", output location "center".
- Preserve spatial intent in insert_objects with exact object and location.
- Use locations like center, side wall, floor area, foreground seating area, main hall.
- Keep arrays compact and non-repetitive.
- Convert themes into physical decor, lighting, materials, and furniture.
- "luxury" must become concrete objects such as crystal chandeliers, floral centerpieces, gold accents, marble decor, cream drapery.

Theme decor map:
- cinderella: princess figure wearing royal blue dress, royal blue drapery, glass slipper centerpiece, castle arch backdrop, crystal chandeliers
- rustic: wooden tables, warm string lights, greenery centerpieces
- modern luxury: gold accents, marble decor, minimalist floral arrangements

Ideal final prompt style:
transform venue into garden birthday event, center sakura tree centerpiece, add banquet tables on floor area, add photo booth near side wall, blue and red color palette, fairy lights, princess themed decorations, photorealistic

Event config:
${JSON.stringify(input)}
`.trim();

  const json = await createJsonCompletion({
    system:
      "You are a scene transformation planner. Return only physical objects and lighting for an SD 1.5 img2img editor.",
    user: prompt,
    temperature: 0.25,
    maxTokens: 450,
  });

  const plan = buildTransformationPlan(input, json);
  const mappedDecor = concreteThemeDecor(input);
  const decorTokens = [
    ...mappedDecor,
    ...plan.objects_to_add,
  ];
  const compiledPrompt = buildTransformationPrompt(input, json.positive_prompt || json.prompt, decorTokens, plan);
  const controlnet = getControlNet(intensity);
  const preprocessor = getPreprocessor(intensity);
  const strength = getStrength(intensity);

  return {
    prompt: compiledPrompt,
    positive_prompt: compiledPrompt,
    negative_prompt: fixedNegativePrompt,
    strength,
    recommended_strength: strength,
    cfg_scale: 7,
    steps: 30,
    controlnet: {
      enabled: true,
      conditioning_scale: controlnet,
      preprocessor,
    },
    mode: getMode(intensity),
    transformation_plan: plan,
    theme_tokens: stringList(json.theme_tokens).concat(mappedDecor).slice(0, 8),
    decor_tokens: decorTokens.slice(0, 8),
    lighting_tokens: plan.lighting_style ? [plan.lighting_style] : [],
  };
}
