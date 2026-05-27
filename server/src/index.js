import "dotenv/config";
import crypto from "node:crypto";
import dns from "node:dns";
import express from "express";
import cors from "cors";
import jwt from "jsonwebtoken";
import bcrypt from "bcryptjs";
import {
  sendEmail,
  isEmailConfigured,
  logEmailStartupStatus,
} from "./email.js";
import postgres from 'postgres'
import path from 'path'
import fs from 'fs/promises'
import { existsSync } from "node:fs";
import { fileURLToPath } from 'url'
import {
  initDb,
  ensureAuthSchemaQuick,
  ensureOrderCateringIdColumns,
  ensureCustomerTrayDraftsSchema,
  ensureRestaurantOrderWorkflowColumns,
  getTableColumnNames,
  getColumnSqlType,
  ensureCustomerAccountsUuidCompat,
  customerAccountIdJoinSql,
  pool,
  poolQueryWithRetry,
  generateUserId,
  generateSequentialId,
  allocateRestaurantOrderNo,
  allocateCateringTransactionId,
  allocateStaffUserId,
  getRoleAccountLimits,
  setRoleAccountLimits,
  getLoyaltyProgramConfig,
  setLoyaltyProgramConfig,
  getCustomAllergenPresets,
  getMenuAllergenCatalog,
  upsertMenuAllergensFromSerialized,
  getMenuMealTypeCatalog,
  upsertMenuMealType,
} from "./db.js";
import {
  ensureRestaurantOrdersCanonicalColumns,
  ensureCateringEventOrdersCanonicalColumns,
  buildRestaurantOrderSelectSql,
  buildCustomerCateringOrdersSql,
  buildStaffEventsOrdersListSql,
  buildStaffEventOrderByIdQueries,
  cateringIdSelectAlias,
  restaurantOrderLookupWhereSql,
  restaurantOrderIdInsertColumn,
  restaurantOrderIdExpr,
  normalizeRestaurantOrderRow,
  normalizeCustomerCateringOrderRow,
  normalizeStaffEventOrderRow,
  parseRestaurantOrderTrayItems,
  restaurantOrderItemsInsertSql,
  buildRestaurantOrderPaymentUpdateSets,
} from "./order_schema.js";
import CartAPI from "./cart_api.js";
import {
  getTrayDraft,
  saveTrayDraft,
  clearTrayDraft,
  getTrayDraftItemsByCustomerId,
  clearTrayDraftForCustomer,
} from "./tray_drafts_api.js";
import { customerIdFromRequest } from "./customer_auth.js";
import { createPublicRateLimiter } from "./public_rate_limit.js";
import {
  ensureRestaurantPosColumns,
  registerPosRoutes,
} from "./posApi.js";
import {
  analyzeDashboard,
  analyzeCustomerFeedbackOverview,
  analyzeDishTrends,
  analyzeFeedbackBatch,
  analyzeSingleFeedback,
  expandEventPrompt,
  isOpenAiConfigured,
  openAiModel,
} from "./services/openaiService.js";

// Prefer IPv4 when resolving SMTP hosts (avoids ENETUNREACH on IPv6 in many cloud/container networks).
try {
  dns.setDefaultResultOrder("ipv4first");
} catch (_) {
}

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const websiteContentPath = path.join(__dirname, "website-content.json");

/** Resolve directory containing Flutter `web` build `index.html`, or null. */
function resolveWebBuildPath() {
  const candidates = [];
  const envPath = process.env.WEB_BUILD_PATH?.trim();
  if (envPath) candidates.push(path.resolve(envPath));
  candidates.push(path.resolve(path.join(__dirname, "../../curatering/build/web")));
  candidates.push(path.resolve(path.join(__dirname, "../../../curatering/build/web")));
  candidates.push(path.resolve(path.join(path.dirname(__dirname), "web")));
  for (const dir of candidates) {
    if (dir && existsSync(path.join(dir, "index.html"))) return dir;
  }
  return null;
}

function normalizeCorsOrigin(origin) {
  if (origin == null || typeof origin !== "string") return origin;
  const t = origin.trim();
  if (!t) return t;
  try {
    const u = new URL(t);
    const port = u.port ? `:${u.port}` : "";
    return `${u.protocol}//${u.hostname.toLowerCase()}${port}`;
  } catch {
    return t;
  }
}

function collectAllowedCorsOrigins() {
  const exact = new Set();

  const addExact = (value) => {
    const n = normalizeCorsOrigin(value);
    if (n) exact.add(n);
  };

  const fromList = String(process.env.CORS_ORIGINS || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  for (const o of fromList) {
    addExact(o);
  }

  for (const key of ["FRONTEND_URL", "WEB_ORIGIN", "PUBLIC_WEB_URL"]) {
    const raw = process.env[key];
    if (!raw) continue;
    try {
      addExact(new URL(raw.trim()).origin);
    } catch {
      // ignore invalid URL
    }
  }

  // Same host as API (e.g. if static app is ever served from the same Railway service)
  if (process.env.RAILWAY_PUBLIC_DOMAIN) {
    addExact(`https://${process.env.RAILWAY_PUBLIC_DOMAIN}`);
  }

  // Default API host (Flutter config.dart); only matters if the web app is served from this origin.
  addExact("https://curatering.up.railway.app");

  // Production web apps (subdomains only)
  addExact("https://macrinas-kitchen.curatering.com");
  addExact("https://www.macrinas-kitchen.curatering.com");
  addExact("https://staff.curatering.com");
  addExact("https://www.staff.curatering.com");

  return exact;
}

const _corsExactOrigins = collectAllowedCorsOrigins();

function corsOriginIsCurateringSite(origin) {
  if (!origin || typeof origin !== "string") return false;
  const n = normalizeCorsOrigin(origin);
  if (!n || !n.startsWith("https://")) return false;
  try {
    const h = new URL(n).hostname;
    return h === "curatering.com" || h.endsWith(".curatering.com");
  } catch {
    return false;
  }
}

const _corsOriginSuffixes = (() => {
  const suffixes = new Set();
  for (const s of String(process.env.CORS_ORIGIN_SUFFIXES || "")
    .split(",")
    .map((x) => x.trim())
    .filter(Boolean)) {
    suffixes.add(s.startsWith(".") ? s : `.${s}`);
  }
  if (String(process.env.CORS_ALLOW_VERCEL_ORIGINS || "") === "1") {
    suffixes.add(".vercel.app");
  }
  if (String(process.env.CORS_INFER_VERCEL_SUFFIX || "1") !== "0") {
    for (const o of _corsExactOrigins) {
      try {
        const h = new URL(o).hostname.toLowerCase();
        if (h === "vercel.app" || h.endsWith(".vercel.app")) {
          suffixes.add(".vercel.app");
          break;
        }
      } catch {
        /* ignore */
      }
    }
  }
  return suffixes;
})();

const _corsLocalhostPatterns = [
  /^https?:\/\/localhost(?::\d+)?$/i,
  /^http:\/\/127\.0\.0\.1(?::\d+)?$/i,
];

function corsOriginMatchesSuffix(origin) {
  if (!origin || typeof origin !== "string" || !origin.startsWith("https://")) return false;
  try {
    const { hostname } = new URL(origin);
    for (const suf of _corsOriginSuffixes) {
      const suffix = suf.startsWith(".") ? suf : `.${suf}`;
      if (hostname.toLowerCase().endsWith(suffix)) return true;
    }
  } catch {
    return false;
  }
  return false;
}

function corsOrigin(origin, callback) {
  if (corsOriginAllowed(origin)) {
    callback(null, true);
    return;
  }
  console.warn(
    "[cors] blocked origin (set CORS_ORIGINS / FRONTEND_URL for your web subdomains):",
    JSON.stringify(origin),
  );
  callback(null, false);
}

function corsOriginAllowed(origin) {
  if (!origin) {
    return true;
  }
  const normalized = normalizeCorsOrigin(origin);
  if (_corsExactOrigins.has(normalized)) {
    return true;
  }
  if (corsOriginIsCurateringSite(normalized)) {
    return true;
  }
  if (corsOriginMatchesSuffix(normalized)) {
    return true;
  }
  for (const re of _corsLocalhostPatterns) {
    if (re.test(normalized)) {
      return true;
    }
  }
  return false;
}

const app = express();
app.use((req, res, next) => {
  const origin = req.headers.origin;
  if (corsOriginAllowed(origin)) {
    if (origin) {
      res.setHeader("Access-Control-Allow-Origin", normalizeCorsOrigin(origin));
      res.setHeader("Vary", "Origin");
    }
    res.setHeader("Access-Control-Allow-Credentials", "true");
    res.setHeader("Access-Control-Allow-Methods", "GET,HEAD,POST,PUT,PATCH,DELETE,OPTIONS");
    res.setHeader(
      "Access-Control-Allow-Headers",
      req.headers["access-control-request-headers"] ||
        "Content-Type, Authorization, X-Requested-With, Accept, Origin",
    );
  }
  if (req.method === "OPTIONS") {
    return res.sendStatus(204);
  }
  next();
});
app.use(
  cors({
    origin: corsOrigin,
    credentials: true,
    methods: ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: [
      "Content-Type",
      "Authorization",
      "X-Requested-With",
      "Accept",
      "Origin",
    ],
    optionsSuccessStatus: 204,
  }),
);
const REQUEST_BODY_LIMIT = process.env.REQUEST_BODY_LIMIT || "100mb";
app.use(express.json({ limit: REQUEST_BODY_LIMIT }));

const publicRateLimit = createPublicRateLimiter();
app.use("/api/public/events/theme-design", publicRateLimit);

let dbReady = false;
let routesRegistered = false;
/** @type {'pending'|'ready'|'failed'} */
let dbInitState = 'pending';

// Health check endpoint (always 200 so Railway liveness does not kill the process during DB init)
app.get('/health', (req, res) => {
  res.status(200).json({
    status: dbInitState === 'ready' ? 'ok' : dbInitState === 'failed' ? 'degraded' : 'starting',
    database: dbInitState,
    authReady: dbReady,
    routesRegistered,
    timestamp: new Date().toISOString(),
    service: 'curatering-backend',
    port: PORT,
    environment: process.env.NODE_ENV || 'development',
    databaseConfigured: Boolean(process.env.DATABASE_URL?.trim()),
  });
});

/**
 * Normalize RunPod worker input for txt2img / img2img.
 * Accepts several client field names for the venue photo; forwards `init_image_base64`.
 */
function controlnetScaleForDenoise(denoise) {
  return getControlNet(intensityFromStrength(denoise));
}

function clampUnit(value, fallback = 0.8) {
  const n = Number(value);
  return Number.isFinite(n) ? Math.min(1, Math.max(0, n)) : fallback;
}

function requestIntensity(input) {
  return clampUnit(
    input?.intensity ??
      input?.transformation_intensity ??
      input?.transformationIntensity,
    input?.strength != null ? intensityFromStrength(input.strength) : 0.8,
  );
}

function intensityFromStrength(strength) {
  const s = Number(strength);
  if (!Number.isFinite(s)) return 0.8;
  if (s < 0.55) return 0.3;
  if (s < 0.7) return 0.55;
  return 0.8;
}

function getStrength(intensity) {
  const value = clampUnit(intensity);
  if (value < 0.4) return 0.75;
  if (value < 0.7) return 0.82;
  return 0.9;
}

function getControlNet(intensity) {
  const value = clampUnit(intensity);
  if (value < 0.4) return 0.85;
  if (value < 0.7) return 0.65;
  return 0.55;
}

function getPreprocessor(intensity) {
  return "depth";
}

function getTransformationMode(intensity) {
  const value = clampUnit(intensity);
  if (value < 0.4) return "preserve";
  if (value < 0.7) return "modify";
  return "rebuild";
}

function normalizeRunpodInput(input) {
  const out = { ...input };
  const raw =
    out.init_image_base64 ??
    out.image_base64 ??
    out.venue_image_base64 ??
    out.venuePhotoBase64 ??
    out.base_image;
  if (typeof raw === "string" && raw.trim()) {
    let s = raw.trim();
    if (s.startsWith("data:")) {
      const comma = s.indexOf(",");
      s = comma >= 0 ? s.slice(comma + 1) : s;
    }
    const maxLen = Number(process.env.RUNPOD_MAX_INIT_IMAGE_B64_LEN || 8_000_000);
    if (s.length > maxLen) {
      const err = new Error(
        `init_image_base64 exceeds ${maxLen} characters — use a smaller venue photo`,
      );
      err.code = "payload_too_large";
      throw err;
    }
    // Keep aliases for current and legacy image workers. The current worker
    // reads `image_base64`/`venue_image_base64`, while older backend code used
    // `init_image_base64`.
    out.init_image_base64 = s;
    out.image_base64 = s;
    out.venue_image_base64 = s;
    out.image = s;
    delete out.venuePhotoBase64;
  }
  const hasInitImage = typeof out.init_image_base64 === "string" && out.init_image_base64.trim();
  const intensity = requestIntensity(out);
  if (hasInitImage) {
    out.strength = getStrength(intensity);
  } else if (out.strength != null) {
    const st = Number(out.strength);
    out.strength = Number.isFinite(st) ? Math.min(0.95, Math.max(0.15, st)) : 0.65;
  }
  const dynamicControlnetScale = hasInitImage ? getControlNet(intensity) : null;
  const preprocessor = getPreprocessor(intensity);
  if (out.controlnet && typeof out.controlnet === "object" && !Array.isArray(out.controlnet)) {
    const scale = Number(out.controlnet.conditioning_scale);
    out.controlnet = {
      ...out.controlnet,
      enabled: out.controlnet.enabled !== false,
      preprocessor: String(out.controlnet.preprocessor || preprocessor),
      conditioning_scale:
        dynamicControlnetScale ??
        (Number.isFinite(scale) ? Math.min(0.85, Math.max(0.4, scale)) : 0.45),
    };
  } else if (hasInitImage) {
    out.controlnet = {
      enabled: true,
      conditioning_scale: dynamicControlnetScale,
      preprocessor,
    };
  }
  if (out.controlnet_conditioning_scale != null) {
    const scale = Number(out.controlnet_conditioning_scale);
    out.controlnet_conditioning_scale =
      dynamicControlnetScale ??
      (Number.isFinite(scale) ? Math.min(0.85, Math.max(0.4, scale)) : 0.45);
  } else if (dynamicControlnetScale != null) {
    out.controlnet_conditioning_scale = dynamicControlnetScale;
  }
  const stepsRaw = out.num_inference_steps ?? out.steps;
  const steps = Number(stepsRaw);
  out.num_inference_steps = Number.isFinite(steps)
    ? Math.min(35, Math.max(25, Math.round(steps)))
    : 30;
  out.steps = out.num_inference_steps;
  const cfgRaw = out.guidance_scale ?? out.cfg_scale;
  const cfg = Number(cfgRaw);
  out.guidance_scale = Number.isFinite(cfg) ? Math.min(7.5, Math.max(6.5, cfg)) : 7;
  out.cfg_scale = out.guidance_scale;
  out.mode = out.mode || getTransformationMode(intensity);
  return out;
}

function shouldExpandEventDesignPrompt(input) {
  if (input?.nlp_expansion || input?.transformation_plan) return false;
  if (input?.use_nlp_prompt_expansion === false) return false;
  const taskType = String(input?.task_type || input?.task || "").trim().toLowerCase();
  return (
    taskType === "event_prompt_expansion" ||
    taskType === "event_design_image" ||
    taskType === "event_design" ||
    taskType === "sdxl_event_design" ||
    input?.use_nlp_prompt_expansion === true
  );
}

function normalizeRunpodEventPromptExpansion(output) {
  const result = output?.result || output?.analysis || output;
  if (!result || typeof result !== "object" || Array.isArray(result)) return null;
  const positivePrompt = String(result.positive_prompt || result.prompt || "").trim();
  if (!positivePrompt) return null;
  const recommendedStrength = Number(result.recommended_strength);
  return {
    prompt: positivePrompt,
    positive_prompt: positivePrompt,
    negative_prompt: String(result.negative_prompt || "").trim(),
    strength: Number.isFinite(Number(result.strength)) ? Number(result.strength) : undefined,
    cfg_scale: Number.isFinite(Number(result.cfg_scale)) ? Number(result.cfg_scale) : undefined,
    steps: Number.isFinite(Number(result.steps)) ? Math.round(Number(result.steps)) : undefined,
    controlnet:
      result.controlnet && typeof result.controlnet === "object" && !Array.isArray(result.controlnet)
        ? result.controlnet
        : undefined,
    mode: typeof result.mode === "string" ? result.mode : undefined,
    transformation_plan:
      result.transformation_plan &&
      typeof result.transformation_plan === "object" &&
      !Array.isArray(result.transformation_plan)
        ? result.transformation_plan
        : undefined,
    scene_graph:
      result.scene_graph && typeof result.scene_graph === "object" && !Array.isArray(result.scene_graph)
        ? result.scene_graph
        : undefined,
    theme_tokens: Array.isArray(result.theme_tokens) ? result.theme_tokens : [],
    visual_direction: Array.isArray(result.visual_direction) ? result.visual_direction : [],
    visual_keywords: Array.isArray(result.visual_keywords) ? result.visual_keywords : [],
    decor_elements: Array.isArray(result.decor_elements) ? result.decor_elements : [],
    style_tokens: Array.isArray(result.style_tokens) ? result.style_tokens : [],
    lighting_tokens: Array.isArray(result.lighting_tokens) ? result.lighting_tokens : [],
    decor_tokens: Array.isArray(result.decor_tokens) ? result.decor_tokens : [],
    negative_tokens: Array.isArray(result.negative_tokens) ? result.negative_tokens : [],
    recommended_strength: Number.isFinite(recommendedStrength)
      ? Math.min(0.9, Math.max(0.75, recommendedStrength))
      : Number.isFinite(Number(result.strength))
        ? Number(result.strength)
      : undefined,
  };
}

async function expandEventDesignPromptForRunpod(input) {
  if (!shouldExpandEventDesignPrompt(input)) return input;

  const nlpInput = {
    task_type: "event_prompt_expansion",
    event_type: input.event_type,
    theme: input.theme || input.style,
    style: input.style,
    mood: input.mood,
    colors: input.colors || input.color_palette,
    color_palette: input.color_palette || input.colors,
    decor: input.decor || input.decor_elements,
    decor_elements: input.decor_elements || input.decor,
    notes: input.notes || input.custom_instructions || input.prompt,
    custom_instructions: input.custom_instructions || input.notes,
    prompt: input.prompt,
  };

  try {
    const output = await expandEventPrompt(nlpInput);
    const expansion = normalizeRunpodEventPromptExpansion(output);
    if (!expansion) {
      return {
        ...input,
        nlp_warning: "OpenAI prompt expansion returned no usable prompt",
      };
    }
    return {
      ...input,
      ...expansion,
      prompt: expansion.positive_prompt,
      negative_prompt: expansion.negative_prompt || input.negative_prompt,
      strength: expansion.strength ?? expansion.recommended_strength ?? input.strength,
      cfg_scale: expansion.cfg_scale ?? input.cfg_scale,
      guidance_scale: expansion.cfg_scale ?? input.guidance_scale,
      steps: expansion.steps ?? input.steps,
      num_inference_steps: expansion.steps ?? input.num_inference_steps,
      controlnet: expansion.controlnet ?? input.controlnet,
      mode: expansion.mode ?? input.mode,
      scene_graph: expansion.scene_graph ?? input.scene_graph,
      transformation_plan: expansion.transformation_plan ?? input.transformation_plan,
      task_type: "sdxl_event_design",
      nlp_expansion: expansion,
    };
  } catch (e) {
    console.error("[openai] event prompt expansion failed:", e?.message || e);
    return {
      ...input,
      nlp_warning: String(e?.message || e),
    };
  }
}

function getRunpodInput(req, res) {
  const input = req.body?.input;
  if (input == null || typeof input !== "object" || Array.isArray(input)) {
    res.status(400).json({
      message: "JSON body must include an object field `input`",
      code: "bad_request",
    });
    return null;
  }
  return input;
}

function sendRunpodNotConfigured(res, service, error) {
  return res.status(503).json({
    message: error?.message || `RunPod ${service} service is not configured on this server`,
    code: "runpod_not_configured",
    service,
  });
}

function sendOpenAiNotConfigured(res, error) {
  return res.status(503).json({
    message: error?.message || "OPENAI_API_KEY is not configured on this server",
    code: "openai_not_configured",
    service: "openai",
  });
}

function completedOpenAiTask(output, extra = {}) {
  return {
    id: null,
    status: "COMPLETED",
    output,
    ...extra,
  };
}

function validateRunpodJobId(jobId) {
  return Boolean(jobId && jobId.length <= 240 && !/[?#/\\]/.test(jobId));
}

async function handleRunpodImageRun(req, res) {
  try {
    const input = getRunpodInput(req, res);
    if (!input) return;
    let normalized;
    try {
      normalized = await expandEventDesignPromptForRunpod(normalizeRunpodInput(input));
      const initLen =
        typeof normalized.init_image_base64 === "string"
          ? normalized.init_image_base64.length
          : 0;
      console.log(
        "[runpod proxy] job input:",
        initLen > 0 ? `img2img (venue b64 ${initLen} chars)` : "txt2img (no venue image)",
        "steps=",
        normalized.num_inference_steps ?? "default",
        "nlp=",
        normalized.nlp_expansion ? "expanded" : normalized.nlp_warning ? "fallback" : "skipped",
      );
    } catch (normErr) {
      if (normErr?.code === "payload_too_large") {
        return res.status(413).json({
          message: normErr.message,
          code: "payload_too_large",
        });
      }
      throw normErr;
    }
    const providerInput = prepareRunpodProviderInput(normalized);
    const { res: rp, data } = await runpodProxyRequest("image", "/run", {
      method: "POST",
      jsonBody: { input: providerInput },
    });
    if (rp.ok && data?.id) {
      console.log("[runpod proxy] job queued:", data.id, "status:", data.status);
    }
    return res.status(rp.status).json(data);
  } catch (e) {
    if (e?.code === "runpod_not_configured") {
      return sendRunpodNotConfigured(res, "image", e);
    }
    console.error("[runpod proxy] POST /run", e);
    return res.status(502).json({
      message: String(e?.message || e),
      code: "runpod_proxy_error",
    });
  }
}

async function handleRunpodImageStatus(req, res) {
  try {
    const jobId = String(req.params.jobId || "").trim();
    if (!validateRunpodJobId(jobId)) {
      return res.status(400).json({ message: "invalid job id", code: "bad_request" });
    }
    const { res: rp, data } = await runpodProxyRequest("image", `/status/${encodeURIComponent(jobId)}`, {
      method: "GET",
    });
    return res.status(rp.status).json(data);
  } catch (e) {
    if (e?.code === "runpod_not_configured") {
      return sendRunpodNotConfigured(res, "image", e);
    }
    console.error("[runpod proxy] GET /status", e);
    return res.status(502).json({
      message: String(e?.message || e),
      code: "runpod_proxy_error",
    });
  }
}

async function handleRunpodNanoImageResult(req, res) {
  try {
    const jobId = String(req.params.jobId || "").trim();
    if (!validateRunpodJobId(jobId)) {
      return res.status(400).json({ message: "invalid job id", code: "bad_request" });
    }

    const imageUrl = `https://image.runpod.ai/google-nano-banana-2-edit/${encodeURIComponent(jobId)}/result.png`;
    const upstream = await fetch(imageUrl, { method: "GET" });
    if (!upstream.ok) {
      const message = await upstream.text().catch(() => "");
      return res.status(upstream.status).json({
        message: message || `RunPod image result unavailable (${upstream.status})`,
        code: "runpod_image_result_unavailable",
      });
    }

    const contentType = upstream.headers.get("content-type") || "image/png";
    const body = Buffer.from(await upstream.arrayBuffer());
    res.set("Content-Type", contentType);
    res.set("Cache-Control", "public, max-age=86400, immutable");
    return res.status(200).send(body);
  } catch (e) {
    console.error("[runpod proxy] GET nano image result", e);
    return res.status(502).json({
      message: String(e?.message || e),
      code: "runpod_image_result_proxy_error",
    });
  }
}

/** Public image proxy to RunPod — API key stays in server env (Railway). */
app.post("/api/public/runpod/run", publicRateLimit, handleRunpodImageRun);
app.get("/api/public/runpod/status/:jobId", handleRunpodImageStatus);
app.post("/api/public/runpod/image/run", publicRateLimit, handleRunpodImageRun);
app.get("/api/public/runpod/image/status/:jobId", handleRunpodImageStatus);
app.get("/api/public/runpod/image/result/:jobId", handleRunpodNanoImageResult);

function publicNlpInput(req, res) {
  const input = getRunpodInput(req, res);
  if (!input) return null;
  const taskType = String(input.task_type || input.task || "").trim().toLowerCase();
  if (taskType !== "event_prompt_expansion") {
    res.status(400).json({
      message: "public NLP proxy only supports event_prompt_expansion",
      code: "bad_request",
    });
    return null;
  }
  return { ...input, task_type: "event_prompt_expansion" };
}

async function handlePublicRunpodNlpRun(req, res) {
  try {
    const input = publicNlpInput(req, res);
    if (!input) return;
    const output = await expandEventPrompt(input);
    return res.json(completedOpenAiTask(output));
  } catch (e) {
    if (e?.code === "openai_not_configured") {
      return sendOpenAiNotConfigured(res, e);
    }
    console.error("[public openai nlp proxy] POST /run", e);
    return res.status(502).json({
      message: String(e?.message || e),
      code: e?.code || "openai_proxy_error",
    });
  }
}

async function handlePublicRunpodNlpStatus(req, res) {
  return res.status(410).json({
    status: "COMPLETED",
    message: "NLP now runs synchronously through OpenAI; polling is no longer required.",
    code: "openai_sync_task",
  });
}

app.post("/api/public/runpod/nlp/run", publicRateLimit, handlePublicRunpodNlpRun);
app.get("/api/public/runpod/nlp/status/:jobId", publicRateLimit, handlePublicRunpodNlpStatus);

app.post(
  "/api/runpod/nlp/run",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "supervisor", "admin", "super_admin"])),
  async (req, res) => {
    try {
      const input = getRunpodInput(req, res);
      if (!input) return;
      const taskType = String(input.task_type || input.task || "").trim().toLowerCase();
      if (taskType === "health_check") {
        return res.json(
          completedOpenAiTask({
            status: "success",
            model: openAiModel(),
            openai_configured: isOpenAiConfigured(),
            nlp_online: isOpenAiConfigured(),
            message: "NLP is served by OpenAI from the backend.",
          }),
        );
      }
      const { output, latencyMs } = await runAiGatewayTask(taskType, input);
      return res.json(completedOpenAiTask(output, { latencyMs }));
    } catch (e) {
      if (e?.code === "openai_not_configured") {
        return sendOpenAiNotConfigured(res, e);
      }
      if (e?.code === "unsupported_ai_task") {
        return res.status(e.status || 400).json({
          status: "FAILED",
          message: e.message,
          code: e.code,
        });
      }
      console.error("[openai nlp proxy] POST /run", e);
      return res.status(502).json({
        message: String(e?.message || e),
        code: e?.code || "openai_proxy_error",
      });
    }
  },
);

function getFeedbackAnalysisInput(body) {
  const feedback = String(body?.feedback || "").trim();
  if (feedback) {
    if (feedback.length > 20_000) {
      const err = new Error("feedback is too long");
      err.status = 413;
      err.code = "payload_too_large";
      throw err;
    }
    return { feedback };
  }

  if (Array.isArray(body?.feedbacks)) {
    const feedbacks = body.feedbacks
      .map((item) => String(item || "").trim())
      .filter(Boolean);
    if (feedbacks.length === 0) {
      const err = new Error("feedbacks must include at least one non-empty entry");
      err.status = 400;
      err.code = "bad_request";
      throw err;
    }
    if (feedbacks.length > 100) {
      const err = new Error("feedbacks supports at most 100 entries");
      err.status = 413;
      err.code = "payload_too_large";
      throw err;
    }
    const totalChars = feedbacks.reduce((sum, item) => sum + item.length, 0);
    if (totalChars > 50_000) {
      const err = new Error("feedbacks payload is too long");
      err.status = 413;
      err.code = "payload_too_large";
      throw err;
    }
    return { feedbacks };
  }

  const err = new Error("feedback or feedbacks is required");
  err.status = 400;
  err.code = "bad_request";
  throw err;
}

async function ensureFeedbackAnalyticsSchema() {
  if (!feedbackAnalyticsSchemaPromise) {
    feedbackAnalyticsSchemaPromise = (async () => {
      await pool.query(`CREATE EXTENSION IF NOT EXISTS pgcrypto`);
      await pool.query(`
        CREATE TABLE IF NOT EXISTS feedback (
          id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          message TEXT NOT NULL,
          source TEXT NOT NULL DEFAULT 'web',
          customer_name TEXT,
          customer_email TEXT,
          rating INTEGER,
          status TEXT NOT NULL DEFAULT 'pending'
            CHECK (status IN ('pending','analyzed','error')),
          created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
          analyzed_at TIMESTAMPTZ
        )
      `);
      await pool.query(`
        ALTER TABLE feedback
        ADD COLUMN IF NOT EXISTS message TEXT,
        ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'web',
        ADD COLUMN IF NOT EXISTS customer_name TEXT,
        ADD COLUMN IF NOT EXISTS customer_email TEXT,
        ADD COLUMN IF NOT EXISTS rating INTEGER,
        ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending',
        ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        ADD COLUMN IF NOT EXISTS analyzed_at TIMESTAMPTZ
      `);
      await pool.query(`
        CREATE TABLE IF NOT EXISTS feedback_analysis (
          id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          batch_id uuid,
          feedback_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
          message TEXT NOT NULL DEFAULT '',
          sentiment TEXT,
          complaints JSONB NOT NULL DEFAULT '[]'::jsonb,
          praises JSONB NOT NULL DEFAULT '[]'::jsonb,
          insights JSONB NOT NULL DEFAULT '[]'::jsonb,
          key_topics JSONB NOT NULL DEFAULT '[]'::jsonb,
          summary TEXT NOT NULL DEFAULT '',
          ai_response JSONB NOT NULL DEFAULT '{}'::jsonb,
          created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
      `);
      await pool.query(`
        DO $$
        BEGIN
          IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = current_schema()
              AND table_name = 'feedback_analysis'
              AND column_name = 'original_feedback'
          ) AND NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = current_schema()
              AND table_name = 'feedback_analysis'
              AND column_name = 'message'
          ) THEN
            ALTER TABLE feedback_analysis RENAME COLUMN original_feedback TO message;
          END IF;
        END $$;
      `);
      await pool.query(`
        CREATE TABLE IF NOT EXISTS feedback_batches (
          id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          feedbacks JSONB NOT NULL DEFAULT '[]'::jsonb,
          overall_sentiment TEXT,
          sentiment_positive INTEGER NOT NULL DEFAULT 0,
          sentiment_neutral INTEGER NOT NULL DEFAULT 0,
          sentiment_negative INTEGER NOT NULL DEFAULT 0,
          top_topics JSONB NOT NULL DEFAULT '[]'::jsonb,
          summary TEXT NOT NULL DEFAULT '',
          ai_response JSONB NOT NULL DEFAULT '{}'::jsonb,
          created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
      `);
      await pool.query(`
        CREATE TABLE IF NOT EXISTS dashboard_insights (
          id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          analysis_type TEXT NOT NULL DEFAULT 'dashboard',
          range_key TEXT NOT NULL DEFAULT '7d',
          filter_key TEXT NOT NULL DEFAULT 'default',
          filters JSONB NOT NULL DEFAULT '{}'::jsonb,
          summary TEXT NOT NULL DEFAULT '',
          insights JSONB NOT NULL DEFAULT '[]'::jsonb,
          trends JSONB NOT NULL DEFAULT '[]'::jsonb,
          problems JSONB NOT NULL DEFAULT '[]'::jsonb,
          recommendations JSONB NOT NULL DEFAULT '[]'::jsonb,
          alerts JSONB NOT NULL DEFAULT '[]'::jsonb,
          explainability JSONB NOT NULL DEFAULT '[]'::jsonb,
          dashboard_data JSONB NOT NULL DEFAULT '{}'::jsonb,
          ai_response JSONB NOT NULL DEFAULT '{}'::jsonb,
          created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
      `);
      await pool.query(`
        CREATE TABLE IF NOT EXISTS ai_analysis_logs (
          id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          analysis_type TEXT NOT NULL DEFAULT 'dashboard',
          range_key TEXT,
          prompt TEXT NOT NULL DEFAULT '',
          input_data JSONB NOT NULL DEFAULT '{}'::jsonb,
          ai_response JSONB NOT NULL DEFAULT '{}'::jsonb,
          normalized_result JSONB NOT NULL DEFAULT '{}'::jsonb,
          created_by TEXT NULL,
          created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
      `);
      await pool.query(`
        ALTER TABLE ai_analysis_logs
        ADD COLUMN IF NOT EXISTS analysis_type TEXT NOT NULL DEFAULT 'dashboard',
        ADD COLUMN IF NOT EXISTS range_key TEXT,
        ADD COLUMN IF NOT EXISTS prompt TEXT NOT NULL DEFAULT '',
        ADD COLUMN IF NOT EXISTS input_data JSONB NOT NULL DEFAULT '{}'::jsonb,
        ADD COLUMN IF NOT EXISTS ai_response JSONB NOT NULL DEFAULT '{}'::jsonb,
        ADD COLUMN IF NOT EXISTS normalized_result JSONB NOT NULL DEFAULT '{}'::jsonb,
        ADD COLUMN IF NOT EXISTS created_by TEXT NULL,
        ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      `);
      await pool.query(`
        ALTER TABLE dashboard_insights
        ADD COLUMN IF NOT EXISTS analysis_type TEXT NOT NULL DEFAULT 'dashboard',
        ADD COLUMN IF NOT EXISTS range_key TEXT NOT NULL DEFAULT '7d',
        ADD COLUMN IF NOT EXISTS filter_key TEXT NOT NULL DEFAULT 'default',
        ADD COLUMN IF NOT EXISTS filters JSONB NOT NULL DEFAULT '{}'::jsonb,
        ADD COLUMN IF NOT EXISTS summary TEXT NOT NULL DEFAULT '',
        ADD COLUMN IF NOT EXISTS insights JSONB NOT NULL DEFAULT '[]'::jsonb,
        ADD COLUMN IF NOT EXISTS trends JSONB NOT NULL DEFAULT '[]'::jsonb,
        ADD COLUMN IF NOT EXISTS problems JSONB NOT NULL DEFAULT '[]'::jsonb,
        ADD COLUMN IF NOT EXISTS recommendations JSONB NOT NULL DEFAULT '[]'::jsonb,
        ADD COLUMN IF NOT EXISTS alerts JSONB NOT NULL DEFAULT '[]'::jsonb,
        ADD COLUMN IF NOT EXISTS explainability JSONB NOT NULL DEFAULT '[]'::jsonb,
        ADD COLUMN IF NOT EXISTS dashboard_data JSONB NOT NULL DEFAULT '{}'::jsonb,
        ADD COLUMN IF NOT EXISTS ai_response JSONB NOT NULL DEFAULT '{}'::jsonb,
        ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      `);
      await pool.query(`
        DO $$
        DECLARE
          col_name text;
        BEGIN
          FOREACH col_name IN ARRAY ARRAY[
            'insights',
            'trends',
            'problems',
            'recommendations',
            'alerts',
            'explainability'
          ] LOOP
            IF EXISTS (
              SELECT 1
              FROM information_schema.columns
              WHERE table_schema = current_schema()
                AND table_name = 'dashboard_insights'
                AND column_name = col_name
                AND data_type = 'ARRAY'
            ) THEN
              EXECUTE format('ALTER TABLE dashboard_insights ALTER COLUMN %I DROP DEFAULT', col_name);
              EXECUTE format(
                'ALTER TABLE dashboard_insights ALTER COLUMN %I TYPE jsonb USING COALESCE(to_jsonb(%I), ''[]''::jsonb)',
                col_name,
                col_name
              );
              EXECUTE format('ALTER TABLE dashboard_insights ALTER COLUMN %I SET DEFAULT ''[]''::jsonb', col_name);
              EXECUTE format('UPDATE dashboard_insights SET %I = ''[]''::jsonb WHERE %I IS NULL', col_name, col_name);
              EXECUTE format('ALTER TABLE dashboard_insights ALTER COLUMN %I SET NOT NULL', col_name);
            END IF;
          END LOOP;
        END $$;
      `);
      await pool.query(`
        ALTER TABLE feedback_analysis
        ADD COLUMN IF NOT EXISTS batch_id uuid,
        ADD COLUMN IF NOT EXISTS feedback_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
        ADD COLUMN IF NOT EXISTS message TEXT NOT NULL DEFAULT '',
        ADD COLUMN IF NOT EXISTS complaints JSONB NOT NULL DEFAULT '[]'::jsonb,
        ADD COLUMN IF NOT EXISTS praises JSONB NOT NULL DEFAULT '[]'::jsonb,
        ADD COLUMN IF NOT EXISTS insights JSONB NOT NULL DEFAULT '[]'::jsonb,
        ADD COLUMN IF NOT EXISTS key_topics JSONB NOT NULL DEFAULT '[]'::jsonb,
        ADD COLUMN IF NOT EXISTS summary TEXT NOT NULL DEFAULT '',
        ADD COLUMN IF NOT EXISTS ai_response JSONB NOT NULL DEFAULT '{}'::jsonb,
        ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      `);
      await pool.query(`
        ALTER TABLE feedback_analysis
        ALTER COLUMN message SET DEFAULT '',
        ALTER COLUMN message DROP NOT NULL
      `);
      await pool.query(`
        UPDATE feedback SET status = 'pending' WHERE status IS NULL
      `);
      await pool.query(`
        CREATE INDEX IF NOT EXISTS idx_feedback_analysis_created_at
        ON feedback_analysis (created_at DESC)
      `);
      await pool.query(`
        CREATE INDEX IF NOT EXISTS idx_feedback_status_created_at
        ON feedback (status, created_at DESC)
      `);
      await pool.query(`
        CREATE INDEX IF NOT EXISTS idx_feedback_batches_created_at
        ON feedback_batches (created_at DESC)
      `);
      await pool.query(`
        CREATE INDEX IF NOT EXISTS idx_dashboard_insights_range_created_at
        ON dashboard_insights (range_key, created_at DESC)
      `);
      await pool.query(`
        CREATE INDEX IF NOT EXISTS idx_dashboard_insights_type_filter_created_at
        ON dashboard_insights (analysis_type, range_key, filter_key, created_at DESC)
      `);
      await pool.query(`
        CREATE INDEX IF NOT EXISTS idx_ai_analysis_logs_type_created_at
        ON ai_analysis_logs (analysis_type, created_at DESC)
      `);
      try {
        await pool.query(`ALTER TABLE feedback ENABLE ROW LEVEL SECURITY`);
        await pool.query(`ALTER TABLE feedback_analysis ENABLE ROW LEVEL SECURITY`);
        await pool.query(`ALTER TABLE feedback_batches ENABLE ROW LEVEL SECURITY`);
        await pool.query(`ALTER TABLE dashboard_insights ENABLE ROW LEVEL SECURITY`);
        await pool.query(`ALTER TABLE ai_analysis_logs ENABLE ROW LEVEL SECURITY`);
      } catch (err) {
        console.warn("[feedback analytics] RLS enable skipped:", err?.message || err);
      }
    })().catch((err) => {
      feedbackAnalyticsSchemaPromise = null;
      throw err;
    });
  }
  return feedbackAnalyticsSchemaPromise;
}

function getFeedbackRunLimit(body, insertedCount = 0) {
  const raw = Number(body?.limit);
  const requested = Number.isFinite(raw) && raw > 0 ? Math.round(raw) : 50;
  return Math.min(100, Math.max(insertedCount, requested));
}

async function storeFeedbackRows(input) {
  await ensureFeedbackAnalyticsSchema();
  const messages = Array.isArray(input.feedbacks) ? input.feedbacks : [input.feedback];
  const rows = [];
  for (const message of messages) {
    const inserted = await pool.query(
      `INSERT INTO feedback (message, source, status)
       VALUES ($1, 'web', 'pending')
       RETURNING id, message, created_at AS "createdAt"`,
      [message],
    );
    rows.push(inserted.rows[0]);
  }
  return rows;
}

function getDashboardRange(rawRange) {
  const key = String(rawRange || "7d").trim().toLowerCase();
  const daysByKey = {
    "7d": 7,
    "30d": 30,
    "90d": 90,
  };
  const rangeKey = Object.prototype.hasOwnProperty.call(daysByKey, key) ? key : "7d";
  const end = new Date();
  const start = new Date(end.getTime() - daysByKey[rangeKey] * 24 * 60 * 60 * 1000);
  const previousStart = new Date(start.getTime() - daysByKey[rangeKey] * 24 * 60 * 60 * 1000);
  return { key: rangeKey, days: daysByKey[rangeKey], start, end, previousStart };
}

function normalizeDashboardAiFilters(raw = {}) {
  const range = getDashboardRange(raw.range || raw.rangeKey);
  const businessSide = String(raw.businessSide || "ALL").trim().toUpperCase();
  const cateringStyle = String(raw.cateringStyle || "ALL").trim().toUpperCase();
  const orderSource = String(raw.orderSource || "ALL").trim().toUpperCase();
  const normalizedSource =
    orderSource === "ONLINE"
      ? "ONLINE"
      : orderSource === "WALK_IN" || orderSource === "WALKIN"
        ? "WALK_IN"
        : orderSource === "POS_WEB"
          ? "WALK_IN"
          : orderSource === "WEB_APP" || orderSource === "MOBILE_APP"
            ? "ONLINE"
            : "ALL";
  return {
    range: range.key,
    businessSide:
      businessSide === "RESTAURANT" || businessSide === "CATERING" || businessSide === "CATERING_WITH_EVENT"
        ? businessSide
        : "ALL",
    cateringStyle:
      cateringStyle === "CATERING_ONLY" || cateringStyle === "CATERING_WITH_EVENT"
        ? cateringStyle
        : "ALL",
    orderSource: normalizedSource,
  };
}

function dashboardFilterKey(filters) {
  return [
    filters.range || "7d",
    filters.businessSide || "ALL",
    filters.cateringStyle || "ALL",
    filters.orderSource || "ALL",
  ].join("|");
}

function sentimentBucket(value) {
  const v = String(value || "").trim().toLowerCase();
  if (v === "positive") return "positive";
  if (v === "negative") return "negative";
  return "neutral";
}

function addTopicCounts(topicCount, values) {
  if (!Array.isArray(values)) return;
  for (const raw of values) {
    const topic = String(raw || "").trim();
    if (!topic) continue;
    topicCount[topic] = (topicCount[topic] || 0) + 1;
  }
}

function aggregateDashboardFeedback(rows) {
  const sentiment = { positive: 0, negative: 0, neutral: 0 };
  const topicCount = {};
  let complaintCount = 0;
  let praiseCount = 0;
  let insightCount = 0;

  for (const item of rows) {
    sentiment[sentimentBucket(item.sentiment)] += 1;
    const complaints = Array.isArray(item.complaints) ? item.complaints : [];
    const praises = Array.isArray(item.praises) ? item.praises : [];
    const insights = Array.isArray(item.insights) ? item.insights : [];
    complaintCount += complaints.length;
    praiseCount += praises.length;
    insightCount += insights.length;
    addTopicCounts(topicCount, item.key_topics);
    addTopicCounts(topicCount, complaints);
    addTopicCounts(topicCount, praises);
  }

  return {
    total: rows.length,
    sentiment,
    complaint_count: complaintCount,
    praise_count: praiseCount,
    insight_count: insightCount,
    top_topics: Object.entries(topicCount)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([topic, count]) => ({ topic, count })),
  };
}

function detectDashboardAlerts(today, yesterday) {
  const alerts = [];
  if (yesterday.negative > 0 && today.negative > yesterday.negative * 1.5) {
    alerts.push({
      type: "negative_sentiment_spike",
      severity: "high",
      message: "Negative sentiment spike detected",
    });
  }
  if (yesterday.complaint_count > 0 && today.complaint_count > yesterday.complaint_count * 1.5) {
    alerts.push({
      type: "complaint_surge",
      severity: "medium",
      message: "Complaint surge detected",
    });
  }
  if (yesterday.total > 0 && today.total > yesterday.total * 2) {
    alerts.push({
      type: "feedback_volume_increase",
      severity: "medium",
      message: "Unusual feedback volume increase",
    });
  }
  return alerts;
}

function buildDashboardExplainability({ current, previous, filters, alerts }) {
  const points = [];
  if (previous.total > 0) {
    const delta = Math.round(((current.total - previous.total) / previous.total) * 100);
    if (Math.abs(delta) >= 20) {
      points.push(
        `${Math.abs(delta)}% ${delta < 0 ? "decrease" : "increase"} in analyzed feedback volume`,
      );
    }
  }
  if (previous.negative > 0) {
    const delta = Math.round(((current.sentiment.negative - previous.negative) / previous.negative) * 100);
    if (Math.abs(delta) >= 20) {
      points.push(
        `${Math.abs(delta)}% ${delta < 0 ? "decrease" : "increase"} in negative feedback signals`,
      );
    }
  }
  if (current.complaint_count > 0) {
    points.push(`${current.complaint_count} complaint signal(s) found in the selected period`);
  }
  if (current.top_topics?.length) {
    points.push(`top detected topics: ${current.top_topics.map((item) => item.topic).join(", ")}`);
  }
  if (filters.businessSide !== "ALL") {
    points.push(`analysis filtered to ${filters.businessSide.toLowerCase().replaceAll("_", " ")}`);
  }
  if (filters.orderSource !== "ALL") {
    points.push(`orders filtered to ${filters.orderSource.toLowerCase().replaceAll("_", " ")}`);
  }
  if (Array.isArray(alerts) && alerts.length) {
    points.push(`${alerts.length} operational alert(s) were detected before model analysis`);
  }
  return points.slice(0, 8);
}

function normalizeDashboardAiResult(output) {
  const parsed = extractRunpodNlpResult(output) || output?.analysis || output;
  const data = parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
  const list = (value, max = 8) => toStringArray(value, max);
  const explainability = list(
    data.explainability || data.explanation_points || data.detected_factors || data.factors,
    10,
  );
  const alerts = Array.isArray(data.alerts)
    ? data.alerts
        .map((item) => {
          if (item && typeof item === "object") {
            return {
              type: String(item.type || "alert"),
              severity: String(item.severity || "info"),
              message: String(item.message || item.summary || "").trim(),
              explanation: String(item.explanation || "").trim(),
            };
          }
          return {
            type: "alert",
            severity: "info",
            message: String(item || "").trim(),
            explanation: "",
          };
        })
        .filter((item) => item.message)
        .slice(0, 8)
    : [];

  return {
    summary: String(data.summary || "").trim(),
    insights: list(data.insights),
    trends: list(data.trends),
    problems: list(data.problems),
    recommendations: list(data.recommendations),
    alerts,
    explainability,
  };
}

async function queryDashboardAnalysisRows(start, end) {
  const result = await pool.query(
    `SELECT
       sentiment,
       complaints,
       praises,
       insights,
       key_topics,
       created_at
     FROM feedback_analysis
     WHERE created_at >= $1 AND created_at < $2
     ORDER BY created_at DESC
     LIMIT 1000`,
    [start, end],
  );
  return result.rows;
}

async function runAiGatewayTask(taskType, input, options = {}) {
  const startedAt = Date.now();
  let output;
  if (taskType === "dashboard_analysis") {
    output = await analyzeDashboard(input);
  } else if (taskType === "dish_trends") {
    output = await analyzeDishTrends(input);
  } else if (taskType === "event_prompt_expansion" || taskType === "event_design") {
    output = await expandEventPrompt(input);
  } else {
    const err = new Error(`Unsupported OpenAI task: ${taskType}`);
    err.code = "unsupported_ai_task";
    err.status = 400;
    throw err;
  }
  return {
    output,
    latencyMs: Date.now() - startedAt,
  };
}

async function getCachedDashboardInsight({ analysisType = "dashboard", rangeKey, filterKey }) {
  await ensureFeedbackAnalyticsSchema();
  const result = await pool.query(
    `SELECT *
     FROM dashboard_insights
     WHERE analysis_type = $1
       AND range_key = $2
       AND filter_key = $3
     ORDER BY created_at DESC
     LIMIT 1`,
    [analysisType, rangeKey, filterKey],
  );
  return serializeDashboardInsight(result.rows[0] || null);
}

async function storeDashboardInsight({
  analysisType = "dashboard",
  range,
  filters,
  prompt,
  dashboardData,
  aiResponse,
  normalized,
  createdBy = null,
}) {
  const filterKey = dashboardFilterKey(filters);
  const stored = await pool.query(
    `INSERT INTO dashboard_insights (
       analysis_type,
       range_key,
       filter_key,
       filters,
       summary,
       insights,
       trends,
       problems,
       recommendations,
       alerts,
       explainability,
       dashboard_data,
       ai_response
     ) VALUES ($1, $2, $3, $4::jsonb, $5, $6::jsonb, $7::jsonb, $8::jsonb, $9::jsonb, $10::jsonb, $11::jsonb, $12::jsonb, $13::jsonb)
     RETURNING *`,
    [
      analysisType,
      range.key,
      filterKey,
      JSON.stringify(filters),
      normalized.summary,
      JSON.stringify(normalized.insights),
      JSON.stringify(normalized.trends),
      JSON.stringify(normalized.problems),
      JSON.stringify(normalized.recommendations),
      JSON.stringify(normalized.alerts),
      JSON.stringify(normalized.explainability || []),
      JSON.stringify(dashboardData),
      JSON.stringify(aiResponse),
    ],
  );

  await pool.query(
    `INSERT INTO ai_analysis_logs (
       analysis_type,
       range_key,
       prompt,
       input_data,
       ai_response,
       normalized_result,
       created_by
     ) VALUES ($1, $2, $3, $4::jsonb, $5::jsonb, $6::jsonb, $7)`,
    [
      analysisType,
      range.key,
      prompt,
      JSON.stringify(dashboardData),
      JSON.stringify(aiResponse),
      JSON.stringify(normalized),
      createdBy,
    ],
  );

  return serializeDashboardInsight(stored.rows[0]);
}

async function analyzeDashboardThroughGateway({
  rangeKey = "7d",
  filters = {},
  prompt = "",
  requestDashboardData = {},
  analysisType = "dashboard",
  createdBy = null,
} = {}) {
  await ensureFeedbackAnalyticsSchema();
  const range = getDashboardRange(rangeKey);
  const normalizedFilters = normalizeDashboardAiFilters({
    ...filters,
    range: range.key,
  });
  const currentRows = await queryDashboardAnalysisRows(range.start, range.end);
  const previousRows = await queryDashboardAnalysisRows(range.previousStart, range.start);
  const current = aggregateDashboardFeedback(currentRows);
  const previous = aggregateDashboardFeedback(previousRows);
  const alerts = detectDashboardAlerts(
    {
      total: current.total,
      negative: current.sentiment.negative,
      complaint_count: current.complaint_count,
    },
    {
      total: previous.total,
      negative: previous.sentiment.negative,
      complaint_count: previous.complaint_count,
    },
  );
  const explainability = buildDashboardExplainability({
    current,
    previous,
    filters: normalizedFilters,
    alerts,
  });
  const dashboardData = {
    range: range.key,
    start: range.start.toISOString(),
    end: range.end.toISOString(),
    filters: normalizedFilters,
    current,
    previous,
    alerts,
    explainability,
    prompt,
    client_dashboard: requestDashboardData,
  };
  const { output: aiResponse, latencyMs } = await runAiGatewayTask(
    "dashboard_analysis",
    {
      dashboard_data: dashboardData,
      dashboard_filters: normalizedFilters,
      alerts,
      explainability,
      ...(prompt ? { prompt } : {}),
    },
  );
  const normalized = normalizeDashboardAiResult(aiResponse);
  if (!normalized.summary) {
    normalized.summary =
      current.total > 0
        ? `Analyzed ${current.total} feedback analysis record(s) for the last ${range.days} days.`
        : `No feedback analysis records found for the last ${range.days} days.`;
  }
  normalized.explainability = normalized.explainability?.length
    ? normalized.explainability
    : explainability;
  normalized.alerts = normalized.alerts.length ? normalized.alerts : alerts;

  const stored = await storeDashboardInsight({
    analysisType,
    range,
    filters: normalizedFilters,
    prompt,
    dashboardData: { ...dashboardData, latencyMs },
    aiResponse,
    normalized,
    createdBy,
  });
  return {
    data: stored,
    dashboardData,
    latencyMs,
  };
}

function serializeDashboardInsight(row) {
  if (!row) return null;
  const jsonArray = (value) => (Array.isArray(value) ? value : []);
  return {
    id: String(row.id || ""),
    analysisType: String(row.analysis_type || "dashboard"),
    range: String(row.range_key || row.range || "7d"),
    filterKey: String(row.filter_key || "default"),
    filters: row.filters && typeof row.filters === "object" ? row.filters : {},
    summary: String(row.summary || ""),
    insights: jsonArray(row.insights),
    trends: jsonArray(row.trends),
    problems: jsonArray(row.problems),
    recommendations: jsonArray(row.recommendations),
    alerts: jsonArray(row.alerts),
    explainability: jsonArray(row.explainability),
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
  };
}

function toStringArray(value, max = 5) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => String(item || "").trim()).filter(Boolean).slice(0, max);
}

function normalizeSingleFeedbackResult(aiResponse) {
  const result = extractRunpodNlpResult(aiResponse);
  if (!result || typeof result !== "object" || Array.isArray(result)) return null;
  return {
    sentiment: String(result.sentiment || "").trim(),
    key_topics: toStringArray(result.key_topics, 5),
    summary: String(result.summary || "").trim(),
  };
}

function normalizeBatchFeedbackResult(aiResponse) {
  const result = extractRunpodNlpResult(aiResponse);
  if (!result || typeof result !== "object" || Array.isArray(result)) return null;
  const distribution =
    result.sentiment_distribution &&
    typeof result.sentiment_distribution === "object" &&
    !Array.isArray(result.sentiment_distribution)
      ? result.sentiment_distribution
      : {};
  const toCount = (value) => {
    const n = Number(value);
    return Number.isFinite(n) ? Math.max(0, Math.round(n)) : 0;
  };
  return {
    overall_sentiment: String(result.overall_sentiment || "").trim(),
    sentiment_distribution: {
      positive: toCount(distribution.positive),
      neutral: toCount(distribution.neutral),
      negative: toCount(distribution.negative),
    },
    top_topics: toStringArray(result.top_topics, 5),
    summary: String(result.summary || "").trim(),
  };
}

async function storeFeedbackAnalysis(input, aiResponse) {
  await ensureFeedbackAnalyticsSchema();
  if (Array.isArray(input.feedbacks)) {
    const result = normalizeBatchFeedbackResult(aiResponse);
    if (!result) {
      const err = new Error("Invalid AI response");
      err.status = 500;
      err.code = "invalid_ai_response";
      throw err;
    }
    await pool.query(
      `INSERT INTO feedback_batches (
         feedbacks,
         overall_sentiment,
         sentiment_positive,
         sentiment_neutral,
         sentiment_negative,
         top_topics,
         summary,
         ai_response
       ) VALUES ($1::jsonb, $2, $3, $4, $5, $6::jsonb, $7, $8::jsonb)`,
      [
        JSON.stringify(input.feedbacks),
        result.overall_sentiment,
        result.sentiment_distribution.positive,
        result.sentiment_distribution.neutral,
        result.sentiment_distribution.negative,
        JSON.stringify(result.top_topics),
        result.summary,
        JSON.stringify(aiResponse),
      ],
    );
    return result;
  }

  const result = normalizeSingleFeedbackResult(aiResponse);
  if (!result) {
    const err = new Error("Invalid AI response");
    err.status = 500;
    err.code = "invalid_ai_response";
    throw err;
  }
  await pool.query(
    `INSERT INTO feedback_analysis (
       message,
       sentiment,
       key_topics,
       summary,
       ai_response
     ) VALUES ($1, $2, $3::jsonb, $4, $5::jsonb)`,
    [
      input.feedback,
      result.sentiment,
      JSON.stringify(result.key_topics),
      result.summary,
      JSON.stringify(aiResponse),
    ],
  );
  return result;
}

async function markFeedbackRowsAnalyzed(feedbackRows) {
  const ids = (Array.isArray(feedbackRows) ? feedbackRows : [])
    .map((row) => row?.id)
    .filter(Boolean);
  if (ids.length === 0) return;
  await pool.query(
    `UPDATE feedback
     SET status = 'analyzed', analyzed_at = now()
     WHERE id = ANY($1::uuid[])`,
    [ids],
  );
}

async function analyzeFeedbackInputWithOpenAi(input, feedbackRows) {
  const aiResponse = Array.isArray(input.feedbacks)
    ? await analyzeFeedbackBatch(input.feedbacks)
    : await analyzeSingleFeedback(input.feedback);
  const result = await storeFeedbackAnalysis(input, aiResponse);
  await markFeedbackRowsAnalyzed(feedbackRows);
  return {
    aiResponse,
    result,
    processed: Array.isArray(feedbackRows) ? feedbackRows.length : 0,
  };
}

app.post(
  "/api/runpod/nlp/analyze",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "supervisor", "admin", "super_admin"])),
  async (req, res) => {
    try {
      const input = getFeedbackAnalysisInput(req.body);
      const feedbackRows = await storeFeedbackRows(input);
      const { result, processed } = await analyzeFeedbackInputWithOpenAi(input, feedbackRows);
      return res.json({
        success: true,
        feedbackIds: feedbackRows.map((row) => String(row.id)),
        batchId: null,
        processed,
        data: result,
      });
    } catch (e) {
      if (e?.code === "openai_not_configured") {
        return sendOpenAiNotConfigured(res, e);
      }
      if (e?.code === "bad_request" || e?.code === "payload_too_large") {
        return res.status(e.status || 400).json({
          message: e.message,
          code: e.code,
        });
      }
      console.error("[openai feedback] analyze failed", e);
      return res.status(e?.status || 500).json({
        error: e?.code === "invalid_ai_response" ? "Invalid AI response" : "Feedback analysis failed",
        code: e?.code || "feedback_analysis_failed",
      });
    }
  },
);

app.post("/api/feedback/analyze", publicRateLimit, async (req, res) => {
  try {
    const input = getFeedbackAnalysisInput(req.body);
    const feedbackRows = await storeFeedbackRows(input);
    const { result, processed } = await analyzeFeedbackInputWithOpenAi(input, feedbackRows);
    return res.json({
      success: true,
      feedbackIds: feedbackRows.map((row) => String(row.id)),
      batchId: null,
      processed,
      data: result,
    });
  } catch (e) {
    if (e?.code === "openai_not_configured") {
      return sendOpenAiNotConfigured(res, e);
    }
    if (e?.code === "bad_request" || e?.code === "payload_too_large") {
      return res.status(e.status || 400).json({
        message: e.message,
        code: e.code,
      });
    }
    console.error("[feedback analyze] OpenAI failed", e);
    return res.status(e?.status || 500).json({
      error: e?.code === "invalid_ai_response" ? "Invalid AI response" : "Feedback analysis failed",
      code: e?.code || "feedback_analysis_failed",
    });
  }
});

app.post("/api/contact-feedback", publicRateLimit, async (req, res) => {
  try {
    await ensureFeedbackAnalyticsSchema();
    const name = String(req.body?.name || "").trim().slice(0, 160);
    const email = String(req.body?.email || "").trim().toLowerCase().slice(0, 240);
    const message = String(req.body?.message || req.body?.feedback || "").trim();
    const ratingRaw = Number(req.body?.rating);
    const rating = Number.isFinite(ratingRaw)
      ? Math.max(1, Math.min(5, Math.round(ratingRaw)))
      : null;

    if (message.length < 3) {
      return res.status(400).json({ error: "Feedback message is required" });
    }
    if (message.length > 5000) {
      return res.status(413).json({ error: "Feedback message is too long" });
    }

    const result = await pool.query(
      `INSERT INTO feedback (message, source, customer_name, customer_email, rating, status)
       VALUES ($1, 'contact_us', $2, $3, $4, 'pending')
       RETURNING id, created_at AS "createdAt"`,
      [message, name || null, email || null, rating],
    );

    return res.status(201).json({
      ok: true,
      feedback: {
        id: String(result.rows[0].id),
        createdAt: result.rows[0].createdAt?.toISOString?.() || null,
      },
    });
  } catch (e) {
    console.error("[contact feedback] submit failed", e);
    return res.status(500).json({ error: "Failed to submit feedback" });
  }
});

app.post(
  "/api/dashboard/analyze",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "supervisor", "admin", "super_admin"])),
  async (req, res) => {
    try {
      const requestInput =
        req.body?.input && typeof req.body.input === "object" && !Array.isArray(req.body.input)
          ? req.body.input
          : {};
      const prompt = String(requestInput.prompt || req.body?.prompt || "").trim().slice(0, 4000);
      const filters = normalizeDashboardAiFilters({
        ...(requestInput.filters || {}),
        range: req.body?.range || requestInput.range,
        businessSide: req.body?.businessSide || requestInput.businessSide,
        cateringStyle: req.body?.cateringStyle || requestInput.cateringStyle,
        orderSource: req.body?.orderSource || requestInput.orderSource,
      });
      const generated = await analyzeDashboardThroughGateway({
        rangeKey: filters.range,
        filters,
        prompt,
        requestDashboardData: requestInput.dashboard_data || {},
        analysisType: "dashboard",
        createdBy: req.user?.id || null,
      });

      return res.json({
        success: true,
        data: generated.data,
        dashboardData: generated.dashboardData,
        latencyMs: generated.latencyMs,
      });
    } catch (e) {
      if (e?.code === "openai_not_configured") {
        return sendOpenAiNotConfigured(res, e);
      }
      console.error("[dashboard analyze] failed", e);
      return res.status(e?.status || 500).json({
        error: "Dashboard analysis failed",
        message: String(e?.message || e),
        code: e?.code || "dashboard_analysis_failed",
      });
    }
  },
);

app.get(
  "/api/dashboard/insights",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "supervisor", "admin", "super_admin"])),
  async (req, res) => {
    try {
      await ensureFeedbackAnalyticsSchema();
      const filters = normalizeDashboardAiFilters({
        range: req.query?.range,
        businessSide: req.query?.businessSide,
        cateringStyle: req.query?.cateringStyle,
        orderSource: req.query?.orderSource,
      });
      const analysisType = String(req.query?.analysisType || "dashboard").trim() || "dashboard";
      const data = await getCachedDashboardInsight({
        analysisType,
        rangeKey: filters.range,
        filterKey: dashboardFilterKey(filters),
      });
      return res.json({
        success: true,
        data,
      });
    } catch (e) {
      console.error("[dashboard insights] failed", e);
      return res.status(500).json({
        error: "Failed to load dashboard insights",
        message: String(e?.message || e),
        code: "dashboard_insights_failed",
      });
    }
  },
);

app.get(
  "/api/ai/dashboard/cached",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "supervisor", "admin", "super_admin"])),
  async (req, res) => {
    try {
      const filters = normalizeDashboardAiFilters(req.query || {});
      const analysisType = String(req.query?.analysisType || "dashboard").trim() || "dashboard";
      const data = await getCachedDashboardInsight({
        analysisType,
        rangeKey: filters.range,
        filterKey: dashboardFilterKey(filters),
      });
      return res.json({ success: true, data, filters });
    } catch (e) {
      console.error("[ai gateway] cached dashboard failed", e);
      return res.status(500).json({
        message: String(e?.message || e),
        code: "ai_cached_dashboard_failed",
      });
    }
  },
);

let aiSchedulerStarted = false;

const scheduledAiJobs = [
  {
    analysisType: "nightly_summary",
    intervalMs: 24 * 60 * 60 * 1000,
    rangeKey: "7d",
    filters: normalizeDashboardAiFilters({ range: "7d" }),
    prompt: "Create a concise nightly management summary with urgent alerts and next-day actions.",
  },
  {
    analysisType: "weekly_business_report",
    intervalMs: 7 * 24 * 60 * 60 * 1000,
    rangeKey: "30d",
    filters: normalizeDashboardAiFilters({ range: "30d" }),
    prompt:
      "Create a weekly business report covering sales trends, operations, catering pipeline, and recommendations.",
  },
  {
    analysisType: "monthly_trend_analysis",
    intervalMs: 30 * 24 * 60 * 60 * 1000,
    rangeKey: "90d",
    filters: normalizeDashboardAiFilters({ range: "90d" }),
    prompt:
      "Create a monthly trend analysis with demand shifts, premium dish signals, event package trends, and risks.",
  },
];

async function runScheduledAiJob({ analysisType, rangeKey, filters, prompt }) {
  try {
    const filterKey = dashboardFilterKey(filters);
    const cached = await getCachedDashboardInsight({
      analysisType,
      rangeKey,
      filterKey,
    });
    if (cached?.createdAt) {
      const cachedAt = new Date(cached.createdAt).getTime();
      const job = scheduledAiJobs.find((item) => item.analysisType === analysisType);
      if (Number.isFinite(cachedAt) && job && Date.now() - cachedAt < job.intervalMs) {
        return;
      }
    }
    console.log(`[ai scheduler] starting ${analysisType}`);
    await analyzeDashboardThroughGateway({
      rangeKey,
      filters: {
        ...filters,
        range: rangeKey,
      },
      prompt,
      analysisType,
      createdBy: "ai_scheduler",
    });
    console.log(`[ai scheduler] completed ${analysisType}`);
  } catch (e) {
    console.error(`[ai scheduler] ${analysisType} failed`, e?.message || e);
  }
}

function shouldRunScheduledJob(lastRun, intervalMs) {
  return !lastRun || Date.now() - lastRun >= intervalMs;
}

function startAiAnalyticsScheduler() {
  if (aiSchedulerStarted || process.env.AI_SCHEDULER_DISABLED === "1") return;
  aiSchedulerStarted = true;

  const lastRunByType = new Map();

  const tick = async () => {
    if (!dbReady) return;
    for (const job of scheduledAiJobs) {
      const lastRun = lastRunByType.get(job.analysisType);
      if (!shouldRunScheduledJob(lastRun, job.intervalMs)) continue;
      lastRunByType.set(job.analysisType, Date.now());
      await runScheduledAiJob(job);
    }
  };

  setTimeout(tick, 60_000);
  setInterval(tick, 60 * 60 * 1000);
}

app.get(
  "/api/runpod/nlp/status/:jobId",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "supervisor", "admin", "super_admin"])),
  async (req, res) => {
    return res.status(410).json({
      status: "COMPLETED",
      message: "NLP now runs synchronously through OpenAI; polling is no longer required.",
      code: "openai_sync_task",
    });
  },
);
app.use(express.urlencoded({ limit: REQUEST_BODY_LIMIT, extended: true }));

const PORT = process.env.PORT ? Number(process.env.PORT) : 3000;
const JWT_SECRET = process.env.JWT_SECRET || "dev-change-me";
const isProduction =
  String(process.env.NODE_ENV || "").toLowerCase() === "production";
if (
  isProduction &&
  (!process.env.JWT_SECRET?.trim() ||
    process.env.JWT_SECRET.trim() === "dev-change-me")
) {
  console.error(
    "[startup] JWT_SECRET must be set to a strong value when NODE_ENV=production",
  );
  process.exit(1);
}
const connectionString = process.env.DATABASE_URL?.trim() || "";
const sql = connectionString
  ? postgres(connectionString, {
      ssl:
        connectionString.toLowerCase().includes("supabase.co") ||
        process.env.PG_SSL === "1"
          ? { rejectUnauthorized: false }
          : undefined,
    })
  : null;

if (!connectionString) {
  console.error(
    "[startup] DATABASE_URL is not set — link Postgres on Railway or set DATABASE_URL in service variables.",
  );
}

// Avoid exiting the API process on transient DB errors from async route handlers.
process.on("unhandledRejection", (reason, p) => {
  console.error("Unhandled Rejection:", reason, p);
});
const FASTAPI_URL = String(
  process.env.FASTAPI_INTERNAL_URL || process.env.AI_SERVICE_BASE_URL || "",
).replace(/\/+$/, "");
const AI_SERVICE_TOKEN = process.env.AI_SERVICE_TOKEN || "";
const AI_SERVICE_TIMEOUT_SEGMENT_MS = Number(process.env.AI_SERVICE_TIMEOUT_SEGMENT_MS || 20000);
const AI_SERVICE_TIMEOUT_RECOLOR_MS = Number(process.env.AI_SERVICE_TIMEOUT_RECOLOR_MS || 8000);
const AI_SERVICE_TIMEOUT_COMPOSE_MS = Number(process.env.AI_SERVICE_TIMEOUT_COMPOSE_MS || 12000);
const AI_SERVICE_TIMEOUT_ADD_BY_PROMPT_MS = Number(process.env.AI_SERVICE_TIMEOUT_ADD_BY_PROMPT_MS || 180000);
const AI_SERVICE_MAX_IMAGE_BYTES = Number(process.env.AI_SERVICE_MAX_IMAGE_BYTES || 8_000_000);
const AI_SERVICE_SEGMENT_TIMEOUT_RETRIES = Math.max(
  0,
  Number(process.env.AI_SERVICE_SEGMENT_TIMEOUT_RETRIES || 1),
);

/** RunPod serverless — proxied so API keys never ship in the Flutter web bundle. */
const RUNPOD_API_KEY = String(
  process.env.RUNPOD_API_KEY_NANO || process.env.RUNPOD_API_KEY || "",
).trim();
const RUNPOD_IMAGE_ENDPOINT_ID = String(
  process.env.RUNPOD_NANO_ENDPOINT_ID ||
    process.env.RUNPOD_IMAGE_ENDPOINT_ID ||
    process.env.RUNPOD_ENDPOINT_ID ||
    "",
).trim();
const RUNPOD_API_BASE = "https://api.runpod.ai/v2";

function getRunpodEndpointId() {
  return RUNPOD_IMAGE_ENDPOINT_ID;
}

function isNanoRunpodEndpoint() {
  const endpointId = getRunpodEndpointId().toLowerCase();
  return (
    Boolean(String(process.env.RUNPOD_NANO_ENDPOINT_ID || "").trim()) ||
    endpointId.includes("nano-banana")
  );
}

function normalizeNanoImageInput(value) {
  const image = String(value || "").trim();
  if (!image) return "";
  if (/^https?:\/\//i.test(image) || /^data:image\//i.test(image)) return image;
  return `data:image/png;base64,${image}`;
}

function prepareRunpodProviderInput(input) {
  if (!isNanoRunpodEndpoint()) return input;
  const rawImage =
    Array.isArray(input.images) && input.images.length > 0
      ? input.images[0]
      : input.image ??
        input.image_base64 ??
        input.init_image_base64 ??
        input.venue_image_base64 ??
        input.base_image;
  const image = normalizeNanoImageInput(rawImage);
  return {
    prompt: input.prompt,
    resolution: input.resolution || "1k",
    output_format: input.output_format || "png",
    enable_safety_checker: input.enable_safety_checker !== false,
    images: image ? [image] : [],
  };
}

async function runpodProxyRequest(service, pathSuffix, { method = "GET", jsonBody } = {}) {
  const endpointId = getRunpodEndpointId();
  if (!RUNPOD_API_KEY || !endpointId) {
    const keyName = "RUNPOD_API_KEY_NANO or RUNPOD_API_KEY";
    const envName = "RUNPOD_NANO_ENDPOINT_ID, RUNPOD_IMAGE_ENDPOINT_ID, or RUNPOD_ENDPOINT_ID";
    const err = new Error(`${keyName} and ${envName} must be set on the server`);
    err.code = "runpod_not_configured";
    err.service = service;
    throw err;
  }
  const path = pathSuffix.startsWith("/") ? pathSuffix : `/${pathSuffix}`;
  const url = `${RUNPOD_API_BASE}/${endpointId}${path}`;
  const headers = {
    Authorization: `Bearer ${RUNPOD_API_KEY}`,
    ...(jsonBody != null ? { "Content-Type": "application/json" } : {}),
  };
  const res = await fetch(url, {
    method,
    headers,
    ...(jsonBody != null ? { body: JSON.stringify(jsonBody) } : {}),
  });
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    data = { message: text || "Invalid JSON from RunPod", raw: true };
  }
  return { res, data };
}

const allowedRoles = new Set(["admin", "manager", "supervisor", "super_admin", "cashier"]);
const allowedHelpStatuses = new Set(["unresolved", "resolved"]);
let feedbackAnalyticsSchemaPromise = null;

const themePromptColorMap = [
  { keyword: "orange", hex: "#f4511e" },
  { keyword: "green", hex: "#1db954" },
  { keyword: "blue", hex: "#1976d2" },
  { keyword: "pink", hex: "#e91e63" },
  { keyword: "purple", hex: "#6a1b9a" },
  { keyword: "yellow", hex: "#ffc024" },
  { keyword: "red", hex: "#d32f2f" },
  { keyword: "teal", hex: "#00796b" },
  { keyword: "brown", hex: "#5d4037" },
  { keyword: "gray", hex: "#455a64" },
  { keyword: "grey", hex: "#455a64" },
];

function resolveThemeTintColor(prompt, fallback = "#f4511e") {
  const normalized = String(prompt || "").trim().toLowerCase();
  const hexMatch = normalized.match(/^#?([0-9a-f]{6})$/i);
  if (hexMatch) {
    return `#${hexMatch[1].toLowerCase()}`;
  }
  for (const entry of themePromptColorMap) {
    if (normalized.includes(entry.keyword)) return entry.hex;
  }
  return String(fallback || "#f4511e").toLowerCase();
}

/** Large base64 theme boards — omit from list endpoints; client loads full order by id for detail. */
function compactEventOrderRow(row) {
  const out = { ...row };
  const td = out.themeDesign;
  if (td && typeof td === "object") {
    out.themeDesign = {
      ...td,
      picksBase64: [],
      picksBase64Omitted: true,
    };
  }
  const sp = out.seatingPlan;
  if (sp && typeof sp === "object") {
    const shallow = { ...sp };
    if (
      typeof shallow.floorImageBase64 === "string" &&
      shallow.floorImageBase64.length > 8000
    ) {
      delete shallow.floorImageBase64;
      shallow.floorImageBase64Omitted = true;
    }
    out.seatingPlan = shallow;
  }
  out.listSummaryOnly = true;
  return out;
}

/** SQL fragment for theme column: strip picks in DB when compact (less I/O than full jsonb). */
function themeDesignListColumn(compact) {
  if (compact) {
    return `jsonb_set(
      COALESCE(theme_design::jsonb, '{}'::jsonb),
      '{picksBase64}',
      '[]'::jsonb,
      true
    ) AS "themeDesign"`;
  }
  return `theme_design AS "themeDesign"`;
}

async function fetchEventOrderRowById(orderId) {
  const id = String(orderId || "").trim();
  if (!id) return null;
  await ensureOrderCateringIdColumns();
  await ensureCateringEventOrdersCanonicalColumns();
  const cateringCols = await getTableColumnNames('catering_orders');
  const eventCols = await getTableColumnNames('event_orders');
  const { cateringSql, eventSql } = buildStaffEventOrderByIdQueries(
    cateringCols,
    eventCols,
  );
  const catering = await pool.query(cateringSql, [id]);
  if (catering.rows.length > 0) {
    return normalizeStaffEventOrderRow(catering.rows[0], { enrichMenu: true });
  }
  const ev = await pool.query(eventSql, [id]);
  if (ev.rows.length === 0) return null;
  return normalizeStaffEventOrderRow(ev.rows[0], { enrichMenu: true });
}

const SEATING_MAX_TABLES = 40;
const SEATING_MAX_SEATS = 1200;
const SEATING_MAX_FLOOR_B64_CHARS = 1_500_000;

/** Preset venue footprints (client “shape placer”); must match Flutter `kVenueFloorShapeOptions`. */
const SEATING_VENUE_FLOOR_SHAPES = new Set([
  "banquet_rect",
  "theater",
  "round_hall",
  "u_shape",
  "l_shape",
]);

function clamp01(n) {
  const x = Number(n);
  if (!Number.isFinite(x)) return 0.5;
  return Math.min(1, Math.max(0, x));
}

/**
 * Validates and normalizes seating_plan JSON for event_orders.
 * Shape: { version, floorImageUrl?, floorImageBase64?, venueFloorShape?, tables[], seats[], meta? }
 */
function normalizeSeatingPlan(raw) {
  const src = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {};
  const version = Math.max(1, Math.min(9999, Number(src.version) || 1));

  let floorImageUrl =
    src.floorImageUrl != null ? String(src.floorImageUrl).trim() : "";
  if (floorImageUrl.length > 2048) {
    return { ok: false, error: "floorImageUrl is too long" };
  }

  let floorImageBase64 =
    src.floorImageBase64 != null ? String(src.floorImageBase64).trim() : "";
  if (floorImageBase64.length > SEATING_MAX_FLOOR_B64_CHARS) {
    return { ok: false, error: "floorImageBase64 exceeds maximum size" };
  }

  let venueFloorShape = "";
  if (src.venueFloorShape != null) {
    const key = String(src.venueFloorShape).trim().toLowerCase();
    if (key.length > 0 && key.length <= 40 && SEATING_VENUE_FLOOR_SHAPES.has(key)) {
      venueFloorShape = key;
    }
  }
  if (floorImageUrl || floorImageBase64) {
    venueFloorShape = "";
  }

  const tablesIn = Array.isArray(src.tables) ? src.tables : [];
  const seatsIn = Array.isArray(src.seats) ? src.seats : [];
  if (tablesIn.length > SEATING_MAX_TABLES) {
    return { ok: false, error: `Too many tables (max ${SEATING_MAX_TABLES})` };
  }
  if (seatsIn.length > SEATING_MAX_SEATS) {
    return { ok: false, error: `Too many seats (max ${SEATING_MAX_SEATS})` };
  }

  const tables = [];
  const tableIds = new Set();
  for (let i = 0; i < tablesIn.length; i += 1) {
    const t = tablesIn[i];
    if (!t || typeof t !== "object") continue;
    let id = String(t.id || "").trim();
    if (!id) id = `tbl-${i}-${Math.random().toString(36).slice(2, 10)}`;
    if (tableIds.has(id)) {
      return { ok: false, error: `Duplicate table id: ${id}` };
    }
    tableIds.add(id);
    const shapeRaw = String(t.shape || "rect").toLowerCase();
    const shape = shapeRaw === "round" ? "round" : "rect";
    const seatCount = Math.max(
      0,
      Math.min(100, Math.floor(Number(t.seatCount) || 0)),
    );
    const label = String(t.label != null ? t.label : `Table ${i + 1}`).slice(
      0,
      80,
    );
    const rotationDeg = Number.isFinite(Number(t.rotationDeg))
      ? Number(t.rotationDeg) % 360
      : 0;
    tables.push({
      id,
      shape,
      xNorm: clamp01(t.xNorm),
      yNorm: clamp01(t.yNorm),
      wNorm: clamp01(t.wNorm || 0.15),
      hNorm: clamp01(t.hNorm || 0.12),
      rotationDeg,
      label,
      seatCount,
    });
  }

  const seats = [];
  for (let j = 0; j < seatsIn.length; j += 1) {
    const s = seatsIn[j];
    if (!s || typeof s !== "object") continue;
    const tableId = String(s.tableId || "").trim();
    const isStandalone = !tableId;
    if (!isStandalone && !tableIds.has(tableId)) {
      return { ok: false, error: `Seat references unknown table: ${tableId}` };
    }
    let sid = String(s.id || "").trim();
    if (!sid) sid = `seat-${j}-${Math.random().toString(36).slice(2, 10)}`;
    const index = Math.max(0, Math.floor(Number(s.index) || 0));
    const label =
      s.label != null ? String(s.label).slice(0, 80) : `Seat ${index + 1}`;
    const perimeterT = clamp01(s.perimeterT != null ? s.perimeterT : index / 100);
    const guestId =
      s.guestId != null && String(s.guestId).trim()
        ? String(s.guestId).trim().slice(0, 64)
        : null;
    if (isStandalone) {
      const xNorm = clamp01(s.xNorm != null ? s.xNorm : 0.5);
      const yNorm = clamp01(s.yNorm != null ? s.yNorm : 0.5);
      seats.push({
        id: sid,
        tableId: "",
        index,
        label,
        perimeterT: 0,
        xNorm,
        yNorm,
        standalone: true,
        ...(guestId ? { guestId } : {}),
      });
      continue;
    }
    seats.push({
      id: sid,
      tableId,
      index,
      label,
      perimeterT,
      ...(guestId ? { guestId } : {}),
    });
  }

  const meta =
    src.meta && typeof src.meta === "object" && !Array.isArray(src.meta)
      ? {
          guestCountHint:
            src.meta.guestCountHint != null
              ? Math.max(0, Math.floor(Number(src.meta.guestCountHint) || 0))
              : undefined,
          updatedAt:
            src.meta.updatedAt != null
              ? String(src.meta.updatedAt).slice(0, 40)
              : undefined,
        }
      : {};

  const plan = {
    version,
    ...(floorImageUrl ? { floorImageUrl } : {}),
    ...(floorImageBase64 ? { floorImageBase64 } : {}),
    ...(venueFloorShape ? { venueFloorShape } : {}),
    tables,
    seats,
    ...(Object.keys(meta).length ? { meta } : {}),
  };
  return { ok: true, plan };
}

function normalizeDetections(rawDetections) {
  if (!Array.isArray(rawDetections)) return [];
  return rawDetections
    .filter((d) => d && typeof d === "object")
    .map((d) => {
      const box = d.boundingBox && typeof d.boundingBox === "object" ? d.boundingBox : {};
      return {
        classId: String(d.classId || ""),
        className: String(d.className || d.classId || "Object"),
        confidence: Number(d.confidence || 0),
        boundingBox: {
          left: Number(box.left || 0),
          top: Number(box.top || 0),
          width: Number(box.width || 0.2),
          height: Number(box.height || 0.2),
        },
        currentColorHex: d.currentColorHex ? String(d.currentColorHex) : null,
      };
    })
    .filter((d) => d.classId);
}

function toHttpError(message, status = 500, code = "internal_error", details) {
  const err = new Error(message);
  err.status = status;
  err.code = code;
  err.details = details;
  return err;
}

function getRequestId(req) {
  const headerId = req.headers["x-request-id"];
  if (typeof headerId === "string" && headerId.trim()) return headerId.trim();
  return `req_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

function sanitizeBase64Image(input) {
  if (typeof input !== "string" || !input.trim()) {
    throw toHttpError("imageBase64 is required", 400, "invalid_image_payload");
  }
  const value = input.trim();
  const cleaned = value.includes(",") ? value.split(",").pop() : value;
  if (!cleaned || !/^[A-Za-z0-9+/=\s]+$/.test(cleaned)) {
    throw toHttpError("imageBase64 must be a valid base64 string", 400, "invalid_base64");
  }
  const sizeBytes = Buffer.byteLength(cleaned, "base64");
  if (sizeBytes <= 0 || sizeBytes > AI_SERVICE_MAX_IMAGE_BYTES) {
    throw toHttpError(
      `imageBase64 exceeds size limit (${AI_SERVICE_MAX_IMAGE_BYTES} bytes)`,
      400,
      "image_too_large",
      { maxBytes: AI_SERVICE_MAX_IMAGE_BYTES, receivedBytes: sizeBytes },
    );
  }
  return cleaned;
}

function ensureHexColor(rawValue, fallback = "#f4511e") {
  const value = String(rawValue || "").trim();
  const match = value.match(/^#?([0-9a-f]{6})$/i);
  if (!match) return String(fallback || "#f4511e").toLowerCase();
  return `#${match[1].toLowerCase()}`;
}

const baseFallbackThemeSuggestions = [
  {
    title: "Elegant Event Tablescape",
    source: "fallback",
    thumbnailUrl: "https://images.unsplash.com/photo-1519225421980-715cb0215aed",
    imageUrl: "https://images.unsplash.com/photo-1519225421980-715cb0215aed",
  },
  {
    title: "Floral Centerpiece Inspiration",
    source: "fallback",
    thumbnailUrl: "https://images.unsplash.com/photo-1478146059778-26028b07395a",
    imageUrl: "https://images.unsplash.com/photo-1478146059778-26028b07395a",
  },
  {
    title: "Modern Reception Setup",
    source: "fallback",
    thumbnailUrl: "https://images.unsplash.com/photo-1469371670807-013ccf25f16a",
    imageUrl: "https://images.unsplash.com/photo-1469371670807-013ccf25f16a",
  },
  {
    title: "Garden Party Decor",
    source: "fallback",
    thumbnailUrl: "https://images.unsplash.com/photo-1522673607200-164d1b6ce486",
    imageUrl: "https://images.unsplash.com/photo-1522673607200-164d1b6ce486",
  },
  {
    title: "Romantic Wedding Setup",
    source: "fallback",
    thumbnailUrl: "https://images.unsplash.com/photo-1511285560929-80b456fea0bc",
    imageUrl: "https://images.unsplash.com/photo-1511285560929-80b456fea0bc",
  },
];

const fallbackThemeSuggestionsByEventType = {
  wedding: [
    {
      title: "Wedding Ceremony Aisle",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1520854221256-17451cc331bf",
      imageUrl: "https://images.unsplash.com/photo-1520854221256-17451cc331bf",
    },
    {
      title: "Bride and Groom Stage Decor",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1465495976277-4387d4b0b2bb",
      imageUrl: "https://images.unsplash.com/photo-1465495976277-4387d4b0b2bb",
    },
  ],
  birthday: [
    {
      title: "Birthday Balloon Backdrop",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1530103862676-de8c9debad1d",
      imageUrl: "https://images.unsplash.com/photo-1530103862676-de8c9debad1d",
    },
    {
      title: "Birthday Dessert Table",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1464349153735-7db50ed83c84",
      imageUrl: "https://images.unsplash.com/photo-1464349153735-7db50ed83c84",
    },
  ],
  corporate: [
    {
      title: "Corporate Conference Hall",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1511578314322-379afb476865",
      imageUrl: "https://images.unsplash.com/photo-1511578314322-379afb476865",
    },
    {
      title: "Business Networking Setup",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1505373877841-8d25f7d46678",
      imageUrl: "https://images.unsplash.com/photo-1505373877841-8d25f7d46678",
    },
  ],
  "private party": [
    {
      title: "Private Party Lighting",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1492684223066-81342ee5ff30",
      imageUrl: "https://images.unsplash.com/photo-1492684223066-81342ee5ff30",
    },
    {
      title: "Lounge Party Decor",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1429962714451-bb934ecdc4ec",
      imageUrl: "https://images.unsplash.com/photo-1429962714451-bb934ecdc4ec",
    },
  ],
  sports: [
    {
      title: "Sports Banquet Setup",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1461896836934-ffe607ba8211",
      imageUrl: "https://images.unsplash.com/photo-1461896836934-ffe607ba8211",
    },
    {
      title: "Team Celebration Venue",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1517649763962-0c623066013b",
      imageUrl: "https://images.unsplash.com/photo-1517649763962-0c623066013b",
    },
  ],
  government: [
    {
      title: "Formal Government Reception",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1475721027785-f74eccf877e2",
      imageUrl: "https://images.unsplash.com/photo-1475721027785-f74eccf877e2",
    },
    {
      title: "Official Ceremony Hall",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1431540015161-0bf868a2d407",
      imageUrl: "https://images.unsplash.com/photo-1431540015161-0bf868a2d407",
    },
  ],
  show: [
    {
      title: "Stage Show Lighting",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1501386761578-eac5c94b800a",
      imageUrl: "https://images.unsplash.com/photo-1501386761578-eac5c94b800a",
    },
    {
      title: "Live Performance Stage",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3",
      imageUrl: "https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3",
    },
  ],
  educational: [
    {
      title: "Educational Seminar Setup",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1523580494863-6f3031224c94",
      imageUrl: "https://images.unsplash.com/photo-1523580494863-6f3031224c94",
    },
    {
      title: "Workshop Event Space",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1513258496099-48168024aec0",
      imageUrl: "https://images.unsplash.com/photo-1513258496099-48168024aec0",
    },
  ],
  reunion: [
    {
      title: "Family Reunion Tablescape",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1511988617509-a57c8a288659",
      imageUrl: "https://images.unsplash.com/photo-1511988617509-a57c8a288659",
    },
    {
      title: "Homecoming Reunion Setup",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1529156069898-49953e39b3ac",
      imageUrl: "https://images.unsplash.com/photo-1529156069898-49953e39b3ac",
    },
  ],
  gala: [
    {
      title: "Black Tie Gala Hall",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1519167758481-83f550bb49b3",
      imageUrl: "https://images.unsplash.com/photo-1519167758481-83f550bb49b3",
    },
    {
      title: "Luxury Gala Decor",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1472653816316-3ad6f10a6592",
      imageUrl: "https://images.unsplash.com/photo-1472653816316-3ad6f10a6592",
    },
  ],
  dinner: [
    {
      title: "Fine Dining Event Layout",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0",
      imageUrl: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0",
    },
    {
      title: "Candlelit Dinner Setup",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1544145945-f90425340c7e",
      imageUrl: "https://images.unsplash.com/photo-1544145945-f90425340c7e",
    },
  ],
  other: [
    {
      title: "Creative Themed Event Setup",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1499364615650-ec38552f4f34",
      imageUrl: "https://images.unsplash.com/photo-1499364615650-ec38552f4f34",
    },
    {
      title: "Custom Celebration Decor",
      source: "fallback",
      thumbnailUrl: "https://images.unsplash.com/photo-1519671482749-fd09be7ccebf",
      imageUrl: "https://images.unsplash.com/photo-1519671482749-fd09be7ccebf",
    },
  ],
};

function getFallbackThemeSuggestions(eventType) {
  const normalized = String(eventType || "")
    .trim()
    .toLowerCase()
    .replace(/[_-]+/g, " ")
    .replace(/\s+/g, " ");
  const aliasMap = new Map([
    ["birthday party", "birthday"],
    ["bday", "birthday"],
    ["corporate event", "corporate"],
    ["privateparty", "private party"],
    ["private-party", "private party"],
    ["sports event", "sports"],
    ["gov", "government"],
    ["government event", "government"],
    ["concert", "show"],
    ["performance", "show"],
    ["school event", "educational"],
    ["education", "educational"],
    ["family reunion", "reunion"],
    ["grand reunion", "reunion"],
    ["gala dinner", "gala"],
    ["formal dinner", "dinner"],
  ]);
  const key = aliasMap.get(normalized) || normalized;
  const specific = sanitizeThemeSuggestions(fallbackThemeSuggestionsByEventType[key] || []);
  const base = sanitizeThemeSuggestions(baseFallbackThemeSuggestions);
  return [...specific, ...base].slice(0, 12);
}

function buildThemeQuery({ eventTitle, eventType, formalityLevel, prompt }) {
  return [
    String(eventTitle || "").trim(),
    String(eventType || "").trim(),
    String(formalityLevel || "").trim(),
    String(prompt || "").trim(),
    "event design inspiration",
  ]
    .filter(Boolean)
    .join(" ");
}

function buildPexelsQuery({
  eventTitle,
  eventType,
  formalityLevel,
  prompt,
  baseImageUrl,
  forceNoPeople = true,
}) {
  const q = [
    String(eventType || "").trim(),
    String(formalityLevel || "").trim(),
    String(eventTitle || "").trim(),
    String(prompt || "").trim(),
    baseImageUrl ? "matching style composition" : "",
    "event decor background",
    forceNoPeople ? "-people -person -human -portrait -face -model -selfie" : "",
  ]
    .filter(Boolean)
    .join(" ")
    .replace(/\s+/g, " ")
    .trim();
  return q;
}

function buildPromptLedPexelsQueries({
  eventTitle,
  eventType,
  formalityLevel,
  prompt,
  baseImageUrl,
  tags = [],
}) {
  const cleanPrompt = String(prompt || "").trim();
  const cleanType = String(eventType || "").trim();
  const cleanFormality = String(formalityLevel || "").trim();
  const cleanTitle = String(eventTitle || "").trim();
  const cleanTags = Array.isArray(tags)
    ? tags.map((t) => String(t || "").trim().toLowerCase()).filter(Boolean)
    : [];
  const tagText = cleanTags.join(" ");
  const queries = [
    // Use the user's exact prompt first so results mirror direct Pexels search.
    `${cleanPrompt} ${tagText} -people -person -human -portrait -face -model -selfie`,
    `${cleanPrompt} ${tagText} event decor -people -person -human -portrait -face -model -selfie`,
    buildPexelsQuery({
      eventTitle: cleanTitle,
      eventType: cleanType,
      formalityLevel: cleanFormality,
      prompt: `${cleanPrompt} ${tagText}`.trim(),
      baseImageUrl,
      forceNoPeople: true,
    }),
  ]
    .map((q) => q.replace(/\s+/g, " ").trim())
    .filter(Boolean);
  return [...new Set(queries)];
}

function looksPeopleCentricPexelsRow(row) {
  const text = [
    row?.alt,
    row?.url,
    row?.photographer,
    row?.src?.original,
    row?.src?.large2x,
  ]
    .map((v) => String(v || "").toLowerCase())
    .join(" ");
  return /\b(person|people|human|portrait|selfie|face|man|woman|model|boy|girl)\b/.test(text);
}

function looksPeopleCentricSuggestion(row) {
  const text = [
    row?.title,
    row?.description,
    row?.imageUrl,
    row?.thumbnailUrl,
    row?.photographer,
    row?.pexelsUrl,
  ]
    .map((v) => String(v || "").toLowerCase())
    .join(" ");
  return /\b(person|people|human|portrait|selfie|face|man|woman|model|boy|girl|bride|groom|crowd|group)\b/.test(text);
}

function looksDecorCentricSuggestion(row) {
  const text = [
    row?.title,
    row?.description,
    row?.imageUrl,
    row?.thumbnailUrl,
    row?.pexelsUrl,
  ]
    .map((v) => String(v || "").toLowerCase())
    .join(" ");
  return /\b(decor|decoration|event|venue|hall|setup|tablescape|table|centerpiece|balloon|floral|flower|banquet|reception|aisle|stage|backdrop|dinner|wedding|birthday|celebration)\b/.test(
    text,
  );
}

function sanitizeThemeSuggestions(rows) {
  if (!Array.isArray(rows)) return [];
  return rows
    .filter((row) => row && typeof row === "object")
    .filter((row) => !looksPeopleCentricSuggestion(row))
    .filter((row) => looksDecorCentricSuggestion(row));
}

function hasPersonLikeObject(objects) {
  const personExp = /\b(person|people|human|man|woman|boy|girl|face)\b/i;
  for (const obj of Array.isArray(objects) ? objects : []) {
    const label = String(obj?.label || obj?.name || "").trim();
    if (personExp.test(label)) return true;
  }
  return false;
}

async function removePersonImagesViaAi(req, rows, { maxChecks = 14 } = {}) {
  const candidates = rows.filter((row) => String(row?.imageUrl || "").trim());
  const checked = candidates.slice(0, Math.max(0, maxChecks));
  const unchecked = candidates.slice(checked.length);

  const checkedResults = await Promise.all(
    checked.map(async (row) => {
      const url = String(row?.imageUrl || "").trim();
      try {
        const r = await fetch(url, { method: "GET" });
        if (!r.ok) return row;
        const buf = Buffer.from(await r.arrayBuffer());
        const imageBase64 = buf.toString("base64");
        const detected = await callFastApiWithTimeoutRetry({
          req,
          routePath: "/v1/infer/yolo-sam",
          timeoutMs: 6000,
          timeoutRetries: 0,
          payload: {
            image_base64: imageBase64,
            confidence_threshold: 0.35,
            max_detections: 12,
            mask_format: "polygon",
          },
        });
        const objects = Array.isArray(detected?.objects) ? detected.objects : [];
        return hasPersonLikeObject(objects) ? null : row;
      } catch (_) {
        // Fail-open to avoid breaking search when AI service is slow.
        return row;
      }
    }),
  );

  return [...checkedResults.filter(Boolean), ...unchecked];
}

async function fetchPexelsImages({
  query,
  perPage = 20,
  page = 1,
}) {
  const pexelsKey = String(process.env.PEXELS_API_KEY || "").trim();
  if (!pexelsKey) {
    return { images: [], error: "PEXELS_API_KEY is not configured", rateLimited: false };
  }
  if (!query.trim()) {
    return { images: [], error: "search query is empty", rateLimited: false };
  }
  const url = new URL("https://api.pexels.com/v1/search");
  url.searchParams.set("query", query);
  url.searchParams.set("per_page", String(Math.max(1, Math.min(perPage, 30))));
  url.searchParams.set("page", String(Math.max(1, page)));
  url.searchParams.set("orientation", "landscape");
  const maxAttempts = Number(process.env.PEXELS_MAX_ATTEMPTS || 3);
  let lastError = "";
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      const upstream = await fetch(url, {
        method: "GET",
        headers: { Authorization: pexelsKey },
      });
      if (upstream.status === 429) {
        const retryAfterRaw = upstream.headers.get("retry-after");
        const retryAfterSec = Number(retryAfterRaw);
        const jitterMs = Math.floor(Math.random() * 500);
        const delayMs = Number.isFinite(retryAfterSec)
          ? Math.max(500, retryAfterSec * 1000)
          : 500 * attempt + jitterMs;
        lastError = "Pexels rate limit reached";
        if (attempt < maxAttempts) {
          await new Promise((r) => setTimeout(r, delayMs));
          continue;
        }
        return {
          images: [],
          error: "Pexels rate limit reached. Please wait and try again.",
          rateLimited: true,
        };
      }
    if (!upstream.ok) {
      const t = await upstream.text().catch(() => "");
      return {
        images: [],
        error: `Pexels request failed (${upstream.status})${t ? `: ${t.slice(0, 200)}` : ""}`,
        rateLimited: false,
      };
    }
    const json = await upstream.json();
    const rows = Array.isArray(json?.photos) ? json.photos : [];
    const images = rows
      .filter((row) => row && typeof row === "object")
      .filter((row) => !looksPeopleCentricPexelsRow(row))
      .map((row) => ({
        title: String(row.alt || "Pexels theme suggestion"),
        source: "pexels",
        thumbnailUrl: String(row?.src?.medium || row?.src?.small || ""),
        imageUrl: String(row?.src?.large2x || row?.src?.large || row?.src?.original || ""),
        photographer: String(row.photographer || ""),
        photographerUrl: String(row.photographer_url || ""),
        pexelsUrl: String(row.url || ""),
      }))
      .filter((row) => row.imageUrl)
      .slice(0, 30);
    return { images, error: "", rateLimited: false };
    } catch (e) {
      lastError = String(e?.message || "network_error");
      if (attempt < maxAttempts) {
        const jitterMs = Math.floor(Math.random() * 500);
        await new Promise((r) => setTimeout(r, 350 * attempt + jitterMs));
        continue;
      }
      return {
        images: [],
        error: `Pexels request failed: ${lastError}`,
        rateLimited: false,
      };
    }
  }
  return {
    images: [],
    error: lastError || "Pexels request failed",
    rateLimited: false,
  };
}

function normalizePolygonPoints(raw) {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((point) => {
      if (point && typeof point === "object") {
        const x = Number(point.x);
        const y = Number(point.y);
        if (Number.isFinite(x) && Number.isFinite(y)) return { x, y };
      }
      if (Array.isArray(point) && point.length >= 2) {
        const x = Number(point[0]);
        const y = Number(point[1]);
        if (Number.isFinite(x) && Number.isFinite(y)) return { x, y };
      }
      return null;
    })
    .filter(Boolean);
}

async function callFastApi({ req, routePath, timeoutMs, payload }) {
  if (!FASTAPI_URL) {
    throw toHttpError(
      "AI service is not configured",
      500,
      "ai_service_not_configured",
    );
  }
  if (!AI_SERVICE_TOKEN) {
    throw toHttpError(
      "AI service token is not configured",
      500,
      "ai_service_auth_not_configured",
    );
  }

  const requestId = getRequestId(req);
  const controller = new AbortController();
  const timeoutHandle = setTimeout(() => controller.abort(), timeoutMs);
  const startedAt = Date.now();
  try {
    const response = await fetch(`${FASTAPI_URL}${routePath}`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${AI_SERVICE_TOKEN}`,
        "x-request-id": requestId,
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });

    const text = await response.text();
    const contentType = String(response.headers.get("content-type") || "").toLowerCase();
    const shouldParseJson = contentType.includes("application/json");
    let decoded = {};
    let parsedJson = false;
    if (text) {
      if (shouldParseJson || text.trim().startsWith("{") || text.trim().startsWith("[")) {
        try {
          decoded = JSON.parse(text);
          parsedJson = true;
        } catch {
          if (response.ok) {
            throw toHttpError(
              "AI service returned invalid JSON",
              502,
              "upstream_bad_response",
              {
                routePath,
                upstreamStatus: response.status,
                contentType,
                snippet: text.slice(0, 300),
              },
            );
          }
        }
      }
    }

    if (!response.ok) {
      let message = "AI processing failed";
      if (parsedJson && decoded && typeof decoded.message === "string" && decoded.message) {
        message = decoded.message;
      } else if (parsedJson && decoded && decoded.detail) {
        const detailText =
          typeof decoded.detail === "string"
            ? decoded.detail
            : JSON.stringify(decoded.detail);
        if (detailText && detailText.trim()) {
          message = detailText.slice(0, 280);
        }
      } else if (text && !parsedJson) {
        const clean = text.replace(/\s+/g, " ").trim();
        if (clean) message = clean.slice(0, 220);
      }
      throw toHttpError(
        message,
        response.status >= 400 && response.status < 600 ? response.status : 502,
        "upstream_failure",
        {
          upstreamStatus: response.status,
          routePath,
          contentType,
          parsedJson,
        },
      );
    }

    return decoded;
  } catch (error) {
    if (error?.name === "AbortError") {
      throw toHttpError("AI service timeout", 504, "upstream_timeout", { routePath });
    }
    if (error && typeof error.status === "number") throw error;
    throw toHttpError("AI processing failed", 502, "upstream_failure", {
      routePath,
      message: error?.message,
    });
  } finally {
    clearTimeout(timeoutHandle);
    const elapsedMs = Date.now() - startedAt;
    console.log(
      JSON.stringify({
        level: "info",
        feature: "events-theme-ai",
        routePath,
        elapsedMs,
        requestId,
      }),
    );
  }
}

async function callFastApiWithTimeoutRetry({
  req,
  routePath,
  timeoutMs,
  payload,
  timeoutRetries = 0,
}) {
  let attempt = 0;
  while (true) {
    try {
      return await callFastApi({ req, routePath, timeoutMs, payload });
    } catch (error) {
      const timedOut = error?.code === "upstream_timeout" || error?.status === 504;
      if (!timedOut || attempt >= timeoutRetries) throw error;
      attempt += 1;
      console.warn(
        `[events-theme-ai] timeout retry ${attempt}/${timeoutRetries} for ${routePath}`,
      );
    }
  }
}

function sendHttpError(res, error, fallbackMessage) {
  const status = Number(error?.status || 500);
  const code = error?.code || "internal_error";
  const message = error?.message || fallbackMessage || "Request failed";
  const details = error?.details && typeof error.details === "object" ? error.details : undefined;
  return res.status(status).json(details ? { message, code, details } : { message, code });
}

function signToken({ userId, role }) {
  return jwt.sign({ role }, JWT_SECRET, {
    subject: userId,
    expiresIn: process.env.STAFF_JWT_MAX_AGE || "12h",
  });
}
// OTP generation
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function assertResendEmailConfigured() {
  if (!isEmailConfigured()) {
    throw new Error("Email not configured: set RESEND_API_KEY and RESEND_FROM");
  }
}

async function sendOtpEmail(email, otp) {
  assertResendEmailConfigured();
  await sendEmail({
    to: email,
    subject: "Verify your Curatering account.",
    text:
      `Welcome to Curatering!\n\n` +
      `If you did not request this email, please ignore this message.\n\n` +
      `Your OTP is ${otp}.\n` +
      `This OTP will expire in 10 minutes.`,
  });
}

async function sendPasswordResetEmail(email, resetCode, fullName) {
  assertResendEmailConfigured();
  await sendEmail({
    to: email,
    subject: "Password Reset - Curatering",
    text:
      `Hello ${fullName || "Customer"},\n\n` +
      `You requested to reset your password for your Curatering account.\n\n` +
      `Your password reset code is: ${resetCode}\n\n` +
      `This code will expire in 30 minutes.\n\n` +
      `If you did not request this password reset, please ignore this email.\n\n` +
      `Best regards,\nCuratering Team`,
  });
}

async function sendPasswordChangedEmail(email, fullName) {
  assertResendEmailConfigured();
  await sendEmail({
    to: email,
    subject: "Your Password Has Been Changed - Curatering",
    text:
      `Hello ${fullName || "Customer"},\n\n` +
      `Your password for your Curatering account has been successfully changed.\n\n` +
      `If you did not make this change, please contact us immediately.\n\n` +
      `Best regards,\nCuratering Team`,
  });
}

async function sendCustomerNotificationEmail({ to, subject, text, html, attachments }) {
  if (!to) return;
  if (!isEmailConfigured()) {
    console.warn(
      "[email] Skipping notification — set RESEND_API_KEY and RESEND_FROM on this host",
    );
    return;
  }
  try {
    await sendEmail({ to, subject, text, html, attachments });
  } catch (error) {
    console.error(
      "Failed to send customer notification email:",
      error?.message || error,
    );
  }
}

/** Fire-and-forget — never block API responses on SMTP. */
function sendCustomerNotificationEmailAsync(payload) {
  void sendCustomerNotificationEmail(payload);
}

function customerWebOrigin() {
  return (
    process.env.PUBLIC_WEB_URL ||
    process.env.FRONTEND_URL ||
    process.env.WEB_ORIGIN ||
    'https://macrinas-kitchen.curatering.com'
  ).replace(/\/+$/, '');
}

function restaurantFeedbackLink(order) {
  const token = jwt.sign(
    {
      type: 'restaurant_feedback',
      orderId: String(order.order_id ?? ''),
      email: String(order.user_email ?? ''),
    },
    JWT_SECRET,
    { expiresIn: '30d' },
  );
  return `${customerWebOrigin()}/restaurant-feedback?token=${encodeURIComponent(token)}`;
}

function sendOtpEmailAsync(email, otp) {
  void sendOtpEmail(email, otp).catch((err) => {
    console.error("Failed to send OTP email:", err?.message || err);
  });
}

/**
 * Customer auth routes registered before full initDb so login works as soon as the process listens.
 * @param {import("express").Express} app
 * @param {import("express").RequestHandler} [dbGate]
 */
/** Customer phone from DB row (Supabase uses contact_number). */
function customerPhoneFromRow(row) {
  if (!row) return null;
  return row.contact_number ?? row.phone ?? null;
}

function registerCustomerAuthRoutes(app, dbGate) {
  const gate = dbGate || ((_req, _res, next) => next());

  app.post("/api/customer/signup", gate, async (req, res) => {
    try {
      const { email, password, fullName, phone, platform } = req.body || {};
      const registrationPlatform =
        String(platform || 'web').toLowerCase() === 'mobile' ? 'mobile' : 'web';

      if (!email || !password || !fullName) {
        return res.status(400).json({ error: "Email, password, and full name are required" });
      }

      const emailNorm = String(email).trim().toLowerCase();

      const existingCustomer = await pool.query(
        `SELECT id, is_verified, archived FROM customer_accounts WHERE lower(trim(email::text)) = $1`,
        [emailNorm],
      );

      const passwordHash = await bcrypt.hash(password, 10);
      const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
      const otpExpiry = new Date(Date.now() + 10 * 60 * 1000);

      if (existingCustomer.rows.length > 0) {
        const row = existingCustomer.rows[0];
        if (!row.archived && row.is_verified) {
          return res.status(400).json({ error: "Email already registered" });
        }

        await pool.query(
          `UPDATE customer_accounts
           SET email = $1,
               password_hash = $2,
               full_name = $3,
               contact_number = $4,
               otp_code = $5,
               otp_expiry = $6,
               archived = FALSE,
               is_verified = FALSE,
               updated_at = now()
           WHERE id = $7`,
          [emailNorm, passwordHash, fullName, phone || null, otpCode, otpExpiry, row.id],
        );

        sendOtpEmailAsync(emailNorm, otpCode);

        return res.status(201).json({
          customer: {
            id: row.id,
            email: emailNorm,
            full_name: fullName,
            is_verified: false,
          },
          message: "Check your email for a new verification code.",
        });
      }

      await ensureCustomerAccountsUuidCompat();
      const idType = await getColumnSqlType('customer_accounts', 'id');
      const caCols = await getTableColumnNames('customer_accounts');
      const useUuidPk = idType === 'UUID';
      const customerCode = useUuidPk
        ? await generateSequentialId('CUS', 4)
        : null;
      const customerId = useUuidPk ? crypto.randomUUID() : customerCode;

      let result;
      if (useUuidPk && caCols.has('customer_code')) {
        result = await pool.query(
          `INSERT INTO customer_accounts (id, customer_code, email, password_hash, full_name, contact_number, otp_code, otp_expiry, registration_platform)
           VALUES ($1::uuid, $2, $3, $4, $5, $6, $7, $8, $9)
           RETURNING id, email, full_name, is_verified`,
          [
            customerId,
            customerCode,
            emailNorm,
            passwordHash,
            fullName,
            phone || null,
            otpCode,
            otpExpiry,
            registrationPlatform,
          ],
        );
      } else if (useUuidPk) {
        result = await pool.query(
          `INSERT INTO customer_accounts (id, email, password_hash, full_name, contact_number, otp_code, otp_expiry, registration_platform)
           VALUES ($1::uuid, $2, $3, $4, $5, $6, $7, $8)
           RETURNING id, email, full_name, is_verified`,
          [
            customerId,
            emailNorm,
            passwordHash,
            fullName,
            phone || null,
            otpCode,
            otpExpiry,
            registrationPlatform,
          ],
        );
      } else {
        result = await pool.query(
          `INSERT INTO customer_accounts (id, email, password_hash, full_name, contact_number, otp_code, otp_expiry, registration_platform)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
           RETURNING id, email, full_name, is_verified`,
          [
            customerId,
            emailNorm,
            passwordHash,
            fullName,
            phone || null,
            otpCode,
            otpExpiry,
            registrationPlatform,
          ],
        );
      }

      sendOtpEmailAsync(emailNorm, otpCode);

      res.status(201).json({
        customer: result.rows[0],
        message: "Account created. Please verify your email with the OTP sent.",
      });
    } catch (error) {
      console.error("Error signing up customer:", error);
      res.status(500).json({ error: "Failed to create account" });
    }
  });

  app.post("/api/customer/verify-otp", gate, async (req, res) => {
    try {
      const { email, otpCode } = req.body || {};

      if (!email || !otpCode) {
        return res.status(400).json({ error: "Email and OTP code are required" });
      }

      const emailNorm = String(email).trim().toLowerCase();

      const result = await pool.query(
        `SELECT id, otp_expiry FROM customer_accounts
         WHERE lower(trim(email::text)) = $1 AND otp_code = $2 AND is_verified = FALSE`,
        [emailNorm, otpCode],
      );

      if (result.rows.length === 0) {
        return res.status(400).json({ error: "Invalid OTP or email" });
      }

      if (new Date() > result.rows[0].otp_expiry) {
        return res.status(400).json({ error: "OTP has expired" });
      }

      await pool.query(
        `UPDATE customer_accounts
         SET is_verified = TRUE, otp_code = NULL, otp_expiry = NULL
         WHERE id = $1`,
        [result.rows[0].id],
      );

      res.json({ message: "Email verified successfully" });
    } catch (error) {
      console.error("Error verifying OTP:", error);
      res.status(500).json({ error: "Failed to verify OTP" });
    }
  });

  app.post("/api/customer/login", gate, async (req, res) => {
    try {
      const { email, password } = req.body || {};

      if (!email || !password) {
        return res.status(400).json({ error: "Email and password are required" });
      }

      const emailNorm = String(email).trim().toLowerCase();

      const result = await pool.query(
        `SELECT id, email, password_hash, full_name, contact_number, is_verified,
                COALESCE(archived, FALSE) AS archived
         FROM customer_accounts
         WHERE lower(trim(email::text)) = $1
         LIMIT 1`,
        [emailNorm],
      );

      if (result.rows.length === 0) {
        return res.status(401).json({ error: "Invalid email or password" });
      }

      const customer = result.rows[0];
      if (customer.archived) {
        return res.status(401).json({
          error: "This account has been archived. Contact support if you need access restored.",
        });
      }

      const isValidPassword = await bcrypt.compare(password, customer.password_hash);

      if (!isValidPassword) {
        return res.status(401).json({ error: "Invalid email or password" });
      }

      if (!customer.is_verified) {
        const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
        const otpExpiry = new Date(Date.now() + 10 * 60 * 1000);

        await pool.query(
          `UPDATE customer_accounts SET otp_code = $1, otp_expiry = $2 WHERE id = $3`,
          [otpCode, otpExpiry, customer.id],
        );

        sendOtpEmailAsync(emailNorm, otpCode);

        return res.status(403).json({
          error: "Email not verified",
          requiresVerification: true,
          message: "Please verify your email with the OTP sent.",
        });
      }

      const token = jwt.sign(
        { customerId: customer.id, role: "customer" },
        JWT_SECRET,
        { expiresIn: "7d" },
      );

      if (process.env.SEND_LOGIN_NOTIFICATION_EMAIL !== "0") {
        sendCustomerNotificationEmailAsync({
          to: customer.email,
          subject: "Curatering: Login detected",
          text:
            `Hello ${customer.full_name || "Customer"},\n\n` +
            `Your account was just used to log in.\n` +
            `If this wasn't you, please reset your password immediately.\n\n` +
            `- Curatering Team`,
        });
      }

      res.json({
        token,
        customer: {
          id: customer.id,
          email: customer.email,
          fullName: customer.full_name,
          phone: customerPhoneFromRow(customer),
        },
      });
    } catch (error) {
      console.error("Error logging in customer:", error);
      res.status(500).json({ error: "Failed to login" });
    }
  });

  app.post("/api/customer/forgot-password", gate, async (req, res) => {
    try {
      const { email } = req.body || {};

      if (!email) {
        return res.status(400).json({ error: "Email is required" });
      }

      const emailNorm = String(email).trim().toLowerCase();
      const customerResult = await pool.query(
        `SELECT id, email, full_name FROM customer_accounts
         WHERE lower(trim(email::text)) = $1`,
        [emailNorm],
      );

      if (customerResult.rows.length === 0) {
        return res.json({ message: "If an account exists, a reset code will be sent" });
      }

      const customer = customerResult.rows[0];
      const resetCode = Math.floor(100000 + Math.random() * 900000).toString();

      await pool.query(
        `UPDATE customer_accounts
         SET reset_code = $1, reset_code_expires = NOW() + INTERVAL '30 minutes'
         WHERE id = $2`,
        [resetCode, customer.id],
      );

      void sendPasswordResetEmail(customer.email, resetCode, customer.full_name).catch(
        (emailError) => {
          console.error("Failed to send password reset email:", emailError);
        },
      );

      res.json({ message: "Reset code sent to your email" });
    } catch (error) {
      console.error("Error in forgot password:", error);
      res.status(500).json({ error: "Failed to process request" });
    }
  });

  app.post("/api/customer/reset-password", gate, async (req, res) => {
    try {
      const { email, resetCode, newPassword } = req.body || {};

      if (!email || !resetCode || !newPassword) {
        return res.status(400).json({ error: "Email, reset code, and new password are required" });
      }

      if (newPassword.length < 6) {
        return res.status(400).json({ error: "Password must be at least 6 characters" });
      }

      const emailNorm = String(email).trim().toLowerCase();
      const customerResult = await pool.query(
        `SELECT id, email, full_name FROM customer_accounts
         WHERE lower(trim(email::text)) = $1
           AND reset_code = $2
           AND reset_code_expires > NOW()`,
        [emailNorm, resetCode],
      );

      if (customerResult.rows.length === 0) {
        return res.status(400).json({ error: "Invalid or expired reset code" });
      }

      const customer = customerResult.rows[0];
      const hashedPassword = await bcrypt.hash(newPassword, 10);

      await pool.query(
        `UPDATE customer_accounts
         SET password_hash = $1, reset_code = NULL, reset_code_expires = NULL
         WHERE id = $2`,
        [hashedPassword, customer.id],
      );

      void sendPasswordChangedEmail(customer.email, customer.full_name).catch(
        (emailError) => {
          console.error("Failed to send password changed email:", emailError);
        },
      );

      res.json({ message: "Password reset successful" });
    } catch (error) {
      console.error("Error resetting password:", error);
      res.status(500).json({ error: "Failed to reset password" });
    }
  });
}

function authRequired(req, res, next) {
  const header = req.headers.authorization || "";
  const [scheme, token] = header.split(" ");
  if (scheme !== "Bearer" || !token) {
    return res.status(401).json({ message: "Missing bearer token" });
  }

  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = {
      id: payload.sub,
      role: payload.role,
    };
    return next();
  } catch (e) {
    return res.status(401).json({ message: "Invalid token" });
  }
}

function requireSuperAdmin(req, res, next) {
  if (req.user?.role !== "super_admin") {
    return res.status(403).json({ message: "Super Admin only" });
  }
  return next();
}

async function verifySuperAdminPassword(req) {
  const rawPassword = req.body?.superAdminPassword;
  const password =
    typeof rawPassword === "string" ? rawPassword : String(rawPassword || "");
  if (!password) return false;
  const result = await pool.query(
    `SELECT password_hash, role, archived
     FROM users
     WHERE id = $1
     LIMIT 1`,
    [req.user?.id],
  );
  if (result.rowCount === 0) return false;
  const row = result.rows[0];
  if (row.role !== "super_admin" || row.archived === true) return false;
  return bcrypt.compare(password, row.password_hash);
}

async function requireSuperAdminPassword(req, res) {
  const ok = await verifySuperAdminPassword(req);
  if (!ok) {
    res.status(403).json({ message: "Password confirmation failed" });
    return false;
  }
  return true;
}

let superAdminTodosSchemaPromise = null;
async function ensureSuperAdminTodosSchema() {
  if (!superAdminTodosSchemaPromise) {
    superAdminTodosSchemaPromise = pool
      .query(
        `CREATE TABLE IF NOT EXISTS super_admin_todos (
           id TEXT PRIMARY KEY,
           user_id TEXT NOT NULL,
           title TEXT NOT NULL,
           notes TEXT NOT NULL DEFAULT '',
           completed BOOLEAN NOT NULL DEFAULT FALSE,
           sort_order INTEGER NOT NULL DEFAULT 0,
           created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
           updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
         )`,
      )
      .then(() =>
        pool.query(
          `CREATE INDEX IF NOT EXISTS idx_super_admin_todos_user
           ON super_admin_todos (user_id, completed, sort_order, created_at DESC)`,
        ),
      )
      .catch((err) => {
        superAdminTodosSchemaPromise = null;
        throw err;
      });
  }
  return superAdminTodosSchemaPromise;
}

function serializeSuperAdminTodo(row) {
  return {
    id: String(row.id),
    title: row.title || "",
    notes: row.notes || "",
    completed: row.completed === true,
    sortOrder: Number(row.sort_order) || 0,
    createdAt: row.created_at ? row.created_at.toISOString() : null,
    updatedAt: row.updated_at ? row.updated_at.toISOString() : null,
  };
}

function requireRoles(req, res, next, allowed) {
  const role = req.user?.role;
  if (role === "super_admin") return next();
  if (!allowed.has(role)) {
    return res.status(403).json({ message: "Not allowed" });
  }
  return next();
}

/** Manager/supervisor/admin JWT guard for restaurant POS and loyalty config routes. */
function managerAuthRequired(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');

  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const adminRoles = ['admin', 'manager', 'supervisor', 'super_admin', 'cashier'];
    if (!adminRoles.includes(decoded.role)) {
      return res.status(403).json({ error: 'Manager access required' });
    }
    req.manager = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

async function logAction({
  client,
  userId,
  feature = "",
  action,
  other = null,
}) {
  const q = client ?? pool;
  await q.query(
    `INSERT INTO action_logs (user_id, feature, action, other)
     VALUES ($1, $2, $3, $4);`,
    [userId, feature, action, other],
  );
}

app.post("/api/auth/login", async (req, res) => {
  try {
    const { email, password } = req.body || {};

    if (!email || !password) {
      return res
        .status(400)
        .json({ message: "email and password are required" });
    }

    const emailNorm = String(email).trim().toLowerCase();
    const result = await pool.query(
      `SELECT id, email, full_name, role, archived, password_hash, page_permissions, is_verified
       FROM users
       WHERE lower(trim(email::text)) = $1
       LIMIT 1;`,
      [emailNorm],
    );

    if (result.rowCount === 0) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const user = result.rows[0];

    if (user.archived) {
      return res.status(401).json({ message: "Account archived" });
    }

    const ok = await bcrypt.compare(password, user.password_hash);

    if (!ok) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const token = signToken({ userId: user.id, role: user.role });

    return res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        fullName: user.full_name,
        role: user.role,
        archived: user.archived,
        isVerified: user.is_verified,
        pagePermissions: user.page_permissions || {},
      },
    });
  } catch (e) {
    console.error("Login error:", e);
    return res.status(500).json({ message: "Login failed" });
  }
});

app.get("/api/auth/me", authRequired, async (req, res) => {
  const { id } = req.user;
  const result = await pool.query(
    `SELECT id, email, full_name, role, archived, page_permissions
     FROM users
     WHERE id = $1
     LIMIT 1;`,
    [id],
  );

  if (result.rowCount === 0)
    return res.status(404).json({ message: "User not found" });
  const u = result.rows[0];
  return res.json({
    user: {
      id: u.id,
      email: u.email,
      fullName: u.full_name,
      role: u.role,
      archived: u.archived,
      pagePermissions: u.page_permissions || {},
    },
  });
});

// Public help request (for contact us form - no auth required)
app.post("/api/public/help-requests", async (req, res) => {
  try {
    const { name, email, message } = req.body || {};
    if (!name || !email || !message) {
      return res
        .status(400)
        .json({ message: "name, email, and message are required" });
    }

    const result = await pool.query(
      `INSERT INTO help_requests (user_id, feature, problem, request, status)
       VALUES (NULL, $1, $2, $3, 'unresolved')
       RETURNING id;`,
      ["Contact Us", `${name} (${email})`, message],
    );

    return res.json({ ok: true, id: result.rows[0].id });
  } catch (e) {
    console.error("Error completing post-event analysis:", e);
    return res.status(500).json({ error: "Failed to complete post-event analysis" });
  }
});

// Complete catering order and calculate loyalty points
app.post(
  "/api/catering/orders/:orderId/complete",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "supervisor", "admin"])),
  async (req, res) => {
    try {
      const { orderId } = req.params;

      const result = await pool.query(
        `UPDATE catering_orders
         SET
           status = 'completed',
           updated_by = $1,
           updated_at = now()
         WHERE id = $2
           AND status IN ('on_going', 'for_full_payment', 'for_processing', 'for_post_analysis')
         RETURNING *;`,
        [req.user.id, orderId],
      );

      if (result.rowCount === 0) {
        return res
          .status(404)
          .json({
            message: "Catering order not found or already completed",
          });
      }

      const order = result.rows[0];
      const customerId = order.customer_id;
      
      // Auto-calculate loyalty points when order is completed
      if (customerId) {
        const totalAmount = parseFloat(order.total_cost || 0);
        
        // Default catering loyalty points: 500 min order to earn 8 points (2% rate)
        const minimumCost = 500.0;
        const pointsApplication = 8; // 2% of total cost
        
        if (totalAmount >= minimumCost) {
          // Calculate points with rounding rule: .2-.6 down, .7-.9 up
          const rawPoints = (totalAmount * pointsApplication) / 100;
          const decimal = rawPoints % 1;
          let points = Math.floor(rawPoints);
          
          if (decimal >= 0.7) {
            points += 1;
          }
          
          // Update order with calculated points
          await pool.query(
            `UPDATE catering_orders SET points_earned = $1 WHERE id = $2`,
            [points, orderId]
          );
          
          // Update customer's total loyalty points
          await pool.query(
            `UPDATE customer_accounts 
             SET catering_loyalty_points = catering_loyalty_points + $1,
                 updated_at = now()
             WHERE id = $2`,
            [points, customerId]
          );
        }
      }

      await logAction({
        userId: req.user.id,
        feature: "Catering",
        action: "completed catering order",
        other: { orderId },
      });

      return res.json({ ok: true, id: result.rows[0].id });
    } catch (e) {
      console.error("Error completing catering order:", e);
      return res.status(500).json({ error: "Failed to complete catering order" });
    }
  },
);

//Help request (authenticated)
app.post("/api/help-requests", authRequired, async (req, res) => {
  try {
    const { feature, problem, request } = req.body || {};
    if (!feature || !problem || !request) {
      return res
        .status(400)
        .json({ message: "feature, problem, request are required" });
    }

    const result = await pool.query(
      `INSERT INTO help_requests (user_id, feature, problem, request, status)
       VALUES ($1, $2, $3, $4, 'unresolved')
       RETURNING id;`,
      [req.user.id, feature, problem, request],
    );

    await logAction({
      userId: req.user.id,
      feature,
      action: "sent help request",
      other: { helpRequestId: result.rows[0].id },
    });

    return res.json({ ok: true, id: result.rows[0].id });
  } catch (e) {
    return res.status(500).json({ message: "Failed to send help request" });
  }
});

// Super Admin: Dashboard
app.get(
  "/api/super-admin/dashboard/summary",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
    try {
      const now = new Date();
      const rangeKey = String(req.query?.range || "30d").trim().toLowerCase();
      const rangeDays = {
        "7d": 7,
        "30d": 30,
        "90d": 90,
      }[rangeKey];
      const rangeStart =
        rangeKey === "today"
          ? new Date(now.getFullYear(), now.getMonth(), now.getDate())
          : rangeKey === "year"
            ? new Date(now.getFullYear(), 0, 1)
            : rangeKey === "all"
              ? new Date(0)
              : new Date(now.getTime() - (rangeDays || 30) * 24 * 60 * 60 * 1000);
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
      const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);
      const yearStart = new Date(now.getFullYear(), 0, 1);

      const userStats = await pool.query(
        `SELECT
           COUNT(*)::int AS total,
           COUNT(*) FILTER (WHERE archived = FALSE)::int AS active,
           COUNT(*) FILTER (WHERE archived = TRUE)::int AS archived,
           COUNT(*) FILTER (WHERE role = 'super_admin')::int AS super_admin,
           COUNT(*) FILTER (WHERE role = 'admin')::int AS admin,
           COUNT(*) FILTER (WHERE role = 'manager')::int AS manager,
           COUNT(*) FILTER (WHERE role = 'supervisor')::int AS supervisor,
           COUNT(*) FILTER (WHERE role = 'cashier')::int AS cashier
         FROM users`,
      );

      const customerCols = await getTableColumnNames("customer_accounts");
      const customerArchivedExpr = customerCols.has("archived") ? "archived" : "FALSE";
      const customerCreatedExpr = customerCols.has("created_at") ? "created_at" : "now()";
      const customerStats = await pool.query(
        `SELECT
           COUNT(*)::int AS total,
           COUNT(*) FILTER (WHERE COALESCE(${customerArchivedExpr}, FALSE) = FALSE)::int AS active,
           COUNT(*) FILTER (WHERE COALESCE(${customerArchivedExpr}, FALSE) = TRUE)::int AS archived,
           COUNT(*) FILTER (WHERE ${customerCreatedExpr} >= $1 AND ${customerCreatedExpr} < $2)::int AS new_this_month
         FROM customer_accounts`,
        [monthStart, nextMonth],
      );

      const helpStats = await pool.query(
        `SELECT
           COUNT(*)::int AS total,
           COUNT(*) FILTER (WHERE status = 'unresolved')::int AS unresolved,
           COUNT(*) FILTER (WHERE status = 'resolved')::int AS resolved,
           COUNT(*) FILTER (WHERE created_at >= $1)::int AS last30
         FROM help_requests`,
        [rangeStart],
      );

      const recentHelp = await pool.query(
        `SELECT hr.id, COALESCE(u.full_name, 'Public user') AS "userName",
                hr.feature, hr.problem, hr.status, hr.created_at AS "createdAt"
         FROM help_requests hr
         LEFT JOIN users u ON u.id = hr.user_id
         ORDER BY hr.created_at DESC
         LIMIT 6`,
      );

      const recentActions = await pool.query(
        `SELECT al.id, COALESCE(u.full_name, 'System') AS "userName",
                al.feature, al.action, al.created_at AS "createdAt"
         FROM action_logs al
         LEFT JOIN users u ON u.id = al.user_id
         ORDER BY al.created_at DESC
         LIMIT 8`,
      );

      let feedback = {
        count: 0,
        averageStars: null,
        complaints: 0,
        positive: 0,
      };
      const roCols = await getTableColumnNames("restaurant_orders");
      if (roCols.has("feedback_stars")) {
        const feedbackResult = await pool.query(
          `SELECT
             COUNT(*) FILTER (WHERE feedback_stars IS NOT NULL)::int AS count,
             AVG(feedback_stars)::float AS average,
             COUNT(*) FILTER (WHERE feedback_stars <= 2)::int AS complaints,
             COUNT(*) FILTER (WHERE feedback_stars >= 4)::int AS positive
           FROM restaurant_orders`,
        );
        const r = feedbackResult.rows[0] || {};
        feedback = {
          count: Number(r.count) || 0,
          averageStars: r.average == null ? null : Number(r.average),
          complaints: Number(r.complaints) || 0,
          positive: Number(r.positive) || 0,
        };
      }

      let websiteAnalytics = {
        totalViews: 0,
        last30Views: 0,
        platformViews: [],
        topPaths: [],
        registrationsByPlatform: [],
      };
      const viewCols = await getTableColumnNames("site_page_views");
      if (viewCols.size > 0) {
        const [viewTotals, platformViews, topPaths, registrations] =
          await Promise.all([
            pool.query(
              `SELECT COUNT(*)::int AS total,
                      COUNT(*) FILTER (WHERE created_at >= $1)::int AS last30
               FROM site_page_views`,
              [rangeStart],
            ),
            pool.query(
              `SELECT COALESCE(platform, 'web') AS platform, COUNT(*)::int AS views
               FROM site_page_views
               WHERE created_at >= $1
               GROUP BY platform
               ORDER BY views DESC`,
              [rangeStart],
            ),
            pool.query(
              `SELECT COALESCE(path, '/') AS path, COUNT(*)::int AS views
               FROM site_page_views
               WHERE created_at >= $1
               GROUP BY path
               ORDER BY views DESC
               LIMIT 8`,
              [rangeStart],
            ),
            pool.query(
              `SELECT COALESCE(registration_platform, 'web') AS platform,
                      COUNT(*)::int AS accounts
               FROM customer_accounts
               WHERE created_at >= $1
               GROUP BY registration_platform
               ORDER BY accounts DESC`,
              [rangeStart],
            ),
          ]);
        websiteAnalytics = {
          totalViews: Number(viewTotals.rows[0]?.total) || 0,
          last30Views: Number(viewTotals.rows[0]?.last30) || 0,
          platformViews: platformViews.rows.map((r) => ({
            platform: r.platform || "web",
            views: Number(r.views) || 0,
          })),
          topPaths: topPaths.rows.map((r) => ({
            path: r.path || "/",
            views: Number(r.views) || 0,
          })),
          registrationsByPlatform: registrations.rows.map((r) => ({
            platform: r.platform || "web",
            accounts: Number(r.accounts) || 0,
          })),
        };
      }

      async function salesForTable(table, statusSql) {
        const cols = await getTableColumnNames(table);
        if (cols.size === 0 || !cols.has("total_cost")) {
          return { totalSales: 0, monthSales: 0, yearSales: 0, orders: 0, completed: 0, pending: 0 };
        }
        const createdCol = cols.has("created_at") ? "created_at" : "now()";
        const statusCol = cols.has("status")
          ? "status"
          : cols.has("order_status")
            ? "order_status"
            : null;
        const statusExpr = statusCol ? `upper(COALESCE(${statusCol}::text, ''))` : "''";
        const completedCondition = statusSql(statusExpr).completed;
        const pendingCondition = statusSql(statusExpr).pending;
        const result = await pool.query(
          `SELECT
             COALESCE(SUM(total_cost), 0)::float AS total_sales,
             COALESCE(SUM(total_cost) FILTER (WHERE ${createdCol} >= $1 AND ${createdCol} < $2), 0)::float AS month_sales,
             COALESCE(SUM(total_cost) FILTER (WHERE ${createdCol} >= $3), 0)::float AS year_sales,
             COUNT(*)::int AS orders,
             COUNT(*) FILTER (WHERE ${completedCondition})::int AS completed,
             COUNT(*) FILTER (WHERE ${pendingCondition})::int AS pending
           FROM ${table}`,
          [monthStart, nextMonth, yearStart],
        );
        const r = result.rows[0] || {};
        return {
          totalSales: Number(r.total_sales) || 0,
          monthSales: Number(r.month_sales) || 0,
          yearSales: Number(r.year_sales) || 0,
          orders: Number(r.orders) || 0,
          completed: Number(r.completed) || 0,
          pending: Number(r.pending) || 0,
        };
      }

      const [restaurantSales, cateringSales, eventSales] = await Promise.all([
        salesForTable("restaurant_orders", (s) => ({
          completed: `${s} IN ('DELIVERED', 'COMPLETED')`,
          pending: `${s} IN ('PENDING_CASHIER', 'IN_PREPARATION', 'OUT_FOR_DELIVERY', 'PENDING')`,
        })),
        salesForTable("catering_orders", (s) => ({
          completed: `${s} = 'COMPLETED'`,
          pending: `${s} NOT IN ('COMPLETED', 'CANCELLED')`,
        })),
        salesForTable("event_orders", (s) => ({
          completed: `${s} = 'COMPLETED'`,
          pending: `${s} NOT IN ('COMPLETED', 'CANCELLED')`,
        })),
      ]);

      return res.json({
        asOf: now.toISOString(),
        analytics: {
          website: websiteAnalytics,
          feedback,
          helpRequests: {
            total: Number(helpStats.rows[0]?.total) || 0,
            unresolved: Number(helpStats.rows[0]?.unresolved) || 0,
            resolved: Number(helpStats.rows[0]?.resolved) || 0,
            last30: Number(helpStats.rows[0]?.last30) || 0,
          },
          recentActions: recentActions.rows.map((r) => ({
            id: String(r.id),
            userName: r.userName || "System",
            feature: r.feature || "",
            action: r.action || "",
            createdAt: r.createdAt ? r.createdAt.toISOString() : null,
          })),
          recentHelpRequests: recentHelp.rows.map((r) => ({
            id: String(r.id),
            userName: r.userName || "Public user",
            feature: r.feature || "",
            problem: r.problem || "",
            status: r.status || "unresolved",
            createdAt: r.createdAt ? r.createdAt.toISOString() : null,
          })),
        },
        userManagement: {
          staff: {
            total: Number(userStats.rows[0]?.total) || 0,
            active: Number(userStats.rows[0]?.active) || 0,
            archived: Number(userStats.rows[0]?.archived) || 0,
            roleCounts: {
              superAdmin: Number(userStats.rows[0]?.super_admin) || 0,
              admin: Number(userStats.rows[0]?.admin) || 0,
              manager: Number(userStats.rows[0]?.manager) || 0,
              supervisor: Number(userStats.rows[0]?.supervisor) || 0,
              cashier: Number(userStats.rows[0]?.cashier) || 0,
            },
          },
          customers: {
            total: Number(customerStats.rows[0]?.total) || 0,
            active: Number(customerStats.rows[0]?.active) || 0,
            archived: Number(customerStats.rows[0]?.archived) || 0,
            newThisMonth: Number(customerStats.rows[0]?.new_this_month) || 0,
          },
        },
        sales: {
          restaurant: restaurantSales,
          catering: cateringSales,
          events: eventSales,
          combined: {
            totalSales: restaurantSales.totalSales + cateringSales.totalSales + eventSales.totalSales,
            monthSales: restaurantSales.monthSales + cateringSales.monthSales + eventSales.monthSales,
            yearSales: restaurantSales.yearSales + cateringSales.yearSales + eventSales.yearSales,
            orders: restaurantSales.orders + cateringSales.orders + eventSales.orders,
            completed: restaurantSales.completed + cateringSales.completed + eventSales.completed,
            pending: restaurantSales.pending + cateringSales.pending + eventSales.pending,
          },
        },
      });
    } catch (e) {
      console.error("super admin dashboard summary", e);
      return res.status(500).json({ message: "Failed to load super admin dashboard" });
    }
  },
);

app.get(
  "/api/super-admin/todos",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
    try {
      await ensureSuperAdminTodosSchema();
      const result = await pool.query(
        `SELECT *
         FROM super_admin_todos
         WHERE user_id = $1
         ORDER BY completed ASC, sort_order ASC, created_at DESC`,
        [String(req.user.id)],
      );
      return res.json({ todos: result.rows.map(serializeSuperAdminTodo) });
    } catch (e) {
      console.error("super admin todos list", e);
      return res.status(500).json({ message: "Failed to load to-do list" });
    }
  },
);

app.post(
  "/api/super-admin/todos",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
    try {
      await ensureSuperAdminTodosSchema();
      const title = String(req.body?.title || "").trim();
      const notes = String(req.body?.notes || "").trim();
      if (!title) return res.status(400).json({ message: "title is required" });
      const result = await pool.query(
        `INSERT INTO super_admin_todos (id, user_id, title, notes, sort_order)
         VALUES ($1, $2, $3, $4, COALESCE((SELECT MAX(sort_order) + 1 FROM super_admin_todos WHERE user_id = $2), 0))
         RETURNING *`,
        [crypto.randomUUID(), String(req.user.id), title, notes],
      );
      return res.status(201).json({ todo: serializeSuperAdminTodo(result.rows[0]) });
    } catch (e) {
      console.error("super admin todo create", e);
      return res.status(500).json({ message: "Failed to create to-do" });
    }
  },
);

app.patch(
  "/api/super-admin/todos/:todoId",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
    try {
      await ensureSuperAdminTodosSchema();
      const title =
        req.body?.title === undefined ? null : String(req.body.title || "").trim();
      const notes =
        req.body?.notes === undefined ? null : String(req.body.notes || "").trim();
      const completed =
        req.body?.completed === undefined ? null : req.body.completed === true;
      const result = await pool.query(
        `UPDATE super_admin_todos
         SET title = COALESCE($3, title),
             notes = COALESCE($4, notes),
             completed = COALESCE($5, completed),
             updated_at = now()
         WHERE id = $1 AND user_id = $2
         RETURNING *`,
        [req.params.todoId, String(req.user.id), title, notes, completed],
      );
      if (result.rowCount === 0) {
        return res.status(404).json({ message: "To-do not found" });
      }
      return res.json({ todo: serializeSuperAdminTodo(result.rows[0]) });
    } catch (e) {
      console.error("super admin todo update", e);
      return res.status(500).json({ message: "Failed to update to-do" });
    }
  },
);

app.delete(
  "/api/super-admin/todos/:todoId",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
    try {
      await ensureSuperAdminTodosSchema();
      const result = await pool.query(
        `DELETE FROM super_admin_todos WHERE id = $1 AND user_id = $2`,
        [req.params.todoId, String(req.user.id)],
      );
      if (result.rowCount === 0) {
        return res.status(404).json({ message: "To-do not found" });
      }
      return res.json({ ok: true });
    } catch (e) {
      console.error("super admin todo delete", e);
      return res.status(500).json({ message: "Failed to delete to-do" });
    }
  },
);

// Super Admin: Users
app.get(
  "/api/super-admin/users",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
    const { search, role, archived } = req.query || {};

    const where = [];
    const params = [];
    let i = 1;

    if (search) {
      where.push(`(email ILIKE $${i} OR full_name ILIKE $${i})`);
      params.push(`%${search}%`);
      i++;
    }

    if (role) {
      where.push(`role = $${i}`);
      params.push(role);
      i++;
    }

    if (archived !== undefined) {
      const archivedBool = archived === "true";
      where.push(`archived = $${i}`);
      params.push(archivedBool);
      i++;
    }

    const whereSql = where.length ? `WHERE ${where.join(" AND ")}` : "";

    const result = await pool.query(
      `SELECT u.id, u.email, u.full_name, u.role, u.archived, u.page_permissions, u.birthday, u.contact_number, u.employment_type,
             COALESCE(ca.restaurant_loyalty_points, 0) as restaurant_loyalty_points,
             COALESCE(ca.catering_loyalty_points, 0) as catering_loyalty_points,
             (COALESCE(ca.restaurant_loyalty_points, 0) + COALESCE(ca.catering_loyalty_points, 0)) as loyalty_points
     FROM users u
     LEFT JOIN customer_accounts ca ON u.id::text = ca.id::text
     ${whereSql}
     ORDER BY u.created_at DESC
     LIMIT 200;`,
      params,
    );

    return res.json({
      users: result.rows.map((u) => ({
        id: u.id,
        email: u.email,
        fullName: u.full_name,
        role: u.role,
        archived: u.archived,
        pagePermissions: u.page_permissions || {},
        birthday: u.birthday,
        contactNumber: u.contact_number,
        employmentType: u.employment_type,
      })),
    });
  },
);

app.get(
  "/api/super-admin/role-limits",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
    try {
      const limits = await getRoleAccountLimits();
      return res.json({ limits });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: "Failed to load role limits" });
    }
  },
);

app.put(
  "/api/super-admin/role-limits",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
    try {
      const raw = req.body?.limits;
      if (!raw || typeof raw !== "object") {
        return res.status(400).json({ message: "limits object is required" });
      }
      const existing = await getRoleAccountLimits();
      const merged = { ...existing };
      for (const role of allowedRoles) {
        if (role === "super_admin") continue;
        if (!Object.prototype.hasOwnProperty.call(raw, role)) continue;
        const v = raw[role];
        if (v === null || v === "" || v === undefined) {
          delete merged[role];
          continue;
        }
        const n = Number(v);
        if (!Number.isFinite(n) || n < 1) {
          return res.status(400).json({ message: `Invalid limit for ${role}` });
        }
        merged[role] = Math.floor(n);
      }
      await setRoleAccountLimits(merged);
      return res.json({ ok: true, limits: await getRoleAccountLimits() });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: "Failed to save role limits" });
    }
  },
);

//create account
app.post("/api/super-admin/users", authRequired, requireSuperAdmin, async (req, res) => {
    try {
      if (!(await requireSuperAdminPassword(req, res))) return;
      const { email, password, fullName, role, birthday, contactNumber, employmentType } = req.body || {};

      if (!email || !password || !fullName || !role) {
        return res
          .status(400)
          .json({ message: "email, password, fullName, role are required" });
      }

      if (!allowedRoles.has(role)) {
        return res.status(400).json({ message: "Invalid role" });
      }

      const passwordHash = await bcrypt.hash(password, 10);
      const otp = generateOTP();
      const expiry = new Date(Date.now() + 10 * 60 * 1000); // 10 mins
      const normalizedEmail = String(email).trim().toLowerCase();
      const existing = await pool.query(
        `SELECT id, archived FROM users WHERE lower(trim(email::text)) = $1`,
        [normalizedEmail],
      );

      if (existing.rows.length > 0 && !existing.rows[0].archived) {
        return res.status(400).json({ message: "Email already exists" });
      }

      if (role !== "super_admin") {
        const limits = await getRoleAccountLimits();
        const cap = limits[role];
        if (cap != null && Number.isFinite(Number(cap)) && Number(cap) > 0) {
          const cnt = await pool.query(
            `SELECT COUNT(*)::int AS n FROM users WHERE role = $1 AND archived = FALSE`,
            [role],
          );
          if (cnt.rows[0].n >= Number(cap)) {
            return res.status(400).json({
              message: `Role limit reached: at most ${Number(cap)} active ${role} account(s). Raise the cap under Manage Accounts → Role limits.`,
            });
          }
        }
      }

      if (existing.rows.length > 0 && existing.rows[0].archived) {
        const userId = existing.rows[0].id;
        await pool.query(
          `UPDATE users SET
             email = $1,
             password_hash = $2,
             full_name = $3,
             role = $4,
             birthday = $5,
             contact_number = $6,
             employment_type = $7,
             archived = FALSE,
             is_verified = FALSE,
             otp_code = $8,
             otp_expiry = $9
           WHERE id = $10`,
          [
            normalizedEmail,
            passwordHash,
            fullName,
            role,
            birthday || null,
            contactNumber || null,
            employmentType || null,
            otp,
            expiry,
            userId,
          ],
        );

        await sendOtpEmail(normalizedEmail, otp);

        await logAction({
          userId: req.user.id,
          feature: "",
          action: "reactivated archived account (OTP sent)",
          other: { email: normalizedEmail, role },
        });

        return res.json({
          ok: true,
          message: "Archived account was restored. OTP sent to email.",
        });
      }

      const userId = await allocateStaffUserId();
      await pool.query(
        `INSERT INTO users 
        (id, email, password_hash, full_name, role, birthday, contact_number, employment_type, archived, is_verified, otp_code, otp_expiry)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, FALSE, FALSE, $9, $10);`,
        [userId, normalizedEmail, passwordHash, fullName, role, birthday || null, contactNumber || null, employmentType || null, otp, expiry],
      );

      await sendOtpEmail(normalizedEmail, otp);

      await logAction({
        userId: req.user.id,
        feature: "",
        action: "created account (OTP sent)",
        other: { email: normalizedEmail, role },
      });

      return res.json({
        ok: true,
        message: "User created. OTP sent to email.",
      });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: "Failed to create user" });
    }
  },
);

//verify email
app.post("/api/auth/verify-otp", async (req, res) => {
  try {
    const { email, otp } = req.body;

    const emailNorm = String(email ?? "").trim().toLowerCase();
    const result = await pool.query(
      `SELECT * FROM users WHERE lower(trim(email::text)) = $1`,
      [emailNorm],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: "User not found" });
    }

    const user = result.rows[0];

    if (user.otp_code !== otp) {
      return res.status(400).json({ message: "Invalid OTP" });
    }

    if (new Date() > user.otp_expiry) {
      return res.status(400).json({ message: "OTP expired" });
    }

    await pool.query(
      `UPDATE users 
       SET is_verified = TRUE, otp_code = NULL, otp_expiry = NULL
       WHERE email = $1`,
      [email],
    );

    return res.json({ message: "Account verified successfully" });
  } catch (e) {
    return res.status(500).json({ message: "Verification failed" });
  }
});

app.post(
  "/api/super-admin/users/:userId",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
    try {
      if (!(await requireSuperAdminPassword(req, res))) return;
      const { userId } = req.params;
      const { fullName, role, birthday, contactNumber, employmentType } = req.body || {};
      if (!fullName || !role) {
        return res
          .status(400)
          .json({ message: "fullName and role are required" });
      }

      if (!allowedRoles.has(role)) {
        return res.status(400).json({ message: "Invalid role" });
      }

      await pool.query(
        `UPDATE users
       SET full_name = $1, role = $2, birthday = $3, contact_number = $4, employment_type = $5
       WHERE id = $6;`,
        [fullName, role, birthday || null, contactNumber || null, employmentType || null, userId],
      );

      await logAction({
        userId: req.user.id,
        feature: "",
        action: "updated account",
        other: { userId, role },
      });

      return res.json({ ok: true });
    } catch (e) {
      return res.status(500).json({ message: "Failed to update user" });
    }
  },
);

app.post(
  "/api/super-admin/users/:userId/page-permissions",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
    try {
      const { userId } = req.params;
      const { pagePermissions } = req.body || {};
      if (!pagePermissions || typeof pagePermissions !== "object") {
        return res
          .status(400)
          .json({ message: "pagePermissions object is required" });
      }

      const result = await pool.query(
        `UPDATE users SET page_permissions = $1::jsonb WHERE id = $2 RETURNING page_permissions;`,
        [JSON.stringify(pagePermissions), userId],
      );

      if (result.rowCount === 0) {
        return res.status(404).json({ message: "User not found" });
      }

      await logAction({
        userId: req.user.id,
        feature: "",
        action: "updated page permissions",
        other: { userId },
      });

      return res.json({
        ok: true,
        pagePermissions: result.rows[0].page_permissions || {},
      });
    } catch (e) {
      return res
        .status(500)
        .json({ message: "Failed to update page permissions" });
    }
  },
);

app.post(
  "/api/super-admin/users/:userId/archive",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
    try {
      if (!(await requireSuperAdminPassword(req, res))) return;
      const { userId } = req.params;
      const { archived } = req.body || {};
      const nextArchived = archived === true;

      await pool.query(
        `UPDATE users
       SET archived = $1
       WHERE id = $2;`,
        [nextArchived, userId],
      );

      await logAction({
        userId: req.user.id,
        feature: "",
        action: nextArchived ? "archived account" : "unarchived account",
        other: { userId, archived: nextArchived },
      });

      return res.json({ ok: true });
    } catch (e) {
      return res
        .status(500)
        .json({ message: "Failed to update archive status" });
    }
  },
);

// Super Admin: Help Requests
app.get(
  "/api/super-admin/help-requests",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "supervisor", "admin"])),
  async (req, res) => {
    const { search, status } = req.query || {};

    const where = [];
    const params = [];
    let i = 1;

    if (status && allowedHelpStatuses.has(status)) {
      where.push(`hr.status = $${i}`);
      params.push(status);
      i++;
    }

    if (search) {
      where.push(`(
      u.full_name ILIKE $${i}
      OR hr.feature ILIKE $${i}
      OR hr.problem ILIKE $${i}
      OR hr.request ILIKE $${i}
    )`);
      params.push(`%${search}%`);
      i++;
    }

    const whereSql = where.length ? `WHERE ${where.join(" AND ")}` : "";

    const result = await pool.query(
      `SELECT
      hr.id,
      hr.user_id,
      COALESCE(u.full_name, hr.problem) AS "userName",
      hr.feature,
      hr.problem,
      hr.request,
      hr.status,
      hr.created_at AS "createdAt"
     FROM help_requests hr
     LEFT JOIN users u ON u.id = hr.user_id
     ${whereSql}
     ORDER BY hr.created_at DESC
     LIMIT 500;`,
      params,
    );

    return res.json({
      helpRequests: result.rows.map((r) => ({
        id: r.id,
        userId: r.user_id,
        userName: r.userName,
        feature: r.feature,
        problem: r.problem,
        request: r.request,
        status: r.status,
        createdAt: r.createdAt.toISOString(),
      })),
    });
  },
);

app.post(
  "/api/super-admin/help-requests/:requestId/resolve",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "supervisor", "admin"])),
  async (req, res) => {
    const { requestId } = req.params;

    const client = await pool.connect();
    try {
      await client.query("BEGIN;");

      const hrRes = await client.query(
        `SELECT id, user_id, feature
       FROM help_requests
       WHERE id = $1;`,
        [requestId],
      );

      if (hrRes.rowCount === 0) {
        await client.query("ROLLBACK;");
        return res.status(404).json({ message: "Help request not found" });
      }

      const hr = hrRes.rows[0];

      await client.query(
        `UPDATE help_requests
       SET status = 'resolved',
           resolved_at = now(),
           resolved_by = $1
       WHERE id = $2;`,
        [req.user.id, requestId],
      );

      // Notification to the sender
      await client.query(
        `INSERT INTO notifications (user_id, message)
       VALUES ($1, $2);`,
        [hr.user_id, "Your concern has been resolved. Thank you!"],
      );

      // Action log for the resolver
      await logAction({
        client,
        userId: req.user.id,
        feature: hr.feature,
        action: "resolved help request",
        other: { helpRequestId: hr.id, resolvedUserId: hr.user_id },
      });

      await client.query("COMMIT;");
      return res.json({ ok: true });
    } catch (e) {
      await client.query("ROLLBACK;");
      return res
        .status(500)
        .json({ message: "Failed to resolve help request" });
    } finally {
      client.release();
    }
  },
);

// Super Admin: Action Logs
app.get(
  "/api/super-admin/action-logs",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
    const { search } = req.query || {};

    const params = [];
    let whereSql = "";
    if (search) {
      whereSql = `WHERE (
      u.full_name ILIKE $1 OR
      al.feature ILIKE $1 OR
      al.action ILIKE $1
    )`;
      params.push(`%${search}%`);
    }

    const result = await pool.query(
      `SELECT
      al.id,
      al.user_id,
      u.full_name AS "userName",
      al.feature,
      al.action,
      al.other,
      al.created_at AS "createdAt"
     FROM action_logs al
     JOIN users u ON u.id = al.user_id
     ${whereSql}
     ORDER BY al.created_at DESC
     LIMIT 500;`,
      params,
    );

    return res.json({
      actionLogs: result.rows.map((r) => ({
        id: r.id,
        userName: r.userName,
        feature: r.feature,
        action: r.action,
        other: r.other,
        createdAt: r.createdAt.toISOString(),
      })),
    });
  },
);

function buildHeuristicFeedbackAnalysis(feedbacks) {
  const count = feedbacks.length;
  if (count === 0) {
    return {
      summary: "No customer feedback to analyze yet.",
      interpretation: "Encourage customers to rate delivered restaurant orders from the website footer.",
      recommendations: [
        "Promote the feedback link after order delivery notifications.",
        "Review delivery times and food quality once reviews arrive.",
      ],
      source: "heuristic",
      feedbackCount: 0,
      averageStars: null,
    };
  }

  const stars = feedbacks.map((f) => Number(f.stars)).filter((n) => Number.isFinite(n));
  const avg = stars.length ? stars.reduce((a, b) => a + b, 0) / stars.length : null;
  const low = feedbacks.filter((f) => Number(f.stars) <= 2);
  const high = feedbacks.filter((f) => Number(f.stars) >= 4);
  const withRemarks = feedbacks.filter((f) => String(f.remarks || "").trim().length > 0);

  const summary = `Based on ${count} review(s), average rating is ${avg != null ? avg.toFixed(1) : "n/a"} stars. `
    + `${high.length} positive (4–5★), ${low.length} critical (1–2★), ${withRemarks.length} included written remarks.`;

  let interpretation = "Overall sentiment appears ";
  if (avg != null) {
    if (avg >= 4.2) interpretation += "strong — customers are generally satisfied.";
    else if (avg >= 3.5) interpretation += "mixed — some areas may need attention.";
    else interpretation += "weak — investigate recurring complaints in remarks.";
  } else {
    interpretation += "unclear — star ratings are missing on some rows.";
  }

  const recommendations = [];
  if (low.length > 0) {
    recommendations.push(
      `Follow up on ${low.length} low-rated order(s); read remarks for delivery, temperature, or portion issues.`,
    );
  }
  if (withRemarks.length > 0) {
    recommendations.push(
      "Tag recurring themes from written remarks (e.g. late delivery, packaging) and assign owners in kitchen or logistics.",
    );
  }
  recommendations.push(
    "Share positive feedback with the team weekly; address top complaint in the next ops meeting.",
  );
  if (avg != null && avg < 4) {
    recommendations.push(
      "Consider a short customer recovery offer (discount or free item) for 1–2★ orders within 48 hours.",
    );
  }

  return {
    summary,
    interpretation,
    recommendations,
    source: "heuristic",
    feedbackCount: count,
    averageStars: avg,
  };
}

function normalizeFeedbackAnalysisPayload(parsed, feedbacks, source) {
  const fallback = buildHeuristicFeedbackAnalysis(feedbacks);
  const stars = feedbacks.map((f) => Number(f.stars)).filter((n) => Number.isFinite(n));
  const avg = stars.length ? stars.reduce((a, b) => a + b, 0) / stars.length : null;
  const data = parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
  const keyTopics = Array.isArray(data.key_topics)
    ? data.key_topics.map((t) => String(t).trim()).filter(Boolean).slice(0, 8)
    : [];
  const recommendations = Array.isArray(data.recommendations)
    ? data.recommendations.map((r) => String(r).trim()).filter(Boolean).slice(0, 8)
    : [];
  const sentiment = String(data.sentiment || "").trim();
  const topicText = keyTopics.length ? ` Key topics: ${keyTopics.join(", ")}.` : "";
  const interpretation =
    String(data.interpretation || "").trim() ||
    (Array.isArray(data.complaints) || Array.isArray(data.praises) || Array.isArray(data.insights)
      ? [
          Array.isArray(data.complaints) && data.complaints.length
            ? `Complaints: ${data.complaints.map((v) => String(v).trim()).filter(Boolean).slice(0, 3).join("; ")}.`
            : "",
          Array.isArray(data.praises) && data.praises.length
            ? `Praises: ${data.praises.map((v) => String(v).trim()).filter(Boolean).slice(0, 3).join("; ")}.`
            : "",
          Array.isArray(data.insights) && data.insights.length
            ? `Insights: ${data.insights.map((v) => String(v).trim()).filter(Boolean).slice(0, 3).join("; ")}.`
            : "",
        ].filter(Boolean).join(" ")
      : "") ||
    (sentiment || topicText
      ? `Overall sentiment: ${sentiment || "mixed"}.${topicText}`.trim()
      : fallback.interpretation);
  const nlpRecommendations = Array.isArray(data.insights)
    ? data.insights.map((r) => String(r).trim()).filter(Boolean).slice(0, 5)
    : [];

  return {
    summary: String(data.summary || "").trim() || fallback.summary,
    interpretation,
    recommendations: recommendations.length
      ? recommendations
      : nlpRecommendations.length
        ? nlpRecommendations
        : fallback.recommendations,
    source,
    feedbackCount: feedbacks.length,
    averageStars: avg,
  };
}

function parseJsonFromText(text) {
  if (!text || typeof text !== "string") return null;
  const trimmed = text.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "");
  try {
    return JSON.parse(trimmed);
  } catch {
    const first = trimmed.indexOf("{");
    const last = trimmed.lastIndexOf("}");
    if (first >= 0 && last > first) {
      try {
        return JSON.parse(trimmed.slice(first, last + 1));
      } catch {
        return null;
      }
    }
    return null;
  }
}

function extractRunpodNlpResult(output) {
  if (!output || typeof output !== "object") return null;
  if (output.result && typeof output.result === "object") return output.result;
  if (typeof output.result === "string") return parseJsonFromText(output.result);
  if (output.output && typeof output.output === "object") return extractRunpodNlpResult(output.output);
  if (output.summary || output.interpretation || output.recommendations || output.sentiment) {
    return output;
  }
  return parseJsonFromText(output.raw_output || output.text || output.response || "");
}

async function analyzeFeedbackWithAi(feedbacks) {
  try {
    const parsed = await analyzeCustomerFeedbackOverview(feedbacks);
    return normalizeFeedbackAnalysisPayload(parsed, feedbacks, "openai");
  } catch (e) {
    console.error("[feedback AI] OpenAI service failed:", e?.message || e);
    return buildHeuristicFeedbackAnalysis(feedbacks);
  }
}

// Super Admin: Customer feedback (restaurant orders)
app.get(
  "/api/super-admin/customer-feedback",
  authRequired,
  (req, res, next) => requireRoles(req, res, next, new Set(["manager", "admin", "super_admin"])),
  async (req, res) => {
    try {
      const roCols = await ensureRestaurantOrdersCanonicalColumns();
      await ensureFeedbackAnalyticsSchema();
      const orderIdSql = restaurantOrderIdExpr(roCols);
      const { search } = req.query || {};
      const params = [];
      let whereSql = "WHERE ro.feedback_stars IS NOT NULL";
      if (search) {
        whereSql += ` AND (
          (${orderIdSql})::text ILIKE $1 OR
          COALESCE(ro.full_name, '') ILIKE $1 OR
          COALESCE(ca.email, ro.user_email, '') ILIKE $1 OR
          COALESCE(ro.feedback_remarks, '') ILIKE $1
        )`;
        params.push(`%${search}%`);
      }

      const result = await pool.query(
        `SELECT
          ro.id,
          (${orderIdSql}) AS "orderNo",
          COALESCE(ca.full_name, ro.full_name, 'Guest') AS "customerName",
          COALESCE(ca.email, ro.user_email, '') AS "customerEmail",
          ro.feedback_stars AS stars,
          COALESCE(ro.feedback_remarks, '') AS remarks,
          ro.feedback_submitted_at AS "submittedAt"
        FROM restaurant_orders ro
        LEFT JOIN customer_accounts ca ON ${customerAccountIdJoinSql('ca', 'ro')}
        ${whereSql}
        ORDER BY ro.feedback_submitted_at DESC NULLS LAST, ro.updated_at DESC
        LIMIT 1000`,
        params,
      );
      const genericParams = [];
      let genericWhereSql = "WHERE message IS NOT NULL";
      if (search) {
        genericWhereSql += ` AND (
          COALESCE(customer_name, '') ILIKE $1 OR
          COALESCE(customer_email, '') ILIKE $1 OR
          COALESCE(message, '') ILIKE $1
        )`;
        genericParams.push(`%${search}%`);
      }
      const generic = await pool.query(
        `SELECT
          id,
          COALESCE(customer_name, 'Website visitor') AS "customerName",
          COALESCE(customer_email, '') AS "customerEmail",
          COALESCE(rating, 0) AS stars,
          COALESCE(message, '') AS remarks,
          created_at AS "submittedAt",
          COALESCE(source, 'web') AS source
        FROM feedback
        ${genericWhereSql}
        ORDER BY created_at DESC
        LIMIT 1000`,
        genericParams,
      );

      return res.json({
        feedback: [
          ...result.rows.map((r) => ({
            id: String(r.id),
            orderNo: r.orderNo != null ? String(r.orderNo) : "",
            customerName: r.customerName || "Guest",
            customerEmail: r.customerEmail || "",
            stars: Number(r.stars) || 0,
            remarks: r.remarks || "",
            submittedAt: r.submittedAt ? r.submittedAt.toISOString() : null,
          })),
          ...generic.rows.map((r) => ({
            id: String(r.id),
            orderNo: "Contact Us",
            customerName: r.customerName || "Website visitor",
            customerEmail: r.customerEmail || "",
            stars: Number(r.stars) || 0,
            remarks: r.remarks || "",
            submittedAt: r.submittedAt ? r.submittedAt.toISOString() : null,
            source: r.source || "contact_us",
          })),
        ].sort((a, b) => new Date(b.submittedAt || 0) - new Date(a.submittedAt || 0)),
      });
    } catch (error) {
      console.error("Error listing customer feedback:", error);
      return res.status(500).json({ error: "Failed to load customer feedback" });
    }
  },
);

app.post(
  "/api/super-admin/customer-feedback/analyze",
  authRequired,
  (req, res, next) => requireRoles(req, res, next, new Set(["manager", "admin", "super_admin"])),
  async (req, res) => {
    try {
      const roCols = await ensureRestaurantOrdersCanonicalColumns();
      await ensureFeedbackAnalyticsSchema();
      const orderIdSql = restaurantOrderIdExpr(roCols);
      const { search } = { ...req.query, ...(req.body || {}) };
      const params = [];
      let whereSql = "WHERE ro.feedback_stars IS NOT NULL";
      if (search) {
        whereSql += ` AND (
          (${orderIdSql})::text ILIKE $1 OR
          COALESCE(ro.full_name, '') ILIKE $1 OR
          COALESCE(ca.email, ro.user_email, '') ILIKE $1 OR
          COALESCE(ro.feedback_remarks, '') ILIKE $1
        )`;
        params.push(`%${search}%`);
      }

      const result = await pool.query(
        `SELECT
          (${orderIdSql}) AS "orderNo",
          COALESCE(ca.full_name, ro.full_name, 'Guest') AS "customerName",
          ro.feedback_stars AS stars,
          COALESCE(ro.feedback_remarks, '') AS remarks,
          ro.feedback_submitted_at AS "submittedAt"
        FROM restaurant_orders ro
        LEFT JOIN customer_accounts ca ON ${customerAccountIdJoinSql('ca', 'ro')}
        ${whereSql}
        ORDER BY ro.feedback_submitted_at DESC NULLS LAST
        LIMIT 200`,
        params,
      );
      const genericParams = [];
      let genericWhereSql = "WHERE message IS NOT NULL";
      if (search) {
        genericWhereSql += ` AND (
          COALESCE(customer_name, '') ILIKE $1 OR
          COALESCE(customer_email, '') ILIKE $1 OR
          COALESCE(message, '') ILIKE $1
        )`;
        genericParams.push(`%${search}%`);
      }
      const generic = await pool.query(
        `SELECT
          'Contact Us' AS "orderNo",
          COALESCE(customer_name, 'Website visitor') AS "customerName",
          COALESCE(rating, 0) AS stars,
          COALESCE(message, '') AS remarks,
          created_at AS "submittedAt"
        FROM feedback
        ${genericWhereSql}
        ORDER BY created_at DESC
        LIMIT 200`,
        genericParams,
      );

      const feedbacks = [
        ...result.rows.map((r) => ({
          orderNo: r.orderNo != null ? String(r.orderNo) : "",
          customerName: r.customerName || "Guest",
          stars: Number(r.stars) || 0,
          remarks: r.remarks || "",
          submittedAt: r.submittedAt ? r.submittedAt.toISOString() : null,
        })),
        ...generic.rows.map((r) => ({
          orderNo: "Contact Us",
          customerName: r.customerName || "Website visitor",
          stars: Number(r.stars) || 0,
          remarks: r.remarks || "",
          submittedAt: r.submittedAt ? r.submittedAt.toISOString() : null,
        })),
      ].sort((a, b) => new Date(b.submittedAt || 0) - new Date(a.submittedAt || 0));

      const analysis = await analyzeFeedbackWithAi(feedbacks);
      return res.json({ analysis });
    } catch (error) {
      console.error("Error analyzing customer feedback:", error);
      return res.status(500).json({ error: "Failed to analyze customer feedback" });
    }
  },
);

// Manager: create/list/finalize event orders
const WEBSITE_CONTENT_ROW_ID = "00000000-0000-0000-0000-000000000001";

function isNonEmptyWebsiteContent(content) {
  return (
    content &&
    typeof content === "object" &&
    !Array.isArray(content) &&
    Object.keys(content).length > 0
  );
}

/** One-time / lazy migration: legacy rows and website-content.json → canonical row. */
async function migrateWebsiteContentIfNeeded() {
  try {
    const canonical = await pool.query(
      `SELECT content, updated_at FROM website_content WHERE id = $1::uuid LIMIT 1`,
      [WEBSITE_CONTENT_ROW_ID],
    );
    const canonicalRow = canonical.rows[0] || null;
    const canonicalHasContent = isNonEmptyWebsiteContent(canonicalRow?.content);

    const latestLegacy = await pool.query(
      `
      SELECT content, updated_at FROM website_content
      WHERE id <> $1::uuid
        AND content IS NOT NULL
        AND content::text NOT IN ('{}', 'null')
      ORDER BY updated_at DESC NULLS LAST, created_at DESC
      LIMIT 1
    `,
      [WEBSITE_CONTENT_ROW_ID],
    );

    const legacyRow = latestLegacy.rows[0] || null;
    if (legacyRow && isNonEmptyWebsiteContent(legacyRow.content)) {
      const canonicalUpdated = canonicalRow?.updated_at
        ? new Date(canonicalRow.updated_at).getTime()
        : 0;
      const legacyUpdated = legacyRow.updated_at
        ? new Date(legacyRow.updated_at).getTime()
        : 0;
      if (!canonicalHasContent || legacyUpdated > canonicalUpdated) {
        await writeWebsiteContent(legacyRow.content);
        console.log("[website-content] Migrated latest legacy DB row → canonical id");
        return;
      }
    }

    if (canonicalHasContent) {
      return;
    }

    try {
      const raw = await fs.readFile(websiteContentPath, "utf8");
      const parsed = JSON.parse(raw);
      if (isNonEmptyWebsiteContent(parsed)) {
        await writeWebsiteContent(parsed);
        console.log("[website-content] Seeded canonical row from website-content.json");
      }
    } catch {
      /* optional seed file */
    }
  } catch (error) {
    console.warn("[website-content] migration skipped:", error.message);
  }
}

async function readWebsiteContent() {
  try {
    await migrateWebsiteContentIfNeeded();

    const result = await pool.query(
      `SELECT content FROM website_content WHERE id = $1::uuid LIMIT 1`,
      [WEBSITE_CONTENT_ROW_ID],
    );

    if (result.rows.length > 0 && isNonEmptyWebsiteContent(result.rows[0].content)) {
      return result.rows[0].content;
    }

    return {};
  } catch (error) {
    console.error("Error reading website content from database:", error);
    return {};
  }
}

async function writeWebsiteContent(content) {
  if (!isNonEmptyWebsiteContent(content)) {
    throw new Error("website content must be a non-empty object");
  }
  try {
    await pool.query(
      `
      INSERT INTO website_content (id, content, created_at, updated_at)
      VALUES ($1::uuid, $2::jsonb, NOW(), NOW())
      ON CONFLICT (id)
      DO UPDATE SET
        content = EXCLUDED.content,
        updated_at = NOW()
    `,
      [WEBSITE_CONTENT_ROW_ID, content],
    );
    try {
      await fs.writeFile(
        websiteContentPath,
        JSON.stringify(content, null, 2),
        "utf8",
      );
    } catch (fileErr) {
      console.warn("[website-content] could not update JSON backup:", fileErr.message);
    }
  } catch (error) {
    console.error("Error writing website content to database:", error);
    throw error;
  }
}

app.get("/api/website-content", async (req, res) => {
  try {
    res.set("Cache-Control", "no-store, no-cache, must-revalidate");
    const content = await readWebsiteContent();
    return res.json({ content, updatedAt: Date.now() });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ message: "Failed to load website content" });
  }
});

app.put(
  "/api/website-content",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "admin", "super_admin"])),
  async (req, res) => {
    try {
      const { content } = req.body || {};
      if (!content || typeof content !== "object" || Array.isArray(content)) {
        return res.status(400).json({ message: "content object is required" });
      }

      await writeWebsiteContent(content);
      try {
        await logAction({
          userId: req.user.id,
          feature: "Website Content",
          action: "updated website content",
        });
      } catch (logError) {
        console.warn("[website-content] content saved, but audit log failed:", logError.message);
      }
      return res.json({ ok: true, content });
    } catch (e) {
      console.error(e);
      if (/quota|too large|payload/i.test(String(e?.message || e))) {
        return res.status(507).json({
          message:
            "Website content save exceeded storage quota. Try replacing large CMS images with compressed versions or remove unused gallery images.",
          code: "website_content_quota_exceeded",
        });
      }
      return res.status(500).json({ message: "Failed to save website content" });
    }
  },
);

app.post(
  "/api/manager/events/orders",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "admin", "super_admin"])),
  async (req, res) => {
    try {
      const {
        eventTitle,
        orderType,
        eventType,
        formalityLevel,
        customerName,
        contactPerson,
        contactNumber,
        emailAddress,
        scheduleSlots,
        address,
        guestCount,
        menu,
        themeDesign,
        allergens,
      } = req.body || {};
      const allergensText = String(allergens ?? '').trim();

      // For catering-only orders, event-specific fields are optional
      const isCateringOnly = orderType === 'catering';
      
      if (
        !orderType ||
        !customerName ||
        !contactPerson ||
        !contactNumber ||
        !emailAddress ||
        !address ||
        guestCount === undefined ||
        !Array.isArray(scheduleSlots) ||
        !Array.isArray(menu) ||
        (!isCateringOnly && !themeDesign)
      ) {
        return res.status(400).json({ message: "Missing required fields" });
      }

      // For catering+event orders, require event-specific fields
      if (!isCateringOnly && (!eventTitle || !eventType || !formalityLevel)) {
        return res.status(400).json({ message: "Missing required event fields" });
      }

      const transactionId = await allocateCateringTransactionId();
      let result;
      
      if (isCateringOnly) {
        // Use separate catering_orders table for catering-only orders
        result = await pool.query(
          `INSERT INTO catering_orders
            (source, status, order_type, catering_id, customer_name, contact_person, contact_number, email_address,
             schedule_slots, address, guest_count, menu, allergens, created_by, updated_by)
          VALUES
            ('new_event', 'for_processing', 'catering', $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
           RETURNING id, catering_id;`,
          [
            transactionId,
            customerName,
            contactPerson,
            contactNumber,
            emailAddress,
            JSON.stringify(scheduleSlots),
            address,
            Number(guestCount),
            JSON.stringify(menu),
            allergensText,
            req.user.id,
            req.user.id,
          ]
        );
      } else {
        // Use event_orders table for catering+event orders
        result = await pool.query(
          `INSERT INTO event_orders
            (source, status, event_title, order_type, event_type, formality_level, catering_id,
             customer_name, contact_person, contact_number, email_address,
             schedule_slots, address, guest_count, menu, theme_design, allergens,
             created_by, updated_by)
           VALUES
            ('new_event', 'for_processing', $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
           RETURNING id, catering_id;`,
          [
            eventTitle,
            orderType,
            eventType,
            formalityLevel,
            transactionId,
            customerName,
            contactPerson,
            contactNumber,
            emailAddress,
            JSON.stringify(scheduleSlots),
            address,
            Number(guestCount),
            JSON.stringify(menu),
            JSON.stringify(themeDesign),
            allergensText,
            req.user.id,
            req.user.id,
          ]
        );
      }

      await logAction({
        userId: req.user.id,
        feature: "Events",
        action: "submitted new event",
        other: { orderId: result.rows[0].id, cateringId: result.rows[0].catering_id },
      });

      return res.json({
        ok: true,
        id: result.rows[0].id,
        cateringId: result.rows[0].catering_id,
      });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: "Failed to create order" });
    }
  },
);

app.post(
  "/api/events/theme-design/swap-colors",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "supervisor", "admin", "super_admin"])),
  async (req, res) => {
    try {
      const {
        imageBase64,
        masks,
        edits,
        picksBase64,
        prompt,
        currentTintColorHex,
      } = req.body || {};

      // Backward compatibility: original tint-only flow.
      if (!imageBase64) {
        if (!Array.isArray(picksBase64) || picksBase64.length === 0) {
          return res.status(400).json({ message: "picksBase64 is required" });
        }
        const tintColorHex = resolveThemeTintColor(prompt, currentTintColorHex);
        return res.json({
          ok: true,
          tintEnabled: true,
          tintColorHex,
          colorPrompt: String(prompt || "").trim(),
        });
      }

      const cleanedImageBase64 = sanitizeBase64Image(imageBase64);
      if (!Array.isArray(masks) || masks.length === 0) {
        throw toHttpError("masks is required", 400, "invalid_masks");
      }
      if (!Array.isArray(edits) || edits.length === 0) {
        throw toHttpError("edits is required", 400, "invalid_edits");
      }

      const normalizedEdits = edits
        .filter((e) => e && typeof e === "object")
        .map((e) => ({
          object_id: String(e.objectId || e.object_id || ""),
          target_hex: ensureHexColor(e.targetHex || e.target_hex || currentTintColorHex),
          intensity: Number(e.intensity ?? 1),
        }))
        .filter((e) => e.object_id);
      if (!normalizedEdits.length) {
        throw toHttpError("No valid edits provided", 400, "invalid_edits");
      }

      const normalizedMasks = masks
        .filter((m) => m && typeof m === "object")
        .map((m) => ({
          object_id: String(m.objectId || m.object_id || ""),
          polygon_points: Array.isArray(m.polygonPoints)
            ? m.polygonPoints
            : Array.isArray(m.polygon_points)
              ? m.polygon_points
              : undefined,
          mask_rle: m.maskRle || m.mask_rle || undefined,
          mask_base64: m.maskBase64 || m.mask_base64 || undefined,
        }))
        .filter((m) => m.object_id);
      if (!normalizedMasks.length) {
        throw toHttpError("No valid masks provided", 400, "invalid_masks");
      }

      const fastApiResponse = await callFastApi({
        req,
        routePath: "/v1/edit/recolor",
        timeoutMs: AI_SERVICE_TIMEOUT_RECOLOR_MS,
        payload: {
          image_base64: cleanedImageBase64,
          masks: normalizedMasks,
          edits: normalizedEdits,
        },
      });

      const applied = Array.isArray(fastApiResponse.applied)
        ? fastApiResponse.applied.map((row) => ({
            objectId: String(row.object_id || row.objectId || ""),
            targetHex: ensureHexColor(row.target_hex || row.targetHex || currentTintColorHex),
          }))
        : [];
      const skipped = Array.isArray(fastApiResponse.skipped)
        ? fastApiResponse.skipped.map((row) => ({
            objectId: String(row.object_id || row.objectId || ""),
            reason: String(row.reason || "Skipped by AI service"),
          }))
        : [];

      return res.json({
        ok: true,
        imageBase64: String(fastApiResponse.image_base64 || fastApiResponse.imageBase64 || ""),
        applied,
        skipped,
      });
    } catch (e) {
      console.error(e);
      return sendHttpError(res, e, "Failed to process theme color");
    }
  },
);

app.post(
  "/api/events/theme-design/yolo-sam-infer",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "supervisor", "admin", "super_admin"])),
  async (req, res) => {
    try {
      const { imageBase64, confidenceThreshold, maxDetections, maskFormat } = req.body || {};
      const cleanedImageBase64 = sanitizeBase64Image(imageBase64);
      const fastApiResponse = await callFastApiWithTimeoutRetry({
        req,
        routePath: "/v1/infer/yolo-sam",
        timeoutMs: AI_SERVICE_TIMEOUT_SEGMENT_MS,
        timeoutRetries: AI_SERVICE_SEGMENT_TIMEOUT_RETRIES,
        payload: {
          image_base64: cleanedImageBase64,
          confidence_threshold: Number.isFinite(Number(confidenceThreshold))
            ? Number(confidenceThreshold)
            : 0.25,
          max_detections: Number.isFinite(Number(maxDetections))
            ? Number(maxDetections)
            : 30,
          mask_format: ["polygon", "rle", "alpha_png"].includes(String(maskFormat))
            ? String(maskFormat)
            : "polygon",
        },
      });

      const detections = normalizeDetections(
        (fastApiResponse.detections || []).map((d, index) => ({
          classId: d.id || d.classId || d.class_id || `det_${index}`,
          className: d.label || d.className || d.class_name || "Object",
          confidence: d.confidence,
          boundingBox: {
            left: Number(d.box?.x ?? d.box?.left ?? 0),
            top: Number(d.box?.y ?? d.box?.top ?? 0),
            width: Number(d.box?.width ?? 0),
            height: Number(d.box?.height ?? 0),
          },
        })),
      );

      const objects = Array.isArray(fastApiResponse.objects)
        ? fastApiResponse.objects.map((d, index) => ({
            id: String(d.id || d.object_id || `sam_${index}`),
            label: String(d.label || "Object"),
            score: Number(d.score || 0),
            boundingBox: {
              left: Number(d.box?.x ?? d.box?.left ?? detections[index]?.boundingBox?.left ?? 0),
              top: Number(d.box?.y ?? d.box?.top ?? detections[index]?.boundingBox?.top ?? 0),
              width: Number(d.box?.width ?? detections[index]?.boundingBox?.width ?? 0),
              height: Number(d.box?.height ?? detections[index]?.boundingBox?.height ?? 0),
            },
            polygonPoints: Array.isArray(d.polygon_points)
              ? d.polygon_points
              : Array.isArray(d.polygonPoints)
                ? d.polygonPoints
                : [],
            maskRle: d.mask_rle || d.maskRle || null,
            maskBase64: d.mask_base64 || d.maskBase64 || "",
          }))
        : [];

      return res.json({
        ok: true,
        imageWidth: Number(fastApiResponse.image_width || fastApiResponse.imageWidth || 0),
        imageHeight: Number(fastApiResponse.image_height || fastApiResponse.imageHeight || 0),
        detections,
        objects,
      });
    } catch (e) {
      console.error(e);
      return sendHttpError(res, e, "Failed to run combined YOLO+SAM inference");
    }
  },
);

app.post("/api/public/events/theme-design/yolo-sam-infer", async (req, res) => {
  try {
    const { imageBase64, confidenceThreshold, maxDetections, maskFormat } = req.body || {};
    const cleanedImageBase64 = sanitizeBase64Image(imageBase64);
    const fastApiResponse = await callFastApiWithTimeoutRetry({
      req,
      routePath: "/v1/infer/yolo-sam",
      timeoutMs: AI_SERVICE_TIMEOUT_SEGMENT_MS,
      timeoutRetries: AI_SERVICE_SEGMENT_TIMEOUT_RETRIES,
      payload: {
        image_base64: cleanedImageBase64,
        confidence_threshold: Number.isFinite(Number(confidenceThreshold))
          ? Number(confidenceThreshold)
          : 0.25,
        max_detections: Number.isFinite(Number(maxDetections)) ? Number(maxDetections) : 30,
        mask_format: ["polygon", "rle", "alpha_png"].includes(String(maskFormat))
          ? String(maskFormat)
          : "polygon",
      },
    });

    const detections = normalizeDetections(
      (fastApiResponse.detections || []).map((d, index) => ({
        classId: d.id || d.classId || d.class_id || `det_${index}`,
        className: d.label || d.className || d.class_name || "Object",
        confidence: d.confidence,
        boundingBox: {
          left: Number(d.box?.x ?? d.box?.left ?? 0),
          top: Number(d.box?.y ?? d.box?.top ?? 0),
          width: Number(d.box?.width ?? 0),
          height: Number(d.box?.height ?? 0),
        },
      })),
    );

    const objects = Array.isArray(fastApiResponse.objects)
      ? fastApiResponse.objects.map((d, index) => ({
          id: String(d.id || d.object_id || `sam_${index}`),
          label: String(d.label || "Object"),
          score: Number(d.score || 0),
          boundingBox: {
            left: Number(d.box?.x ?? d.box?.left ?? detections[index]?.boundingBox?.left ?? 0),
            top: Number(d.box?.y ?? d.box?.top ?? detections[index]?.boundingBox?.top ?? 0),
            width: Number(d.box?.width ?? detections[index]?.boundingBox?.width ?? 0),
            height: Number(d.box?.height ?? detections[index]?.boundingBox?.height ?? 0),
          },
          polygonPoints: Array.isArray(d.polygon_points)
            ? d.polygon_points
            : Array.isArray(d.polygonPoints)
              ? d.polygonPoints
              : [],
          maskRle: d.mask_rle || d.maskRle || null,
          maskBase64: d.mask_base64 || d.maskBase64 || "",
        }))
      : [];

    return res.json({
      ok: true,
      imageWidth: Number(fastApiResponse.image_width || fastApiResponse.imageWidth || 0),
      imageHeight: Number(fastApiResponse.image_height || fastApiResponse.imageHeight || 0),
      detections,
      objects,
    });
  } catch (e) {
    console.error(e);
    return sendHttpError(res, e, "Failed to run combined public YOLO+SAM inference");
  }
});

app.post("/api/public/events/theme-design/swap-colors", async (req, res) => {
  try {
    const { imageBase64, masks, edits, currentTintColorHex } = req.body || {};
    const cleanedImageBase64 = sanitizeBase64Image(imageBase64);
    if (!Array.isArray(masks) || masks.length === 0) {
      throw toHttpError("masks is required", 400, "invalid_masks");
    }
    if (!Array.isArray(edits) || edits.length === 0) {
      throw toHttpError("edits is required", 400, "invalid_edits");
    }

    const normalizedEdits = edits
      .filter((e) => e && typeof e === "object")
      .map((e) => ({
        object_id: String(e.objectId || e.object_id || ""),
        target_hex: ensureHexColor(e.targetHex || e.target_hex || currentTintColorHex),
        intensity: Number(e.intensity ?? 1),
      }))
      .filter((e) => e.object_id);
    if (!normalizedEdits.length) {
      throw toHttpError("No valid edits provided", 400, "invalid_edits");
    }

    const normalizedMasks = masks
      .filter((m) => m && typeof m === "object")
      .map((m) => ({
        object_id: String(m.objectId || m.object_id || ""),
        polygon_points: Array.isArray(m.polygonPoints)
          ? m.polygonPoints
          : Array.isArray(m.polygon_points)
            ? m.polygon_points
            : undefined,
        mask_rle: m.maskRle || m.mask_rle || undefined,
        mask_base64: m.maskBase64 || m.mask_base64 || undefined,
      }))
      .filter((m) => m.object_id);
    if (!normalizedMasks.length) {
      throw toHttpError("No valid masks provided", 400, "invalid_masks");
    }

    const fastApiResponse = await callFastApi({
      req,
      routePath: "/v1/edit/recolor",
      timeoutMs: AI_SERVICE_TIMEOUT_RECOLOR_MS,
      payload: {
        image_base64: cleanedImageBase64,
        masks: normalizedMasks,
        edits: normalizedEdits,
      },
    });

    const applied = Array.isArray(fastApiResponse.applied)
      ? fastApiResponse.applied.map((row) => ({
          objectId: String(row.object_id || row.objectId || ""),
          targetHex: ensureHexColor(row.target_hex || row.targetHex || currentTintColorHex),
        }))
      : [];
    const skipped = Array.isArray(fastApiResponse.skipped)
      ? fastApiResponse.skipped.map((row) => ({
          objectId: String(row.object_id || row.objectId || ""),
          reason: String(row.reason || "Skipped by AI service"),
        }))
      : [];

    return res.json({
      ok: true,
      imageBase64: String(fastApiResponse.image_base64 || fastApiResponse.imageBase64 || ""),
      applied,
      skipped,
    });
  } catch (e) {
    console.error(e);
    return sendHttpError(res, e, "Failed to process public theme color");
  }
});

app.post("/api/public/events/theme-design/theme-search", async (req, res) => {
  const fallbackThemeSuggestions = getFallbackThemeSuggestions(req.body?.eventType);
  try {
    const { eventTitle, eventType, formalityLevel, prompt, baseImageUrl, tags, page, perPage } = req.body || {};
    const pageNum = Math.max(1, Number(page) || 1);
    const sizeNum = Math.max(1, Math.min(24, Number(perPage) || 12));
    const queryCandidates = buildPromptLedPexelsQueries({
      eventTitle,
      eventType,
      formalityLevel,
      prompt,
      baseImageUrl,
      tags,
    });
    const query = queryCandidates[0] || '';
    if (!query.trim()) {
      throw toHttpError("prompt is required", 400, "invalid_prompt");
    }

    let images = [];
    let error = "";
    let rateLimited = false;
    const seen = new Set();
    
    // Parallelize all Pexels API calls for better performance
    const pexelsPromises = [];
    for (const q of queryCandidates) {
      if (!q) continue;
      pexelsPromises.push(fetchPexelsImages({ query: q, perPage: 30, page: 1 }));
      pexelsPromises.push(fetchPexelsImages({ query: q, perPage: 30, page: 2 }));
    }
    
    const pexelsResults = await Promise.allSettled(pexelsPromises);
    for (const result of pexelsResults) {
      if (result.status === 'fulfilled') {
        const { images: resultImages, error: resultError, rateLimited: resultRateLimited } = result.value;
        for (const row of resultImages || []) {
          const key = String(row.imageUrl || "");
          if (!key || seen.has(key)) continue;
          seen.add(key);
          images.push(row);
        }
        if (resultError) error = resultError;
        if (resultRateLimited) rateLimited = resultRateLimited;
      }
      if (images.length >= 36 || rateLimited) break;
    }

    let safeImages = sanitizeThemeSuggestions(images);
    if (safeImages.length) {
      safeImages = await removePersonImagesViaAi(req, safeImages, { maxChecks: 12 });
    }
    safeImages = safeImages.slice(0, 48);
    const safeFallback = sanitizeThemeSuggestions(fallbackThemeSuggestions);
    const source = safeImages.length ? safeImages : safeFallback;
    const total = source.length;
    const start = (pageNum - 1) * sizeNum;
    const paged = source.slice(start, start + sizeNum);
    const hasMore = start + sizeNum < total;
    return res.json({
      ok: true,
      query,
      usedFallback: safeImages.length === 0,
      error: safeImages.length === 0 && error ? error : undefined,
      images: paged,
      page: pageNum,
      perPage: sizeNum,
      total,
      hasMore,
    });
  } catch (e) {
    console.error(e);
    return res.json({
      ok: true,
      usedFallback: true,
      images: fallbackThemeSuggestions,
      error: String(e.message || "search_failed"),
    });
  }
});

app.post("/api/public/events/theme-design/add-by-prompt", async (req, res) => {
  try {
    const {
      baseImageBase64,
      eventTitle,
      eventType,
      formalityLevel,
      prompt,
      baseImageUrl,
    } = req.body || {};
    const cleanedBase = sanitizeBase64Image(baseImageBase64);
    const userPrompt = String(prompt || "").trim();
    if (!userPrompt) {
      throw toHttpError("prompt is required", 400, "invalid_prompt");
    }
    const baseQuery = buildPexelsQuery({
      eventTitle,
      eventType,
      formalityLevel,
      prompt: userPrompt,
      baseImageUrl,
      forceNoPeople: true,
    });
    const pex = await fetchPexelsImages({ query: baseQuery, perPage: 30, page: 1 });
    const selected = sanitizeThemeSuggestions(pex.images || []).slice(0, 10);
    if (selected.length === 0) {
      return res.json({
        ok: true,
        usedFallback: true,
        error: pex.error || "No prompt images found.",
        imageBase64: "",
        placements: [],
      });
    }
    const imageDownloads = await Promise.all(
      selected.map(async (row) => {
        const url = String(row.imageUrl || "").trim();
        if (!url) return "";
        const r = await fetch(url, { method: "GET" });
        if (!r.ok) return "";
        const buf = Buffer.from(await r.arrayBuffer());
        return buf.toString("base64");
      }),
    );
    const imagesBase64 = imageDownloads.filter((b) => b);
    if (imagesBase64.length === 0) {
      throw toHttpError("Failed to load prompt source images", 502, "prompt_source_download_failed");
    }

    let occupied = [];
    try {
      const baseInfo = await callFastApiWithTimeoutRetry({
        req,
        routePath: "/v1/infer/yolo-sam",
        timeoutMs: AI_SERVICE_TIMEOUT_ADD_BY_PROMPT_MS,
        timeoutRetries: AI_SERVICE_SEGMENT_TIMEOUT_RETRIES,
        payload: {
          image_base64: cleanedBase,
          confidence_threshold: 0.35,
          max_detections: 20,
          mask_format: "polygon",
        },
      });
      occupied = (Array.isArray(baseInfo?.objects) ? baseInfo.objects : []).map((obj) => ({
        left: Number(obj.box?.x ?? obj.box?.left ?? 0),
        top: Number(obj.box?.y ?? obj.box?.top ?? 0),
        width: Number(obj.box?.width ?? 0),
        height: Number(obj.box?.height ?? 0),
        label: String(obj.label || "Object"),
      }));
    } catch (baseErr) {
      console.warn("add-by-prompt: base analyze failed, using grid fallback:", baseErr);
      occupied = [];
    }
    const freeSpaces = [];
    const grid = 3;
    for (let row = 0; row < grid; row += 1) {
      for (let col = 0; col < grid; col += 1) {
        const left = col / grid;
        const top = row / grid;
        const width = 1 / grid;
        const height = 1 / grid;
        const overlaps = occupied.some((box) => {
          const xOverlap = Math.max(0, Math.min(left + width, box.left + box.width) - Math.max(left, box.left));
          const yOverlap = Math.max(0, Math.min(top + height, box.top + box.height) - Math.max(top, box.top));
          return xOverlap * yOverlap > 0.02;
        });
        if (!overlaps) freeSpaces.push({ left, top, width, height });
      }
    }

    const extractedGroups = [];
    for (let i = 0; i < imagesBase64.length; i += 1) {
      try {
        const fastApiResponse = await callFastApi({
          req,
          routePath: "/v1/infer/yolo-sam-extract",
          timeoutMs: AI_SERVICE_TIMEOUT_ADD_BY_PROMPT_MS,
          payload: {
            image_base64: imagesBase64[i],
            confidence_threshold: 0.35,
            max_detections: 10,
            mask_format: "alpha_png",
          },
        });
        const objects = Array.isArray(fastApiResponse.objects)
          ? fastApiResponse.objects.map((obj, idx) => ({
              id: String(obj.id || obj.object_id || `obj_${i}_${idx}`),
              label: String(obj.label || "Object"),
              objectImageBase64: String(obj.object_image_base64 || obj.objectImageBase64 || ""),
            }))
          : [];
        extractedGroups.push(...objects.filter((o) => o.objectImageBase64));
      } catch (extractErr) {
        console.warn(`add-by-prompt: extraction failed for source ${i}:`, extractErr);
      }
    }
    let usedSourceImageFallback = false;
    if (extractedGroups.length === 0) {
      usedSourceImageFallback = true;
      for (let i = 0; i < Math.min(imagesBase64.length, 6); i += 1) {
        extractedGroups.push({
          id: `fallback_source_${i}`,
          label: "Source image",
          objectImageBase64: String(imagesBase64[i] || ""),
        });
      }
    }
    if (extractedGroups.length === 0) {
      throw toHttpError("No objects extracted from prompt sources", 422, "no_prompt_objects_extracted");
    }
    const placements = extractedGroups.map((obj, idx) => {
      const slot = freeSpaces[idx % Math.max(1, freeSpaces.length)] || {
        left: 0.1 + ((idx % 3) * 0.25),
        top: 0.2 + ((idx % 2) * 0.25),
        width: 0.25,
        height: 0.25,
      };
      return {
        objectImageBase64: obj.objectImageBase64,
        x: Number(slot.left || 0),
        y: Number(slot.top || 0),
        width: Number(slot.width || 0.25),
        height: Number(slot.height || 0.25),
        rotation: 0,
        zIndex: idx,
        intensity: 1.0,
        targetHex: null,
      };
    });

    const composeResp = await callFastApi({
      req,
      routePath: "/v1/edit/compose",
      timeoutMs: AI_SERVICE_TIMEOUT_COMPOSE_MS,
      payload: {
        base_image_base64: cleanedBase,
        objects: placements.map((o) => ({
          object_image_base64: o.objectImageBase64,
          x: o.x,
          y: o.y,
          width: o.width,
          height: o.height,
          rotation: o.rotation,
          z_index: o.zIndex,
          intensity: o.intensity,
          target_hex: o.targetHex,
        })),
      },
    });

    return res.json({
      ok: true,
      imageBase64: String(composeResp.image_base64 || composeResp.imageBase64 || ""),
      placements,
      images: selected,
      usedSourceImageFallback,
    });
  } catch (e) {
    console.error(e);
    return sendHttpError(res, e, "Failed to add objects from prompt");
  }
});

app.post("/api/public/events/theme-design/extract-objects", async (req, res) => {
  try {
    const { imagesBase64, confidenceThreshold, maxDetections } = req.body || {};
    if (!Array.isArray(imagesBase64) || imagesBase64.length === 0) {
      throw toHttpError("imagesBase64 is required", 400, "invalid_images");
    }

    // Process images sequentially to avoid OOM
    const extractionResults = [];
    for (let i = 0; i < imagesBase64.length; i += 1) {
      try {
        const sanitizedBase64 = sanitizeBase64Image(imagesBase64[i]);
        const fastApiResponse = await callFastApi({
          req,
          routePath: "/v1/infer/yolo-sam-extract",
          timeoutMs: AI_SERVICE_TIMEOUT_SEGMENT_MS,
          payload: {
            image_base64: sanitizedBase64,
            confidence_threshold: Number.isFinite(Number(confidenceThreshold))
                ? Number(confidenceThreshold)
              : 0.35,
            max_detections: Number.isFinite(Number(maxDetections)) ? Math.min(Number(maxDetections), 10) : 10,
            mask_format: "alpha_png",
          },
        });
        const objects = Array.isArray(fastApiResponse.objects)
          ? fastApiResponse.objects.map((obj, idx) => ({
              id: String(obj.id || obj.object_id || `obj_${i}_${idx}`),
              label: String(obj.label || "Object"),
              score: Number(obj.score || 0),
              sourceImageIndex: i,
              boundingBox: {
                left: Number(obj.box?.x ?? obj.box?.left ?? 0),
                top: Number(obj.box?.y ?? obj.box?.top ?? 0),
                width: Number(obj.box?.width ?? 0),
                height: Number(obj.box?.height ?? 0),
              },
              polygonPoints: normalizePolygonPoints(obj.polygon_points || obj.polygonPoints || []),
              maskBase64: String(obj.mask_base64 || obj.maskBase64 || ""),
              objectImageBase64: String(obj.object_image_base64 || obj.objectImageBase64 || ""),
            }))
          : [];
        extractionResults.push({
          imageIndex: i,
          imageWidth: Number(fastApiResponse.image_width || fastApiResponse.imageWidth || 0),
          imageHeight: Number(fastApiResponse.image_height || fastApiResponse.imageHeight || 0),
          objects,
        });
      } catch (err) {
        const msg =
          err && typeof err === "object" && "message" in err && typeof err.message === "string"
              ? err.message
              : String(err || "unknown");
        console.warn(`extract-objects: failed for image ${i}:`, msg);
        extractionResults.push({
          imageIndex: i,
          imageWidth: 0,
          imageHeight: 0,
          objects: [],
        });
      }
    }
    return res.json({ ok: true, images: extractionResults });
  } catch (e) {
    console.error(e);
    return sendHttpError(res, e, "Failed to extract theme objects");
  }
});

app.post("/api/public/events/theme-design/analyze-base", async (req, res) => {
  try {
    const { baseImageBase64 } = req.body || {};
    const cleaned = sanitizeBase64Image(baseImageBase64);
    let objects = [];
    try {
      const fastApiResponse = await callFastApiWithTimeoutRetry({
        req,
        routePath: "/v1/infer/yolo-sam",
        timeoutMs: AI_SERVICE_TIMEOUT_SEGMENT_MS,
        timeoutRetries: AI_SERVICE_SEGMENT_TIMEOUT_RETRIES,
        payload: {
          image_base64: cleaned,
          confidence_threshold: 0.25,
          max_detections: 20,
          mask_format: "polygon",
        },
      });
      objects = Array.isArray(fastApiResponse.objects) ? fastApiResponse.objects : [];
    } catch (err) {
      console.warn("[analyze-base] YOLO/SAM unavailable, using generic free-space fallback.");
    }
    const occupied = objects.map((obj) => ({
      left: Number(obj.box?.x ?? obj.box?.left ?? 0),
      top: Number(obj.box?.y ?? obj.box?.top ?? 0),
      width: Number(obj.box?.width ?? 0),
      height: Number(obj.box?.height ?? 0),
      label: String(obj.label || "Object"),
    }));
    const cells = [];
    const grid = 3;
    for (let row = 0; row < grid; row += 1) {
      for (let col = 0; col < grid; col += 1) {
        const left = col / grid;
        const top = row / grid;
        const width = 1 / grid;
        const height = 1 / grid;
        const overlaps = occupied.some((box) => {
          const xOverlap = Math.max(0, Math.min(left + width, box.left + box.width) - Math.max(left, box.left));
          const yOverlap = Math.max(0, Math.min(top + height, box.top + box.height) - Math.max(top, box.top));
          return xOverlap * yOverlap > 0.02;
        });
        if (!overlaps) cells.push({ left, top, width, height });
      }
    }
    const recommendations = occupied.some((o) => /table|desk|counter|buffet/i.test(o.label))
      ? ["flowers", "fruit platter", "plates", "napkins"]
      : ["flowers", "lights", "decorative elements", "table setup"];
    return res.json({ ok: true, freeSpaces: cells, recommendations });
  } catch (e) {
    console.error(e);
    return sendHttpError(res, e, "Failed to analyze base image");
  }
});

app.post("/api/public/events/theme-design/auto-place", async (req, res) => {
  try {
    const { freeSpaces, objects } = req.body || {};
    const spaces = Array.isArray(freeSpaces) ? freeSpaces : [];
    const sourceObjects = Array.isArray(objects) ? objects : [];
    const placements = sourceObjects.map((obj, idx) => {
      const slot = spaces[idx % Math.max(1, spaces.length)] || {
        left: 0.1 + ((idx % 3) * 0.25),
        top: 0.2 + ((idx % 2) * 0.25),
        width: 0.25,
        height: 0.25,
      };
      return {
        objectId: String(obj.id || `obj_${idx}`),
        x: Number(slot.left || 0),
        y: Number(slot.top || 0),
        width: Number(slot.width || 0.25),
        height: Number(slot.height || 0.25),
        rotation: 0,
        zIndex: idx,
        confidence: 0.72,
        reason: "Placed in low-occupancy region",
      };
    });
    return res.json({ ok: true, placements });
  } catch (e) {
    console.error(e);
    return sendHttpError(res, e, "Failed to auto-place objects");
  }
});

app.post("/api/public/events/theme-design/render-composite", async (req, res) => {
  try {
    const { baseImageBase64, objects } = req.body || {};
    const cleanedBase = sanitizeBase64Image(baseImageBase64);
    const normalizedObjects = (Array.isArray(objects) ? objects : [])
      .filter((obj) => obj && typeof obj === "object")
      .map((obj, idx) => {
        const xRaw = Number(obj.x ?? 0);
        const yRaw = Number(obj.y ?? 0);
        const widthRaw = Number(obj.width ?? 120);
        const heightRaw = Number(obj.height ?? 120);
        const rotationRaw = Number(obj.rotation ?? 0);
        const intensityRaw = Number(obj.intensity ?? 1);
        const zIndexRaw = Number(obj.zIndex ?? obj.z_index ?? idx);

        const x = Number.isFinite(xRaw) ? xRaw : 0;
        const y = Number.isFinite(yRaw) ? yRaw : 0;
        const width = Number.isFinite(widthRaw) && widthRaw > 1 ? widthRaw : 120;
        const height = Number.isFinite(heightRaw) && heightRaw > 1 ? heightRaw : 120;
        const rotation = Number.isFinite(rotationRaw) ? rotationRaw : 0;
        const zIndex = Number.isFinite(zIndexRaw) ? zIndexRaw : idx;
        const intensity = Number.isFinite(intensityRaw)
          ? Math.max(0, Math.min(1, intensityRaw))
          : 1;

        return {
          object_image_base64: String(obj.objectImageBase64 || obj.object_image_base64 || ""),
          x,
          y,
          width,
          height,
          rotation,
          z_index: zIndex,
          target_hex: obj.targetHex ? ensureHexColor(obj.targetHex) : null,
          intensity,
        };
      })
      .filter((obj) => obj.object_image_base64);

    const fastApiResponse = await callFastApi({
      req,
      routePath: "/v1/edit/compose",
      timeoutMs: AI_SERVICE_TIMEOUT_COMPOSE_MS,
      payload: {
        base_image_base64: cleanedBase,
        objects: normalizedObjects,
      },
    });
    return res.json({
      ok: true,
      imageBase64: String(fastApiResponse.image_base64 || fastApiResponse.imageBase64 || ""),
    });
  } catch (e) {
    console.error(e);
    return sendHttpError(res, e, "Failed to render composite");
  }
});

const DEFAULT_EVENT_DESIGN_CATEGORIES = {
  styles: ["Elegant", "Rustic", "Modern", "Garden", "Minimalist", "Vintage", "Bohemian", "Other"],
  moods: ["Romantic", "Bright", "Dramatic", "Cozy", "Luxurious", "Fun", "Other"],
  palettes: ["White & Gold", "Pastel Pink", "Earthy Green", "Navy & Silver", "Peach & Cream", "Black & White", "Other"],
  decor: ["Floral Centerpieces", "Fairy Lights", "Stage Backdrop", "Balloon Setup", "Drapery & Curtains", "Table Runners", "Photo Booth", "Chandeliers", "Other"],
};

async function ensureEventDesignCategoryOptions() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS event_design_category_options (
      id TEXT PRIMARY KEY DEFAULT 'default',
      categories JSONB NOT NULL DEFAULT '{}'::jsonb,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
  await pool.query(
    `INSERT INTO event_design_category_options (id, categories)
     VALUES ('default', $1::jsonb)
     ON CONFLICT (id) DO NOTHING`,
    [JSON.stringify(DEFAULT_EVENT_DESIGN_CATEGORIES)],
  );
}

app.get("/api/mobile/event-design/categories", async (_req, res) => {
  try {
    await ensureEventDesignCategoryOptions();
    const result = await pool.query(
      `SELECT categories FROM event_design_category_options WHERE id = 'default' LIMIT 1`,
    );
    return res.json(result.rows[0]?.categories || DEFAULT_EVENT_DESIGN_CATEGORIES);
  } catch (e) {
    console.error("[event design categories] load failed", e);
    return res.status(500).json({ error: "Failed to load event design categories" });
  }
});

app.put(
  "/api/mobile/event-design/categories",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["admin", "super_admin"])),
  async (req, res) => {
    try {
      await ensureEventDesignCategoryOptions();
      const categories =
        req.body?.categories && typeof req.body.categories === "object"
          ? req.body.categories
          : DEFAULT_EVENT_DESIGN_CATEGORIES;
      await pool.query(
        `INSERT INTO event_design_category_options (id, categories, updated_at)
         VALUES ('default', $1::jsonb, now())
         ON CONFLICT (id) DO UPDATE
         SET categories = EXCLUDED.categories, updated_at = now()`,
        [JSON.stringify(categories)],
      );
      return res.json({ ok: true, categories });
    } catch (e) {
      console.error("[event design categories] save failed", e);
      return res.status(500).json({ error: "Failed to save event design categories" });
    }
  },
);

app.get("/api/mobile/ai-generations", async (req, res) => {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS ai_generations (
        id BIGSERIAL PRIMARY KEY,
        user_id UUID,
        user_email TEXT NOT NULL DEFAULT '',
        image_url TEXT NOT NULL DEFAULT '',
        prompt TEXT NOT NULL DEFAULT '',
        negative_prompt TEXT,
        design_meta JSONB NOT NULL DEFAULT '{}'::jsonb,
        job_id TEXT,
        seed BIGINT,
        generation_mode TEXT,
        event_type TEXT,
        style TEXT,
        mood TEXT,
        formality TEXT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);
    await pool.query(`
      ALTER TABLE ai_generations
      ADD COLUMN IF NOT EXISTS user_id UUID,
      ADD COLUMN IF NOT EXISTS negative_prompt TEXT,
      ADD COLUMN IF NOT EXISTS seed BIGINT,
      ADD COLUMN IF NOT EXISTS generation_mode TEXT,
      ADD COLUMN IF NOT EXISTS event_type TEXT,
      ADD COLUMN IF NOT EXISTS style TEXT,
      ADD COLUMN IF NOT EXISTS mood TEXT,
      ADD COLUMN IF NOT EXISTS formality TEXT
    `);
    const email = String(req.query.email || req.query.userEmail || "").trim().toLowerCase();
    const params = [];
    let where = "";
    if (email) {
      params.push(email);
      where = "WHERE lower(trim(user_email)) = $1";
    }
    const result = await pool.query(
      `SELECT id::text, image_url, prompt, design_meta, job_id, created_at
       FROM ai_generations
       ${where}
       ORDER BY created_at DESC
       LIMIT 24`,
      params,
    );
    return res.json({ generations: result.rows });
  } catch (e) {
    console.error("[ai generations] load failed", e);
    return res.status(500).json({ error: "Failed to load AI generations" });
  }
});

app.get(
  "/api/manager/events/orders",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "admin", "super_admin"])),
  async (req, res) => {
    try {
      await ensureOrderCateringIdColumns();
      await ensureCateringEventOrdersCanonicalColumns();
      const { status } = req.query || {};
      if (!status)
        return res
          .status(400)
          .json({ message: "status query param is required" });

      const compact = String(req.query.compact || "") === "1";
      const cateringCols = await getTableColumnNames('catering_orders');
      const eventCols = await getTableColumnNames('event_orders');
      const listSql = buildStaffEventsOrdersListSql(cateringCols, eventCols, {
        compact,
      });

      const result = await pool.query(listSql, [status]);

      let orders = await Promise.all(
        result.rows.map((row) => normalizeStaffEventOrderRow(row)),
      );
      if (compact) {
        orders = orders.map(compactEventOrderRow);
      }
      return res.json({ orders });
    } catch (e) {
      console.error("GET /api/manager/events/orders", e);
      return res.status(500).json({ message: "Failed to load orders" });
    }
  },
);

app.get(
  "/api/manager/events/orders/:orderId",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "admin", "super_admin"])),
  async (req, res) => {
    try {
      const row = await fetchEventOrderRowById(req.params.orderId);
      if (!row) {
        return res.status(404).json({ message: "Order not found" });
      }
      return res.json({ order: row });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: "Failed to load order" });
    }
  },
);

app.post(
  "/api/manager/events/orders/:orderId/finalize",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "admin", "super_admin"])),
  async (req, res) => {
    try {
      const { orderId } = req.params;
      const {
        eventTitle,
        eventType,
        formalityLevel,
        customerName,
        contactPerson,
        contactNumber,
        emailAddress,
        scheduleSlots,
        address,
        guestCount,
        menu,
        themeDesign,
        totalCost,
        action = 'confirm_inquiry',
      } = req.body || {};

      const normalizedAction = String(action || '').toLowerCase();
      const isPostChanges = normalizedAction === 'post_changes';
      const isCancelEvent = normalizedAction === 'cancel_event';
      const nextStatus = isPostChanges ? 'online_inquiries' : 'for_down_payment';

      if (!['post_changes', 'confirm_inquiry', 'cancel_event'].includes(normalizedAction)) {
        return res.status(400).json({ message: "Invalid finalize action" });
      }

      if (isCancelEvent) {
        // Keep cancel behavior consistent with shared cancel endpoint.
        let cancelResult = await pool.query(
          `UPDATE event_orders
           SET
             status = 'cancelled',
             updated_by = $1,
             updated_at = now()
           WHERE id = $2
             AND source = 'online_inquiry'
             AND status = 'online_inquiries'
           RETURNING id;`,
          [req.user.id, orderId],
        );

        if (cancelResult.rowCount === 0) {
          cancelResult = await pool.query(
            `UPDATE catering_orders
             SET
               status = 'cancelled',
               updated_by = $1,
               updated_at = now()
             WHERE id = $2
               AND source = 'online_inquiry'
               AND status = 'online_inquiries'
             RETURNING id;`,
            [req.user.id, orderId],
          );
        }

        if (cancelResult.rowCount === 0) {
          return res
            .status(404)
            .json({ message: "Online inquiry not found or not cancellable" });
        }

        await logAction({
          userId: req.user.id,
          feature: "Events",
          action: "cancelled online inquiry",
          other: { orderId },
        });

        return res.json({ ok: true, id: cancelResult.rows[0].id });
      }

      let sourceTable = 'event_orders';
      let existingOrderResult = await pool.query(
        `SELECT
           event_title AS "eventTitle",
           event_type AS "eventType",
           formality_level AS "formalityLevel",
           customer_name AS "customerName",
           contact_person AS "contactPerson",
           contact_number AS "contactNumber",
           email_address AS "emailAddress",
           schedule_slots AS "scheduleSlots",
           address,
           guest_count AS "guestCount",
           menu,
           theme_design AS "themeDesign",
           total_cost AS "totalCost"
         FROM event_orders
         WHERE id = $1
           AND source = 'online_inquiry'
           AND status = 'online_inquiries'
         LIMIT 1;`,
        [orderId],
      );

      if (existingOrderResult.rowCount === 0) {
        sourceTable = 'catering_orders';
        const catCols = await getTableColumnNames('catering_orders');
        const catThemeSel = catCols.has('theme_design')
          ? 'theme_design AS "themeDesign"'
          : "'{}'::jsonb AS \"themeDesign\"";
        existingOrderResult = await pool.query(
          `SELECT
             null AS "eventTitle",
             null AS "eventType",
             null AS "formalityLevel",
             customer_name AS "customerName",
             contact_person AS "contactPerson",
             contact_number AS "contactNumber",
             email_address AS "emailAddress",
             schedule_slots AS "scheduleSlots",
             address,
             guest_count AS "guestCount",
             menu,
             total_cost AS "totalCost",
             ${catThemeSel}
           FROM catering_orders
           WHERE id = $1
             AND source = 'online_inquiry'
             AND status = 'online_inquiries'
           LIMIT 1;`,
          [orderId],
        );
      }

      if (existingOrderResult.rowCount === 0) {
        return res
          .status(404)
          .json({ message: "Online inquiry not found or not finalizable" });
      }

      const existing = existingOrderResult.rows[0];
      const changedFields = [];
      const addChanged = (key, oldValue, newValue) => {
        if (JSON.stringify(oldValue ?? null) !== JSON.stringify(newValue ?? null)) {
          changedFields.push(key);
        }
      };
      addChanged('eventTitle', existing.eventTitle, eventTitle);
      addChanged('eventType', existing.eventType, eventType);
      addChanged('formalityLevel', existing.formalityLevel, formalityLevel);
      addChanged('customerName', existing.customerName, customerName);
      addChanged('contactPerson', existing.contactPerson, contactPerson);
      addChanged('contactNumber', existing.contactNumber, contactNumber);
      addChanged('emailAddress', existing.emailAddress, emailAddress);
      addChanged('scheduleSlots', existing.scheduleSlots, scheduleSlots || []);
      addChanged('address', existing.address, address);
      addChanged('guestCount', existing.guestCount, Number(guestCount));
      addChanged('menu', existing.menu, menu || []);
      addChanged('themeDesign', existing.themeDesign, themeDesign || {});
      addChanged('totalCost', Number(existing.totalCost || 0), Number(totalCost || 0));

      const costBreakdown =
        themeDesign?.costBreakdown && typeof themeDesign.costBreakdown === "object"
          ? themeDesign.costBreakdown
          : {};
      const laborCost = Number(
        req.body.laborCost ?? costBreakdown.laborCost ?? costBreakdown.labor_cost ?? 0,
      );
      const travelCost = Number(
        req.body.travelCost ?? costBreakdown.travelCost ?? costBreakdown.travel_cost ?? 0,
      );
      const dishCost = Number(
        costBreakdown.dishCost ?? costBreakdown.dish_cost ?? 0,
      );
      const totalNum = totalCost != null ? Number(totalCost) : 0;
      const estimateMessage =
        `Macrina posted an updated cost estimate: PHP ${totalNum.toFixed(2)} ` +
        `(labor PHP ${laborCost.toFixed(2)}, travel PHP ${travelCost.toFixed(2)}).`;

      const priorTheme =
        existing.themeDesign && typeof existing.themeDesign === 'object'
          ? existing.themeDesign
          : {};

      const mergedThemeDesign = {
        ...priorTheme,
        ...(themeDesign || {}),
        costBreakdown: {
          dishCost,
          laborCost,
          travelCost,
        },
        laborCost,
        travelCost,
        managerUpdateNotice: {
          action: normalizedAction,
          preferencesChanged: isPostChanges || changedFields.length > 0,
          estimateUpdated: isPostChanges,
          message: isPostChanges
            ? estimateMessage
            : changedFields.length > 0
              ? 'Macrina updated your inquiry details. Please review in My Caterings.'
              : undefined,
          changedFields,
          postedAt: new Date().toISOString(),
        },
      };

      const tableCols = await getTableColumnNames(sourceTable);
      const laborSql = tableCols.has("labor_cost") ? ", labor_cost = $17" : "";
      const travelSql = tableCols.has("travel_cost") ? ", travel_cost = $18" : "";

      const result = sourceTable === 'event_orders'
        ? await pool.query(
            `UPDATE event_orders
             SET
               event_title = $1,
               event_type = $2,
               formality_level = $3,
               customer_name = $4,
               contact_person = $5,
               contact_number = $6,
               email_address = $7,
               schedule_slots = $8,
               address = $9,
               guest_count = $10,
               menu = $11,
               theme_design = $12,
               status = $13,
               total_cost = $14,
               updated_by = $15,
               updated_at = now()${laborSql}${travelSql}
             WHERE id = $16
               AND source = 'online_inquiry'
               AND status = 'online_inquiries'
             RETURNING id;`,
            [
              eventTitle,
              eventType,
              formalityLevel,
              customerName,
              contactPerson,
              contactNumber,
              emailAddress,
              JSON.stringify(scheduleSlots || []),
              address,
              Number(guestCount),
              JSON.stringify(menu || []),
              JSON.stringify(mergedThemeDesign),
              nextStatus,
              totalCost != null ? Number(totalCost) : 0,
              req.user.id,
              orderId,
              ...(tableCols.has("labor_cost") ? [laborCost] : []),
              ...(tableCols.has("travel_cost") ? [travelCost] : []),
            ],
          )
        : await (async () => {
            const catSets = [
              'customer_name = $1',
              'contact_person = $2',
              'contact_number = $3',
              'email_address = $4',
              'schedule_slots = $5',
              'address = $6',
              'guest_count = $7',
              'menu = $8',
            ];
            const catParams = [
              customerName,
              contactPerson,
              contactNumber,
              emailAddress,
              JSON.stringify(scheduleSlots || []),
              address,
              Number(guestCount),
              JSON.stringify(menu || []),
            ];
            let p = 9;
            if (tableCols.has('theme_design')) {
              catSets.push(`theme_design = $${p}`);
              catParams.push(JSON.stringify(mergedThemeDesign));
              p += 1;
            }
            catSets.push(`status = $${p}`);
            catParams.push(nextStatus);
            p += 1;
            catSets.push(`total_cost = $${p}`);
            catParams.push(totalCost != null ? Number(totalCost) : 0);
            p += 1;
            catSets.push(`updated_by = $${p}`);
            catParams.push(req.user.id);
            p += 1;
            catSets.push('updated_at = now()');
            if (tableCols.has('labor_cost')) {
              catSets.push(`labor_cost = $${p}`);
              catParams.push(laborCost);
              p += 1;
            }
            if (tableCols.has('travel_cost')) {
              catSets.push(`travel_cost = $${p}`);
              catParams.push(travelCost);
              p += 1;
            }
            catParams.push(orderId);
            return pool.query(
              `UPDATE catering_orders
               SET ${catSets.join(', ')}
               WHERE id = $${p}
                 AND source = 'online_inquiry'
                 AND status = 'online_inquiries'
               RETURNING id;`,
              catParams,
            );
          })();

      if (result.rowCount === 0) {
        return res
          .status(404)
          .json({ message: "Online inquiry not found or not finalizable" });
      }

      await logAction({
        userId: req.user.id,
        feature: "Events",
        action: isPostChanges
          ? "posted online inquiry changes"
          : "confirmed online inquiry",
        other: { orderId, changedFields },
      });

      const customerEmail = emailAddress || existing.emailAddress;
      const customerDisplayName = customerName || existing.customerName || "Customer";
      if (normalizedAction === "post_changes") {
        try {
          await sendCustomerNotificationEmail({
            to: customerEmail,
            subject: "Curatering: Your inquiry has a cost estimation update",
            text:
              `Hello ${customerDisplayName},\n\n` +
              `Your catering inquiry (${orderId}) has been updated with a revised cost estimation.\n` +
              `Estimated total: PHP ${Number(totalCost || 0).toFixed(2)}.\n` +
              `Labor: PHP ${laborCost.toFixed(2)} · Travel: PHP ${travelCost.toFixed(2)}.\n\n` +
              `Please review your inquiry details in Curatering.\n\n` +
              `- Curatering Team`,
          });
        } catch (mailError) {
          console.error('Finalize email failed (post_changes, non-fatal):', mailError);
        }
      } else if (normalizedAction === "confirm_inquiry") {
        try {
          await sendCustomerNotificationEmail({
            to: customerEmail,
            subject: "Curatering: Your inquiry is now for processing",
            text:
              `Hello ${customerDisplayName},\n\n` +
              `Your inquiry (${orderId}) has been accepted and moved to for downpayment.\n` +
              `When your booking includes an event, you can open the Curatering app, go to My Caterings, tap your booking, and review the Seating layout section (and adjust table layout while the event is in processing, if enabled).\n\n` +
              `- Curatering Team`,
          });
        } catch (mailError) {
          console.error('Finalize email failed (confirm_inquiry, non-fatal):', mailError);
        }
      }

      return res.json({ ok: true, id: result.rows[0].id });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: "Failed to finalize order" });
    }
  },
);

// Supervisor: list/update processing orders
app.get(
  "/api/supervisor/events/orders",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["supervisor", "admin", "super_admin"])),
  async (req, res) => {
    await ensureOrderCateringIdColumns();
    await ensureCateringEventOrdersCanonicalColumns();
    const { status } = req.query || {};
    if (!status)
      return res
        .status(400)
        .json({ message: "status query param is required" });

    const compact = String(req.query.compact || "") === "1";
    const cateringCols = await getTableColumnNames('catering_orders');
    const eventCols = await getTableColumnNames('event_orders');
    const listSql = buildStaffEventsOrdersListSql(cateringCols, eventCols, {
      compact,
    });

    const result = await pool.query(listSql, [status]);

    let orders = await Promise.all(
      result.rows.map((row) => normalizeStaffEventOrderRow(row)),
    );
    if (compact) {
      orders = orders.map(compactEventOrderRow);
    }
    return res.json({ orders });
  },
);

app.get(
  "/api/supervisor/events/orders/:orderId",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["supervisor", "admin", "super_admin"])),
  async (req, res) => {
    try {
      const row = await fetchEventOrderRowById(req.params.orderId);
      if (!row) {
        return res.status(404).json({ message: "Order not found" });
      }
      return res.json({ order: row });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: "Failed to load order" });
    }
  },
);

app.post(
  "/api/events/orders/:orderId/complete-post-analysis",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "supervisor", "admin"])),
  async (req, res) => {
    try {
      const { orderId } = req.params;
      const { businessCardsGivenAway, onTheSpotInquiries, complaints } =
        req.body || {};

      const postAnalysis = {
        businessCardsGivenAway: Number(businessCardsGivenAway) || 0,
        onTheSpotInquiries: Number(onTheSpotInquiries) || 0,
        complaints: Number(complaints) || 0,
      };

      const result = await pool.query(
        `UPDATE event_orders
         SET
           status = 'completed',
           post_analysis = $1::jsonb,
           updated_by = $2,
           updated_at = now()
         WHERE id = $3
           AND status IN ('for_full_payment', 'for_post_analysis')
         RETURNING id;`,
        [JSON.stringify(postAnalysis), req.user.id, orderId],
      );

      if (result.rowCount === 0) {
        return res
          .status(404)
          .json({
            message: "Post-analysis order not found or already completed",
          });
      }

      await logAction({
        userId: req.user.id,
        feature: "Events",
        action: "completed post-event analysis",
        other: { orderId, postAnalysis },
      });

      return res.json({ ok: true, id: result.rows[0].id });
    } catch (e) {
      console.error(e);
      return res
        .status(500)
        .json({ message: "Failed to complete post-analysis" });
    }
  },
);

app.post(
  "/api/supervisor/events/orders/:orderId",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["supervisor", "admin", "super_admin"])),
  async (req, res) => {
    try {
      const { orderId } = req.params;
      const {
        eventTitle,
        eventType,
        formalityLevel,
        customerName,
        contactPerson,
        contactNumber,
        emailAddress,
        scheduleSlots,
        address,
        guestCount,
        menu,
        themeDesign,
      } = req.body || {};

      const result = await pool.query(
        `UPDATE event_orders
         SET
           event_title = $1,
           event_type = $2,
           formality_level = $3,
           customer_name = $4,
           contact_person = $5,
           contact_number = $6,
           email_address = $7,
           schedule_slots = $8,
           address = $9,
           guest_count = $10,
           menu = $11,
           theme_design = $12,
           updated_by = $13,
           updated_at = now()
         WHERE id = $14
           AND status IN ('on_going', 'for_processing', 'for_down_payment')
         RETURNING id;`,
        [
          eventTitle,
          eventType,
          formalityLevel,
          customerName,
          contactPerson,
          contactNumber,
          emailAddress,
          JSON.stringify(scheduleSlots || []),
          address,
          Number(guestCount),
          JSON.stringify(menu || []),
          JSON.stringify(themeDesign || {}),
          req.user.id,
          orderId,
        ],
      );

      if (result.rowCount === 0) {
        return res.status(404).json({ message: "Processing order not found" });
      }

      await logAction({
        userId: req.user.id,
        feature: "Events",
        action: "updated for processing",
        other: { orderId },
      });

      return res.json({ ok: true, id: result.rows[0].id });
    } catch (e) {
      console.error(e);
      return res
        .status(500)
        .json({ message: "Failed to update processing order" });
    }
  },
);

// Public: customer submits online inquiries
app.post("/api/online-inquiries", async (req, res) => {
  try {
    const {
      orderType,
      eventTitle,
      eventType,
      formalityLevel,
      customerName,
      contactPerson,
      contactNumber,
      emailAddress,
      scheduleSlots,
      address,
      addressLat,
      addressLng,
      guestCount,
      paxBuffer,
      menu,
      allergens,
      inquiryType,
      serviceIncluded,
      eventCity,
      eventSetting,
      selectedSetMenu,
      menuModifications,
      estimatedTotal,
      costBreakdown,
      foodTastingRequested,
      foodTastingDate,
      foodTastingTime,
      menuSuggestionNote,
      curateOwnMenu,
      guestAllergens,
      themeDesign,
      source = 'web', // 'web' or 'mobile'
    } = req.body || {};
    const allergensText = String(guestAllergens ?? allergens ?? '').trim();
    const normalizedServiceIncluded = String(serviceIncluded ?? '').trim().toLowerCase() === 'yes' ? 'yes' : 'no';
    const normalizedMenuMods = Array.isArray(menuModifications)
      ? { additionalChargeRows: menuModifications }
      : menuModifications && typeof menuModifications === 'object'
        ? menuModifications
        : {};
    const normalizedCostBreakdown = Array.isArray(costBreakdown) ? costBreakdown : [];
    const slimTheme =
      themeDesign && typeof themeDesign === "object" && !Array.isArray(themeDesign)
        ? { ...themeDesign }
        : {};
    if (eventSetting) slimTheme.event_setting = String(eventSetting).trim();
    if (inquiryType) slimTheme.inquiry_type = String(inquiryType).trim();
    if (menuSuggestionNote) slimTheme.menu_suggestion_note = String(menuSuggestionNote).trim();
    if (curateOwnMenu !== undefined) slimTheme.curate_own_menu = Boolean(curateOwnMenu);
    if (normalizedCostBreakdown.length) slimTheme.cost_breakdown = normalizedCostBreakdown;
    if (Object.keys(normalizedMenuMods).length) slimTheme.menu_modifications = normalizedMenuMods;
    if (
      typeof slimTheme.venuePhotoBase64 === "string" &&
      slimTheme.venuePhotoBase64.length > 120_000
    ) {
      delete slimTheme.venuePhotoBase64;
      slimTheme.venuePhotoOmitted = true;
    }
    const themeDesignJson = JSON.stringify(slimTheme);

    const parseCoord = (v) => {
      if (v === undefined || v === null || v === "") return null;
      const n = Number(v);
      return Number.isFinite(n) ? n : null;
    };
    const resolvedAddressLat = parseCoord(addressLat);
    const resolvedAddressLng = parseCoord(addressLng);

    const isCateringOnly = orderType === 'catering';

    // Validate required fields
    if (
      !customerName ||
      !contactPerson ||
      !contactNumber ||
      !emailAddress ||
      !address ||
      guestCount === undefined ||
      !Array.isArray(scheduleSlots) ||
      !Array.isArray(menu)
    ) {
      return res.status(400).json({ message: "Missing required fields" });
    }

    // Only validate event-specific fields for catering+event
    if (!isCateringOnly) {
      if (!eventTitle || !eventType || !formalityLevel) {
        return res.status(400).json({ message: "Missing required event fields" });
      }
    }

    const cateringId = await allocateCateringTransactionId();

    let result;
    if (isCateringOnly) {
      // Use catering_orders table for catering-only orders
      result = await pool.query(
        `INSERT INTO catering_orders
          (source, status, order_type, catering_id, customer_name, contact_person, contact_number, email_address,
           schedule_slots, address, address_lat, address_lng, guest_count, pax_buffer, menu, allergens,
           event_city, event_setting, service_included, selected_set_menu, menu_modifications,
           cost_breakdown, food_tasting_requested, food_tasting_date, food_tasting_time,
           estimated_total, theme_design)
        VALUES
          ('online_inquiry', 'online_inquiries', 'catering', $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
           $11, $12, $13, $14, $15, $16, $17::jsonb, $18::jsonb, $19, $20, $21, $22, $23, $24::jsonb)
         RETURNING id, catering_id;`,
        [
          cateringId,
          customerName,
          contactPerson,
          contactNumber,
          emailAddress,
          JSON.stringify(scheduleSlots),
          address,
          resolvedAddressLat,
          resolvedAddressLng,
          Number(guestCount),
          Number(paxBuffer ?? 0) || 0,
          JSON.stringify(menu),
          allergensText,
          String(eventCity ?? '').trim(),
          String(eventSetting ?? '').trim(),
          normalizedServiceIncluded,
          String(selectedSetMenu ?? '').trim(),
          JSON.stringify(normalizedMenuMods),
          JSON.stringify(normalizedCostBreakdown),
          foodTastingRequested === true,
          String(foodTastingDate ?? '').trim(),
          String(foodTastingTime ?? '').trim(),
          Number(estimatedTotal ?? 0) || 0,
          themeDesignJson,
        ]
      );
    } else {
      // Use event_orders table for catering+event orders
      result = await pool.query(
        `INSERT INTO event_orders
          (source, status, event_title, order_type, event_type, formality_level, catering_id,
           customer_name, contact_person, contact_number, email_address,
           schedule_slots, address, address_lat, address_lng, guest_count, pax_buffer, menu, theme_design, allergens,
           event_city, event_setting, service_included, selected_set_menu, menu_modifications,
           cost_breakdown, food_tasting_requested, food_tasting_date, food_tasting_time,
           estimated_total)
         VALUES
          ('online_inquiry', 'online_inquiries',
           $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23::jsonb,$24::jsonb,$25,$26,$27,$28)
         RETURNING id, catering_id;`,
        [
          eventTitle,
          'catering_event',
          eventType,
          formalityLevel,
          cateringId,
          customerName,
          contactPerson,
          contactNumber,
          emailAddress,
          JSON.stringify(scheduleSlots),
          address,
          resolvedAddressLat,
          resolvedAddressLng,
          Number(guestCount),
          Number(paxBuffer ?? 0) || 0,
          JSON.stringify(menu),
          themeDesignJson,
          allergensText,
          String(eventCity ?? '').trim(),
          String(eventSetting ?? '').trim(),
          normalizedServiceIncluded,
          String(selectedSetMenu ?? '').trim(),
          JSON.stringify(normalizedMenuMods),
          JSON.stringify(normalizedCostBreakdown),
          foodTastingRequested === true,
          String(foodTastingDate ?? '').trim(),
          String(foodTastingTime ?? '').trim(),
          Number(estimatedTotal ?? 0) || 0,
        ]
      );
    }

    sendCustomerNotificationEmailAsync({
      to: emailAddress,
      subject: "Curatering: Inquiry received",
      text:
        `Hello ${customerName || "Customer"},\n\n` +
        `We received your inquiry (${result.rows[0].catering_id}).\n` +
        `Our team will review it and contact you soon.\n\n` +
        `- Curatering Team`,
    });

    return res.json({ ok: true, id: result.rows[0].id, cateringId: result.rows[0].catering_id });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ message: "Failed to create online inquiry" });
  }
});

app.put(
  "/api/events/orders/:orderId/theme-design",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "supervisor", "admin", "super_admin"])),
  async (req, res) => {
    try {
      const orderId = String(req.params.orderId || "").trim();
      const themeDesign = req.body?.themeDesign ?? req.body?.theme_design ?? {};
      if (!orderId) return res.status(400).json({ error: "orderId required" });
      if (!themeDesign || typeof themeDesign !== "object" || Array.isArray(themeDesign)) {
        return res.status(400).json({ error: "themeDesign must be an object" });
      }
      let result = await pool.query(
        `UPDATE event_orders
         SET theme_design = COALESCE(theme_design, '{}'::jsonb) || $1::jsonb,
             updated_at = now()
         WHERE id = $2
         RETURNING id, theme_design`,
        [JSON.stringify(themeDesign), orderId],
      );
      if (result.rowCount === 0) {
        result = await pool.query(
          `UPDATE catering_orders
           SET theme_design = COALESCE(theme_design, '{}'::jsonb) || $1::jsonb,
               updated_at = now()
           WHERE id = $2
           RETURNING id, theme_design`,
          [JSON.stringify(themeDesign), orderId],
        );
      }
      if (result.rowCount === 0) return res.status(404).json({ error: "Order not found" });
      return res.json({ ok: true, themeDesign: result.rows[0].theme_design });
    } catch (e) {
      console.error("[theme design save] failed", e);
      return res.status(500).json({ error: "Failed to save theme design" });
    }
  },
);

// Debug endpoints — development only
if (process.env.NODE_ENV !== "production") {
app.get("/api/debug/test-account", async (req, res) => {
  try {
    const testEmail = "admin@curatering.test";
    const result = await pool.query(
      `SELECT id, email, full_name, role, is_verified, archived
       FROM users
       WHERE email = $1`,
      [testEmail]
    );
    
    if (result.rowCount === 0) {
      return res.json({ 
        message: "Test account not found",
        email: testEmail 
      });
    }
    
    const user = result.rows[0];
    return res.json({ 
      message: "Test account found",
      user: {
        id: user.id,
        email: user.email,
        fullName: user.full_name,
        role: user.role,
        isVerified: user.is_verified,
        archived: user.archived
      }
    });
  } catch (e) {
    return res.status(500).json({ message: "Failed to check test account" });
  }
});

// Debug endpoint to list users (development only)
app.get("/api/debug/users", async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, email, full_name, role, is_verified, archived
       FROM users
       ORDER BY created_at DESC
       LIMIT 10;`
    );
    return res.json({ users: result.rows });
  } catch (e) {
    return res.status(500).json({ message: "Failed to fetch users" });
  }
});
}

// Accept an order (move to post-analysis)
app.post(
  "/api/events/orders/:orderId/accept",
  authRequired,
  (req, res, next) =>
    requireRoles(
      req,
      res,
      next,
      new Set(["manager", "supervisor", "admin", "super_admin"]),
    ),
  async (req, res) => {
    try {
      const { orderId } = req.params;

      const result = await pool.query(
        `UPDATE event_orders
         SET
           status = 'for_full_payment',
           updated_by = $1,
           updated_at = now()
         WHERE id = $2
           AND status IN ('on_going', 'ongoing', 'for_ongoing', 'for_processing')
         RETURNING id;`,
        [req.user.id, orderId],
      );

      if (result.rowCount === 0) {
        return res
          .status(404)
          .json({ message: "Processing order not found or already completed" });
      }

      await logAction({
        userId: req.user.id,
        feature: "Events",
        action: "accepted order",
        other: { orderId },
      });

      const eventEmail = await pool.query(
        "SELECT email_address, customer_name FROM event_orders WHERE id = $1 LIMIT 1",
        [orderId],
      );
      if (eventEmail.rowCount > 0) {
        await sendCustomerNotificationEmail({
          to: eventEmail.rows[0].email_address,
          subject: "Curatering: Order status updated",
          text:
            `Hello ${eventEmail.rows[0].customer_name || "Customer"},\n\n` +
            `Your event order (${orderId}) is now marked for final payment.\n\n` +
            `- Curatering Team`,
        });
      }

      return res.json({ ok: true, id: result.rows[0].id });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: "Failed to accept order" });
    }
  },
);

app.post(
  "/api/events/orders/:orderId/post-changes",
  authRequired,
  (req, res, next) =>
    requireRoles(
      req,
      res,
      next,
      new Set(["manager", "supervisor", "admin", "super_admin"]),
    ),
  async (req, res) => {
    try {
      const { orderId } = req.params;
      const result = await pool.query(
        `SELECT id, email_address, customer_name, event_title, status
         FROM event_orders
         WHERE id = $1
           AND status IN ('on_going', 'ongoing', 'for_ongoing', 'for_processing', 'for_full_payment')
         LIMIT 1;`,
        [orderId],
      );
      if (result.rowCount === 0) {
        return res
          .status(404)
          .json({ message: "Event order not found or not publishable" });
      }

      const order = result.rows[0];
      const customerEmail = String(order.email_address || "").trim();
      if (!customerEmail) {
        return res.status(400).json({ message: "Customer email is missing" });
      }

      await logAction({
        userId: req.user.id,
        feature: "Events",
        action: "posted order changes to customer",
        other: { orderId },
      });

      await sendCustomerNotificationEmail({
        to: customerEmail,
        subject: "Curatering: Your event order has been updated",
        text:
          `Hello ${order.customer_name || "Customer"},\n\n` +
          `Your event order (${order.event_title || orderId}) has updated details from our team. ` +
          `Please review your order in Curatering, including the seating layout if one is available.\n\n` +
          `- Curatering Team`,
      });

      return res.json({ ok: true });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: "Failed to post order changes" });
    }
  },
);

// Cancel an order
app.post(
  "/api/events/orders/:orderId/cancel",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "supervisor", "admin"])),
  async (req, res) => {
    try {
      const { orderId } = req.params;

      // First try event_orders table
      let result = await pool.query(
        `UPDATE event_orders
         SET
           status = 'cancelled',
           updated_by = $1,
           updated_at = now()
         WHERE id = $2
           AND status IN ('for_processing', 'online_inquiries', 'new_event')
         RETURNING id;`,
        [req.user.id, orderId],
      );

      // If no rows affected, try catering_orders table
      if (result.rowCount === 0) {
        result = await pool.query(
          `UPDATE catering_orders
           SET
             status = 'cancelled',
             updated_by = $1,
             updated_at = now()
           WHERE id = $2
             AND status IN ('for_processing', 'online_inquiries', 'new_event')
           RETURNING id;`,
          [req.user.id, orderId],
        );
      }

      if (result.rowCount === 0) {
        return res
          .status(404)
          .json({ message: "Order not found or cannot be cancelled" });
      }

      await logAction({
        userId: req.user.id,
        feature: "Events",
        action: "cancelled order",
        other: { orderId },
      });

      const eventEmail = await pool.query(
        "SELECT email_address, customer_name FROM event_orders WHERE id = $1 LIMIT 1",
        [orderId],
      );
      if (eventEmail.rowCount > 0) {
        await sendCustomerNotificationEmail({
          to: eventEmail.rows[0].email_address,
          subject: "Curatering: Order status updated",
          text:
            `Hello ${eventEmail.rows[0].customer_name || "Customer"},\n\n` +
            `Your event order (${orderId}) has been cancelled.\n\n` +
            `- Curatering Team`,
        });
      }

      return res.json({ ok: true, id: result.rows[0].id });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: "Failed to cancel order" });
    }
  },
);

async function seedSuperAdminIfNeeded() {
  const email = process.env.SEED_SUPER_ADMIN_EMAIL;
  const password = process.env.SEED_SUPER_ADMIN_PASSWORD;
  const fullName = process.env.SEED_SUPER_ADMIN_FULL_NAME || "Super Admin";

  if (!email || !password) {
    if (process.env.NODE_ENV === "production") {
      console.warn(
        "[startup] SEED_SUPER_ADMIN_EMAIL/PASSWORD not set — skipping default admin seed in production",
      );
      return;
    }
    const testEmail = "admin@curatering.test";
    const testPassword = "admin123";
    const testFullName = "Test Super Admin";
    const existing = await pool.query(
      `SELECT id FROM users WHERE email = $1 LIMIT 1;`,
      [testEmail],
    );

    if (existing.rowCount === 0) {
      const passwordHash = await bcrypt.hash(testPassword, 10);
      const userId = await allocateStaffUserId();
      await pool.query(
        `INSERT INTO users (id, email, password_hash, full_name, role, archived, is_verified)
         VALUES ($1, $2, $3, $4, 'super_admin', FALSE, TRUE);`,
        [userId, testEmail, passwordHash, testFullName],
      );
      console.warn(
        "[startup] Created dev super-admin admin@curatering.test / admin123 — set SEED_SUPER_ADMIN_* in production",
      );
    }
    return;
  }

  const existing = await pool.query(
    `SELECT id FROM users WHERE email = $1 LIMIT 1;`,
    [email],
  );
  if (existing.rowCount > 0) return;

  const passwordHash = await bcrypt.hash(password, 10);
  const userId = await allocateStaffUserId();
  await pool.query(
    `INSERT INTO users (id, email, password_hash, full_name, role, archived)
     VALUES ($1, $2, $3, $4, 'super_admin', FALSE);`,
    [userId, email, passwordHash, fullName],
  );
}

function parseRestaurantCoord(value) {
  if (value == null || value === '') return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

async function resolveRestaurantOrderEmail(order) {
  if (order.user_email) {
    return String(order.user_email).trim();
  }
  if (!order.customer_id) return null;
  const r = await pool.query(
    'SELECT email FROM customer_accounts WHERE id = $1 LIMIT 1',
    [order.customer_id],
  );
  return r.rowCount > 0 ? r.rows[0].email : null;
}

/** Transient DNS/network errors to Supabase are common in Docker (EAI_AGAIN). */
async function runInitDbWithRetries() {
  const maxAttempts = Number(process.env.DB_INIT_RETRY_ATTEMPTS || 10);
  const delayMs = Number(process.env.DB_INIT_RETRY_DELAY_MS || 2500);
  let lastErr;
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      await initDb();
      if (attempt > 1) {
        console.log(`initDb succeeded on attempt ${attempt}/${maxAttempts}`);
      }
      return;
    } catch (e) {
      lastErr = e;
      const msg = String(e?.message || e || "");
      const retryable =
        e?.code === "EAI_AGAIN" ||
        e?.code === "ENOTFOUND" ||
        e?.code === "ETIMEDOUT" ||
        e?.code === "ECONNRESET" ||
        e?.code === "EPIPE" ||
        /getaddrinfo/i.test(msg) ||
        /connect/i.test(msg);
      console.error(
        `Database init attempt ${attempt}/${maxAttempts} failed:`,
        msg || e,
      );
      if (!retryable || attempt >= maxAttempts) {
        throw e;
      }
      await new Promise((r) => setTimeout(r, delayMs));
    }
  }
  throw lastErr;
}

let bootstrapRetryTimer = null;

let authSchemaPromise = Promise.resolve();

function scheduleBootstrapRetry() {
  if (process.env.DB_INIT_FATAL === '1') {
    console.error('[startup] DB_INIT_FATAL=1 — not scheduling retry');
    return;
  }
  if (bootstrapRetryTimer) return;
  const delayMs = Number(process.env.DB_INIT_BACKGROUND_RETRY_MS || 30000);
  console.log(`[startup] Scheduling database bootstrap retry in ${delayMs}ms`);
  bootstrapRetryTimer = setTimeout(() => {
    bootstrapRetryTimer = null;
    runDatabaseBootstrap().catch(() => {});
  }, delayMs);
}

function runDatabaseBootstrap() {
  dbInitState = 'pending';
  authSchemaPromise = ensureAuthSchemaQuick()
    .then(() => ensureRestaurantOrderWorkflowColumns().catch((err) => {
      console.warn('[startup] restaurant_orders workflow columns:', err?.message || err);
    }))
    .then(() => ensureRestaurantOrdersCanonicalColumns().catch((err) => {
      console.warn('[startup] restaurant_orders canonical columns:', err?.message || err);
    }))
    .then(() => ensureCateringEventOrdersCanonicalColumns().catch((err) => {
      console.warn('[startup] catering/event_orders canonical columns:', err?.message || err);
    }))
    .then(() => ensureCustomerAccountsUuidCompat().catch((err) => {
      console.warn('[startup] customer_accounts UUID compat:', err?.message || err);
    }))
    .then(() => ensureCustomerTrayDraftsSchema().catch((err) => {
      console.warn('[startup] customer_tray_drafts schema:', err?.message || err);
    }))
    .then(() => ensureSuperAdminTodosSchema().catch((err) => {
      console.warn('[startup] super_admin_todos schema:', err?.message || err);
    }))
    .then(() => {
      dbReady = true;
      console.log('[startup] Auth schema ready — customer login enabled');
      return runInitDbWithRetries();
    })
    .then(() => seedSuperAdminIfNeeded())
    .then(registerRoutesAfterDbInit)
    .then(() => {
      dbInitState = 'ready';
    })
    .catch((err) => {
      dbInitState = 'failed';
      dbReady = false;
      console.error('[startup] Database bootstrap failed:', err?.message || err);
      scheduleBootstrapRetry();
    });
  return authSchemaPromise;
}

function requireDbReady(req, res, next) {
  if (dbReady) return next();
  authSchemaPromise
    .then(() => next())
    .catch(() => {
      res.status(503).json({
        message: 'Server is starting up. Please try again in a moment.',
        database: dbInitState,
      });
    });
}

registerCustomerAuthRoutes(app, requireDbReady);

let autoCancelJobScheduled = false;

function scheduleAutoCancelJob() {
  if (autoCancelJobScheduled) return;
  autoCancelJobScheduled = true;
  console.log('[auto-cancel] Disabled; customer follow-up requests now handle stale pending orders.');
}

async function autoCancelStalePendingCashierOrders() {
  try {
    await ensureRestaurantOrderWorkflowColumns();
    const result = await pool.query(
      `UPDATE restaurant_orders
       SET order_status = 'CANCELLED', updated_at = now()
       WHERE order_status = 'PENDING_CASHIER'
         AND COALESCE(updated_at, created_at) < now() - interval '1 hour'
       RETURNING *`,
    );
    for (const order of result.rows) {
      const email = await resolveRestaurantOrderEmail(order);
      if (email) {
        await sendCustomerNotificationEmail({
          to: email,
          subject: 'Curatering: Order cancelled (payment timeout)',
          text:
            `Your order ${order.order_id} was cancelled because payment was not confirmed within 1 hour.\n\n` +
            `- Curatering Team`,
        });
      }
    }
    if (result.rowCount > 0) {
      console.log(
        `[auto-cancel] Cancelled ${result.rowCount} stale pending_cashier order(s)`,
      );
    }
  } catch (error) {
    console.error('[auto-cancel] pending_cashier:', error);
  }
}

app.listen(PORT, () => {
  console.log(`Curatering server listening on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || "development"}`);
  console.log(
    `Database URL configured: ${process.env.DATABASE_URL ? "Yes" : "No"}`,
  );
  logEmailStartupStatus();
});

// Optional: send a test email (set EMAIL_TEST_SECRET on the server)
app.post("/api/health/email-test", async (req, res) => {
  try {
    const secret = process.env.EMAIL_TEST_SECRET?.trim();
    const { to, testSecret } = req.body || {};
    if (!secret || testSecret !== secret) {
      return res.status(403).json({ message: "Forbidden" });
    }
    if (!to || typeof to !== "string") {
      return res.status(400).json({ message: "to (email) is required" });
    }
    if (!isEmailConfigured()) {
      return res.status(503).json({
        message: "Email not configured",
        hint: "Set RESEND_API_KEY and RESEND_FROM on this host",
      });
    }
    const data = await sendEmail({
      to: to.trim(),
      subject: "Curatering email test",
      text: "If you received this, Resend is working.",
    });
    return res.json({ ok: true, id: data?.id });
  } catch (e) {
    console.error("[email-test]", e?.message || e);
    return res.status(500).json({
      message: e?.message || "Send failed",
      hint:
        "If FROM uses @curatering.com, verify the domain at https://resend.com/domains. " +
        "For testing use RESEND_FROM=Curatering <onboarding@resend.dev>",
    });
  }
});

async function registerRoutesAfterDbInit() {
  if (routesRegistered) {
    console.log('[startup] API routes already registered');
    return;
  }

    // Replace entire checklist (bulk save from staff UI)
    app.put('/api/events/orders/:orderId/checklist', authRequired, async (req, res) => {
      try {
        const { orderId } = req.params;
        const { checklist, deductInventory } = req.body || {};
        if (!Array.isArray(checklist)) {
          return res.status(400).json({ error: 'checklist array is required' });
        }

        const orderResult = await pool.query(
          `SELECT 'event_orders' as table_name FROM event_orders WHERE id = $1
           UNION ALL
           SELECT 'catering_orders' FROM catering_orders WHERE id = $1
           LIMIT 1`,
          [orderId],
        );
        if (orderResult.rows.length === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }
        const tableName = orderResult.rows[0].table_name;

        const normalized = checklist.map((raw) => {
          const row = raw && typeof raw === 'object' ? raw : {};
          const title = (row.title ?? row.item ?? '').toString().trim();
          const description = (row.description ?? '').toString();
          const qty = Math.max(1, Number(row.quantity) || 1);
          const price =
            row.price != null
              ? Number(row.price)
              : row.cost != null
                ? Number(row.cost)
                : 0;
          return {
            id:
              row.id && String(row.id).trim()
                ? String(row.id).trim()
                : crypto.randomUUID(),
            title: title || 'Item',
            description,
            price: Number.isFinite(price) ? price : 0,
            quantity: qty,
            assignedTo: (row.assignedTo ?? '').toString(),
            isCompleted: row.isCompleted === true,
            inventoryId: row.inventoryId ? String(row.inventoryId) : null,
          };
        });

        const shouldAdvanceToFullPayment =
          normalized.length > 0 && normalized.every((item) => item.isCompleted === true);
        const result = await pool.query(
          `UPDATE ${tableName}
           SET checklist = $1::jsonb,
               status = CASE
                 WHEN $3::boolean
                   AND status IN ('on_going', 'ongoing', 'for_processing')
                   THEN 'for_full_payment'
                 ELSE status
               END,
               updated_at = now()
           WHERE id = $2
           RETURNING checklist, status`,
          [JSON.stringify(normalized), orderId, shouldAdvanceToFullPayment],
        );

        if (deductInventory === true) {
          for (const item of normalized) {
            if (!item.inventoryId) continue;
            const qty = Math.max(0, Number(item.quantity) || 0);
            if (qty <= 0) continue;
            await pool.query(
              `UPDATE inventory
               SET quantity = GREATEST(0, quantity - $1), updated_at = now()
               WHERE id = $2::uuid AND archived = FALSE`,
              [qty, item.inventoryId],
            );
          }
        }

        res.json({ checklist: result.rows[0].checklist, status: result.rows[0].status });
      } catch (error) {
        console.error('Error replacing checklist:', error);
        res.status(500).json({ error: 'Failed to save checklist' });
      }
    });

    app.post(
      '/api/events/orders/:orderId/send-order-summary',
      authRequired,
      async (req, res) => {
        try {
          const { orderId } = req.params;
          const { pdfBase64, paymentType } = req.body || {};
          if (!pdfBase64 || typeof pdfBase64 !== 'string') {
            return res.status(400).json({ error: 'pdfBase64 is required' });
          }

          const orderResult = await pool.query(
            `SELECT email_address, event_title, customer_name FROM event_orders WHERE id = $1
             UNION ALL
             SELECT email_address, NULL::text AS event_title, customer_name FROM catering_orders WHERE id = $1
             LIMIT 1`,
            [orderId],
          );
          if (orderResult.rows.length === 0) {
            return res.status(404).json({ error: 'Order not found' });
          }
          const row = orderResult.rows[0];
          const to = (row.email_address || '').toString().trim();
          if (!to) {
            return res.status(400).json({ error: 'Order has no customer email' });
          }

          const isDown = paymentType === 'down_payment';
          const eventLabel =
            (row.event_title || row.customer_name || 'your event').toString();
          const subject = isDown
            ? `Order summary (down payment) — ${eventLabel}`
            : `Order summary — ${eventLabel}`;
          const text =
            `Hello,\n\n` +
            `Please find your order summary attached for ${eventLabel}.\n\n` +
            `Thank you,\nMacrina's Kitchen and Catering`;

          await sendCustomerNotificationEmail({
            to,
            subject,
            text,
            attachments: [
              {
                filename: isDown
                  ? 'order-summary-down-payment.pdf'
                  : 'order-summary.pdf',
                content: pdfBase64.replace(/^data:application\/pdf;base64,/, ''),
              },
            ],
          });

          res.json({ ok: true });
        } catch (error) {
          console.error('Error emailing order summary:', error);
          res.status(500).json({ error: 'Failed to email order summary' });
        }
      },
    );

    // Checklist CRUD operations
    app.put('/api/events/orders/:orderId/checklist/:itemId', authRequired, async (req, res) => {
      try {
        const { orderId, itemId } = req.params;
        const { isCompleted, title, description, price, assignedTo } = req.body;
        
        // Determine which table to use
        const orderResult = await pool.query(
          `SELECT 'event_orders' as table_name FROM event_orders WHERE id = $1
           UNION ALL
           SELECT 'catering_orders' FROM catering_orders WHERE id = $1
           LIMIT 1`,
          [orderId]
        );
        
        if (orderResult.rows.length === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }
        
        const tableName = orderResult.rows[0].table_name;
        
        // Update checklist item in the correct table
        const result = await pool.query(
          `UPDATE ${tableName} 
           SET checklist = jsonb_set(
             checklist,
             array(
               (SELECT idx FROM jsonb_array_elements(checklist) WITH ORDINALITY arr(elem, idx) 
                WHERE elem->>'id' = $2)::int - 1
             ),
             $3::jsonb,
             true
           )
           WHERE id = $1
           RETURNING checklist`,
          [orderId, itemId, JSON.stringify({ id: itemId, title, description, price, assignedTo, isCompleted })]
        );
        
        if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Checklist item not found' });
        }
        
        res.json({ checklist: result.rows[0].checklist });
      } catch (error) {
        console.error('Error updating checklist item:', error);
        res.status(500).json({ error: 'Failed to update checklist item' });
      }
    });

    app.post('/api/events/orders/:orderId/checklist', authRequired, async (req, res) => {
      try {
        const { orderId } = req.params;
        const item = req.body;
        
        // Determine which table to use
        const orderResult = await pool.query(
          `SELECT 'event_orders' as table_name FROM event_orders WHERE id = $1
           UNION ALL
           SELECT 'catering_orders' FROM catering_orders WHERE id = $1
           LIMIT 1`,
          [orderId]
        );
        
        if (orderResult.rows.length === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }
        
        const tableName = orderResult.rows[0].table_name;
        
        // Add checklist item to the correct table
        const result = await pool.query(
          `UPDATE ${tableName} SET checklist = checklist || $1::jsonb WHERE id = $2 RETURNING checklist`,
          [JSON.stringify(item), orderId]
        );
        
        res.json({ checklist: result.rows[0].checklist });
      } catch (error) {
        console.error('Error adding checklist item:', error);
        res.status(500).json({ error: 'Failed to add checklist item' });
      }
    });

    app.delete('/api/events/orders/:orderId/checklist/:itemId', authRequired, async (req, res) => {
      try {
        const { orderId, itemId } = req.params;
        
        // Determine which table to use
        const orderResult = await pool.query(
          `SELECT 'event_orders' as table_name FROM event_orders WHERE id = $1
           UNION ALL
           SELECT 'catering_orders' FROM catering_orders WHERE id = $1
           LIMIT 1`,
          [orderId]
        );
        
        if (orderResult.rows.length === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }
        
        const tableName = orderResult.rows[0].table_name;
        
        // Remove checklist item from the correct table
        const result = await pool.query(
          `UPDATE ${tableName} 
           SET checklist = (
             SELECT jsonb_agg(elem) 
             FROM jsonb_array_elements(checklist) elem 
             WHERE elem->>'id' != $1
           )
           WHERE id = $2
           RETURNING checklist`,
          [itemId, orderId]
        );
        
        res.json({ checklist: result.rows[0].checklist });
      } catch (error) {
        console.error('Error deleting checklist item:', error);
        res.status(500).json({ error: 'Failed to delete checklist item' });
      }
    });

    // Payment status update endpoint
    app.put('/api/events/orders/:orderId/payment-status', authRequired, async (req, res) => {
      try {
        const { orderId } = req.params;
        const { paymentType, status, referenceNumber, amount } = req.body || {};
        const paymentMethodRaw = String(
          req.body?.paymentMethod ?? req.body?.payment_method ?? "",
        ).trim();

        if (!paymentType || !status) {
          return res.status(400).json({ error: 'paymentType and status are required' });
        }

        if (!['down_payment', 'full_payment'].includes(paymentType)) {
          return res.status(400).json({ error: 'Invalid paymentType. Must be down_payment or full_payment' });
        }

        if (!['paid', 'pending', 'cancelled'].includes(status)) {
          return res.status(400).json({ error: 'Invalid status. Must be paid, pending, or cancelled' });
        }

        const paymentMethodKey = paymentMethodRaw.toLowerCase().replace(/[^a-z0-9]+/g, "_");
        const referenceRules = [
          { test: /bank/.test(paymentMethodKey), label: "Bank Transfer", digits: 18 },
          { test: /debit|credit|card/.test(paymentMethodKey), label: "Debit/Credit Card", digits: 23 },
          { test: /e_?wallet|wallet/.test(paymentMethodKey), label: "E-wallet", digits: 13 },
        ];
        const referenceRule = referenceRules.find((rule) => rule.test);
        const cleanReference = String(referenceNumber || "").trim();
        if (status === "paid" && referenceRule) {
          const expected = referenceRule.digits;
          if (!new RegExp(`^\\d{${expected}}$`).test(cleanReference)) {
            return res.status(400).json({
              error: `${referenceRule.label} reference number must be exactly ${expected} digits`,
            });
          }
        }

        // Determine which table to use
        const orderResult = await pool.query(
          `SELECT 'event_orders' as table_name FROM event_orders WHERE id = $1
           UNION ALL
           SELECT 'catering_orders' FROM catering_orders WHERE id = $1
           LIMIT 1`,
          [orderId]
        );

        if (orderResult.rows.length === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }

        const tableName = orderResult.rows[0].table_name;
        const statusColumn = paymentType === 'down_payment' ? 'down_payment_status' : 'full_payment_status';
        const amountColumn = paymentType === 'down_payment' ? 'down_payment_amount' : 'full_payment_amount';
        let downPaymentNextStatus = "on_going";
        if (paymentType === "down_payment") {
          try {
            const constraint = await pool.query(
              `SELECT pg_get_constraintdef(oid) AS definition
               FROM pg_constraint
               WHERE conrelid = $1::regclass
                 AND conname = $2
               LIMIT 1`,
              [tableName, `${tableName}_status_check`],
            );
            const definition = String(constraint.rows[0]?.definition || "");
            if (
              definition &&
              !definition.includes("'on_going'") &&
              definition.includes("'for_processing'")
            ) {
              downPaymentNextStatus = "for_processing";
            }
          } catch (_) {
            // Keep the canonical status when constraint inspection is unavailable.
          }
        }

        // Build update query with reference number if provided
        let updateQuery = `UPDATE ${tableName} SET ${statusColumn} = $1, updated_at = now()`;
        const queryParams = [status];

        if (status === 'paid' && paymentType === 'down_payment') {
          updateQuery += `,
            status = CASE
              WHEN status IN ('for_down_payment', 'for_downpayment') THEN $${queryParams.length + 1}
              ELSE status
            END`;
          queryParams.push(downPaymentNextStatus);
        } else if (status === 'paid' && paymentType === 'full_payment') {
          updateQuery += `,
            status = CASE
              WHEN status IN ('on_going', 'ongoing', 'for_processing') THEN 'for_full_payment'
              ELSE status
            END`;
        }

        if (referenceNumber && referenceNumber.trim()) {
          const refColumn = paymentType === 'down_payment' ? 'down_payment_reference' : 'full_payment_reference';
          updateQuery += `, ${refColumn} = $${queryParams.length + 1}`;
          queryParams.push(cleanReference);
        }

        if (paymentMethodRaw) {
          updateQuery += `, payment_method = $${queryParams.length + 1}`;
          queryParams.push(paymentMethodRaw);
        }

        const amountNum = Number(amount);
        if (Number.isFinite(amountNum) && amountNum > 0) {
          updateQuery += `, ${amountColumn} = $${queryParams.length + 1}`;
          queryParams.push(amountNum);
        }

        updateQuery += ` WHERE id = $${queryParams.length + 1} RETURNING *`;
        queryParams.push(orderId);

        const result = await pool.query(updateQuery, queryParams);

        res.json({ ok: true, order: result.rows[0] });
      } catch (error) {
        console.error('Error updating payment status:', error);
        res.status(500).json({ error: 'Failed to update payment status' });
      }
    });

    app.put(
      '/api/events/orders/:orderId/seating',
      authRequired,
      (req, res, next) =>
        requireRoles(
          req,
          res,
          next,
          new Set(['manager', 'supervisor', 'super_admin', 'admin']),
        ),
      async (req, res) => {
        try {
          const { orderId } = req.params;
          const { seatingPlan } = req.body || {};
          const n = normalizeSeatingPlan(seatingPlan);
          if (!n.ok) {
            return res.status(400).json({ error: n.error });
          }
          const result = await pool.query(
            `UPDATE event_orders
             SET seating_plan = $1::jsonb, updated_by = $2, updated_at = now()
             WHERE id = $3::uuid
               AND status IN ('for_processing', 'on_going', 'ongoing', 'for_ongoing')
             RETURNING id`,
            [JSON.stringify(n.plan), req.user.id, orderId],
          );
          if (result.rowCount === 0) {
            return res.status(404).json({
              message:
                'Event order not found, not ongoing, or order is not in event_orders.',
            });
          }
          await logAction({
            userId: req.user.id,
            feature: 'Events',
            action: 'updated seating plan',
            other: { orderId },
          });
          return res.json({ ok: true, seatingPlan: n.plan });
        } catch (error) {
          console.error('Error updating seating plan:', error);
          res.status(500).json({ error: 'Failed to update seating plan' });
        }
      },
    );

// Loyalty Rewards API endpoints
    app.get('/api/loyalty/program-config', async (_req, res) => {
      try {
        const config = await getLoyaltyProgramConfig();
        res.json(config);
      } catch (error) {
        console.error('Error fetching loyalty program config:', error);
        res.status(500).json({ error: 'Failed to fetch loyalty program config' });
      }
    });

    app.get(
      '/api/manager/loyalty/program-config',
      managerAuthRequired,
      async (_req, res) => {
        try {
          const config = await getLoyaltyProgramConfig();
          res.json(config);
        } catch (error) {
          res.status(500).json({ error: 'Failed to fetch loyalty program config' });
        }
      },
    );

    app.put(
      '/api/manager/loyalty/program-config',
      managerAuthRequired,
      async (req, res) => {
        try {
          const { pointsConditions, rewardsConditions } = req.body || {};
          if (!Array.isArray(pointsConditions) || !Array.isArray(rewardsConditions)) {
            return res.status(400).json({
              error: 'pointsConditions and rewardsConditions arrays are required',
            });
          }
          await setLoyaltyProgramConfig({ pointsConditions, rewardsConditions });
          res.json({ ok: true });
        } catch (error) {
          res.status(500).json({ error: 'Failed to save loyalty program config' });
        }
      },
    );

    app.get('/api/loyalty/user-points', authRequired, async (req, res) => {
      try {
        const userId = req.user.id;
        
        // Calculate user points from completed orders
        // TODO: Fix customer_id column issue - using id for testing
        const ordersResult = await pool.query(
          `SELECT 
             COUNT(*) as total_orders,
             COALESCE(SUM(total_cost), 0) as total_spent
           FROM (
             SELECT total_cost FROM event_orders 
             WHERE id = $1 AND final_status = 'successful'
             UNION ALL
             SELECT total_cost FROM catering_orders 
             WHERE id = $1 AND final_status = 'successful'
           ) orders`,
          [userId]
        );
        
        const { total_orders, total_spent } = ordersResult.rows[0];
        const points = Math.floor(total_spent * 0.1); // 10% of total spent
        
        // Get redeemed rewards
        const redeemedResult = await pool.query(
          'SELECT * FROM user_rewards WHERE user_id = $1 AND redeemed = true',
          [userId]
        );
        
        res.json({
          userPoints: points,
          totalOrders: parseInt(total_orders),
          totalSpent: parseFloat(total_spent),
          redeemedRewards: redeemedResult.rows,
        });
      } catch (error) {
        console.error('Error fetching user points:', error);
        res.status(500).json({ error: 'Failed to fetch user points' });
      }
    });

    app.get('/api/loyalty/rewards', authRequired, async (req, res) => {
      try {
        const result = await pool.query(
          'SELECT * FROM rewards WHERE active = true ORDER BY points_cost ASC'
        );
        
        res.json({ rewards: result.rows });
      } catch (error) {
        console.error('Error fetching rewards:', error);
        res.status(500).json({ error: 'Failed to fetch rewards' });
      }
    });

    app.post('/api/loyalty/redeem', authRequired, async (req, res) => {
      try {
        const { rewardId } = req.body;
        const userId = req.user.id;
        
        // Get reward details
        const rewardResult = await pool.query(
          'SELECT * FROM rewards WHERE id = $1 AND active = true',
          [rewardId]
        );
        
        if (rewardResult.rows.length === 0) {
          return res.status(404).json({ error: 'Reward not found' });
        }
        
        const reward = rewardResult.rows[0];
        
        // Calculate user points
        // TODO: Fix customer_id column issue - using id for testing
        const pointsResult = await pool.query(
          `SELECT COALESCE(SUM(total_cost), 0) as total_spent
           FROM (
             SELECT total_cost FROM event_orders 
             WHERE id = $1 AND final_status = 'successful'
             UNION ALL
             SELECT total_cost FROM catering_orders 
             WHERE id = $1 AND final_status = 'successful'
           ) orders`,
          [userId]
        );
        
        const userPoints = Math.floor(pointsResult.rows[0].total_spent * 0.1);
        
        if (userPoints < reward.points_cost) {
          return res.status(400).json({ error: 'Insufficient points' });
        }
        
        // Check if already redeemed
        const existingResult = await pool.query(
          'SELECT * FROM user_rewards WHERE user_id = $1 AND reward_id = $2',
          [userId, rewardId]
        );
        
        if (existingResult.rows.length > 0) {
          return res.status(400).json({ error: 'Reward already redeemed' });
        }
        
        // Create redemption record
        await pool.query(
          `INSERT INTO user_rewards (user_id, reward_id, redeemed_at, points_used)
           VALUES ($1, $2, NOW(), $3)`,
          [userId, rewardId, reward.points_cost]
        );
        
        res.json({ 
          message: 'Reward redeemed successfully',
          pointsUsed: reward.points_cost,
          remainingPoints: userPoints - reward.points_cost
        });
      } catch (error) {
        console.error('Error redeeming reward:', error);
        res.status(500).json({ error: 'Failed to redeem reward' });
      }
    });

    app.get('/api/loyalty/user-rewards', authRequired, async (req, res) => {
      try {
        const userId = req.user.id;
        
        const result = await pool.query(
          `SELECT ur.*, r.title, r.description, r.category, r.points_cost
           FROM user_rewards ur
           JOIN rewards r ON ur.reward_id = r.id
           WHERE ur.user_id = $1
           ORDER BY ur.redeemed_at DESC`,
          [userId]
        );
        
        res.json({ rewards: result.rows });
      } catch (error) {
        console.error('Error fetching user rewards:', error);
        res.status(500).json({ error: 'Failed to fetch user rewards' });
      }
    });

    // Menu Dishes API endpoints
    // Public endpoint - only returns active (non-archived) dishes without images for faster loading
    app.get('/api/menu/allergen-presets', async (_req, res) => {
      try {
        const presets = await getMenuAllergenCatalog();
        res.json({ presets });
      } catch (e) {
        console.error('allergen-presets get', e);
        res.status(500).json({ error: 'Failed to load allergen presets' });
      }
    });

    app.get('/api/menu/meal-types', async (_req, res) => {
      try {
        const mealTypes = await getMenuMealTypeCatalog();
        res.json({ mealTypes });
      } catch (e) {
        console.error('meal-types get', e);
        res.status(500).json({ error: 'Failed to load meal types' });
      }
    });

    app.post('/api/public/analytics/page-view', async (req, res) => {
      try {
        const platform =
          String(req.body?.platform || 'web').toLowerCase() === 'mobile'
            ? 'mobile'
            : 'web';
        const path = String(req.body?.path || '/').slice(0, 500);
        await pool.query(
          `INSERT INTO site_page_views (platform, path) VALUES ($1, $2)`,
          [platform, path],
        );
        res.json({ ok: true });
      } catch (e) {
        console.error('page-view', e);
        res.status(500).json({ error: 'Failed to record page view' });
      }
    });

    app.get('/api/menu/dishes', async (req, res) => {
      let retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          const result = await pool.query(
            `SELECT id, name, price, menu_dishes_additional_charge_amount, category, pax_options, sauces, supports_addons, ingredients,
                    image_base64, archived, available, archived_at, created_at, updated_at, type, set_menus,
                    public_description, allergens, meal_type
             FROM menu_dishes
             WHERE archived = false
             ORDER BY category, name`
          );
          res.json({ dishes: result.rows });
          return;
        } catch (error) {
          retryCount++;
          console.error(`Error fetching menu dishes (attempt ${retryCount}):`, error);
          
          if (retryCount >= maxRetries) {
            res.status(500).json({ error: 'Failed to fetch menu dishes' });
            return;
          }
          
          // Exponential backoff: wait 1s, 2s, 4s
          await new Promise(resolve => setTimeout(resolve, Math.pow(2, retryCount - 1) * 1000));
        }
      }
    });

    // Public endpoint with images - for when dish details are needed
    app.get('/api/menu/dishes/with-images', async (req, res) => {
      let retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          const result = await pool.query(
            `SELECT id, name, price, menu_dishes_additional_charge_amount, category, pax_options, sauces, supports_addons, ingredients,
                    image_base64, archived, available, archived_at, created_at, updated_at, type, set_menus,
                    public_description, allergens, meal_type
             FROM menu_dishes
             WHERE archived = false
             ORDER BY category, name`
          );
          res.json({ dishes: result.rows });
          return;
        } catch (error) {
          retryCount++;
          console.error(`Error fetching menu dishes with images (attempt ${retryCount}):`, error);
          
          if (retryCount >= maxRetries) {
            res.status(500).json({ error: 'Failed to fetch menu dishes' });
            return;
          }
          
          // Exponential backoff: wait 1s, 2s, 4s
          await new Promise(resolve => setTimeout(resolve, Math.pow(2, retryCount - 1) * 1000));
        }
      }
    });

    // Get single dish with image
    app.get('/api/menu/dishes/:id/with-image', async (req, res) => {
      let retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          const { id } = req.params;
          const result = await pool.query(
            `SELECT id, name, price, menu_dishes_additional_charge_amount, category, pax_options, sauces, supports_addons, ingredients,
                    image_base64, archived, available, archived_at, created_at, updated_at, type, set_menus,
                    public_description, allergens, meal_type
             FROM menu_dishes
             WHERE id = $1 AND archived = false`,
            [id]
          );
          
          if (result.rows.length === 0) {
            res.status(404).json({ error: 'Dish not found' });
            return;
          }
          
          res.json({ dish: result.rows[0] });
          return;
        } catch (error) {
          retryCount++;
          console.error(`Error fetching dish with image (attempt ${retryCount}):`, error);
          
          if (retryCount >= maxRetries) {
            res.status(500).json({ error: 'Failed to fetch dish' });
            return;
          }
          
          // Exponential backoff: wait 1s, 2s, 4s
          await new Promise(resolve => setTimeout(resolve, Math.pow(2, retryCount - 1) * 1000));
        }
      }
    });

    // Protected endpoint - returns all dishes including archived (for admin)
    app.get('/api/menu/dishes/all', authRequired, async (req, res) => {
      try {
        const result = await pool.query(
          `SELECT id, name, price, menu_dishes_additional_charge_amount, category, pax_options, sauces, supports_addons, ingredients,
                  image_base64, archived, available, archived_at, created_at, updated_at, type, meal_type, set_menus,
                  public_description, allergens
           FROM menu_dishes
           ORDER BY category, name`
        );
        res.json({ dishes: result.rows });
      } catch (error) {
        console.error('Error fetching all menu dishes:', error);
        res.status(500).json({ error: 'Failed to fetch menu dishes' });
      }
    });

    app.post('/api/menu/dishes', authRequired, async (req, res) => {
      try {
        const {
          name,
          price,
          category,
          paxOptions,
          sauces,
          supportsAddOns,
          ingredients,
          imageBase64,
          type,
          mealType,
          available,
          publicDescription,
          allergens,
          menuDishesAdditionalChargeAmount,
          additionalChargeAmount,
        } = req.body || {};
        
        if (!name || !price) {
          return res.status(400).json({ error: 'Name and price are required' });
        }

        const dishCategory = category || 'catering';
        const additionalCharge = Number(
          menuDishesAdditionalChargeAmount ?? additionalChargeAmount ?? 0,
        );
        const resolvedMealType = String(mealType ?? '').trim() || String(type ?? '').trim();
        const mealTypeSaved = resolvedMealType
          ? await upsertMenuMealType(resolvedMealType)
          : '';

        const result = await pool.query(
          `INSERT INTO menu_dishes (name, price, menu_dishes_additional_charge_amount, category, pax_options, sauces, supports_addons, ingredients, image_base64, type, set_menus, available, public_description, allergens, meal_type)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
           RETURNING *`,
          [
            name,
            price,
            Number.isFinite(additionalCharge) ? Math.max(0, additionalCharge) : 0,
            dishCategory,
            JSON.stringify(paxOptions || []),
            JSON.stringify(sauces || []),
            Boolean(supportsAddOns) || (Array.isArray(sauces) && sauces.length > 0),
            JSON.stringify(ingredients || []),
            imageBase64 || null,
            dishCategory === 'restaurant' ? '' : (type || ''),
            JSON.stringify([]),
            available !== false,
            String(publicDescription ?? '').trim(),
            String(allergens ?? '').trim(),
            mealTypeSaved,
          ]
        );
        
        const allergenStr = String(allergens ?? '').trim();
        if (allergenStr) {
          await upsertMenuAllergensFromSerialized(allergenStr, await getMenuAllergenCatalog());
        }
        res.status(201).json({ dish: result.rows[0] });
      } catch (error) {
        console.error('Error creating menu dish:', error);
        res.status(500).json({ error: 'Failed to create menu dish' });
      }
    });

    app.put('/api/menu/dishes/:dishId', authRequired, async (req, res) => {
      try {
        const { dishId } = req.params;
        const {
          name,
          price,
          category,
          paxOptions,
          sauces,
          supportsAddOns,
          ingredients,
          imageBase64,
          type,
          mealType,
          available,
          publicDescription,
          allergens,
          menuDishesAdditionalChargeAmount,
          additionalChargeAmount,
        } = req.body || {};
        
        const dishCategory = category || 'catering';
        const additionalCharge = Number(
          menuDishesAdditionalChargeAmount ?? additionalChargeAmount ?? 0,
        );
        const resolvedMealType = String(mealType ?? '').trim() || String(type ?? '').trim();
        const mealTypeSaved = resolvedMealType
          ? await upsertMenuMealType(resolvedMealType)
          : '';

        const result = await pool.query(
          `UPDATE menu_dishes
           SET name = $1, price = $2, category = $3, pax_options = $4, 
               sauces = $5, supports_addons = $6, ingredients = $7, image_base64 = $8, type = $9, set_menus = $10,
               available = $11, public_description = $12, allergens = $13, meal_type = $14,
               menu_dishes_additional_charge_amount = $15, updated_at = now()
           WHERE id = $16
           RETURNING *`,
          [
            name,
            price,
            dishCategory,
            JSON.stringify(paxOptions),
            JSON.stringify(sauces),
            Boolean(supportsAddOns) || (Array.isArray(sauces) && sauces.length > 0),
            JSON.stringify(ingredients),
            imageBase64,
            dishCategory === 'restaurant' ? '' : type,
            JSON.stringify(req.body.setMenus || []),
            available !== false,
            String(publicDescription ?? '').trim(),
            String(allergens ?? '').trim(),
            mealTypeSaved,
            Number.isFinite(additionalCharge) ? Math.max(0, additionalCharge) : 0,
            dishId,
          ]
        );
        
        if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Dish not found' });
        }

        const allergenStr = String(allergens ?? '').trim();
        if (allergenStr) {
          await upsertMenuAllergensFromSerialized(allergenStr, await getMenuAllergenCatalog());
        }
        
        res.json({ dish: result.rows[0] });
      } catch (error) {
        console.error('Error updating menu dish:', error);
        res.status(500).json({ error: 'Failed to update menu dish' });
      }
    });

    app.post('/api/menu/dishes/:dishId/archive', authRequired, async (req, res) => {
      try {
        const { dishId } = req.params;
        const { archived } = req.body || {};
        
        const result = await pool.query(
          `UPDATE menu_dishes
           SET archived = $1, archived_at = CASE WHEN $1 THEN now() ELSE null END, updated_at = now()
           WHERE id = $2
           RETURNING *`,
          [archived, dishId]
        );
        
        if (result.rowCount === 0) {
          return res.status(404).json({ error: 'Dish not found' });
        }
        
        res.json({ dish: result.rows[0] });
      } catch (error) {
        console.error('Error archiving menu dish:', error);
        res.status(500).json({ error: 'Failed to archive menu dish' });
      }
    });

    // Set Menus API endpoints
    app.get('/api/set-menus', authRequired, async (req, res) => {
      try {
        const result = await pool.query(
          `SELECT id, name, dish_ids, archived, created_at 
           FROM set_menus 
           WHERE archived = FALSE 
           ORDER BY name`
        );

        res.json({ setMenus: result.rows });
      } catch (error) {
        console.error('Error fetching set menus:', error);
        res.status(500).json({ error: 'Failed to fetch set menus' });
      }
    });

    app.post('/api/set-menus', authRequired, async (req, res) => {
      try {
        const { name, dishIds } = req.body || {};
        
        if (!name || !dishIds || !Array.isArray(dishIds)) {
          return res.status(400).json({ error: 'Name and dishIds array are required' });
        }

        // Check for duplicate name
        const existingResult = await pool.query(
          'SELECT id FROM set_menus WHERE LOWER(name) = LOWER($1) AND archived = FALSE',
          [name]
        );
        
        if (existingResult.rows.length > 0) {
          return res.status(400).json({ error: 'A set menu with this name already exists' });
        }

        const result = await pool.query(
          `INSERT INTO set_menus (name, dish_ids, archived, created_at, updated_at)
           VALUES ($1, $2, FALSE, now(), now())
           RETURNING *`,
          [name, dishIds]
        );

        res.status(201).json({ setMenu: result.rows[0] });
      } catch (error) {
        console.error('Error creating set menu:', error);
        res.status(500).json({ error: 'Failed to create set menu' });
      }
    });

    app.put('/api/set-menus/:setMenuId', authRequired, async (req, res) => {
      try {
        const { setMenuId } = req.params;
        const { name, dishIds } = req.body || {};
        
        if (!name || !dishIds || !Array.isArray(dishIds)) {
          return res.status(400).json({ error: 'Name and dishIds array are required' });
        }

        // Check for duplicate name (excluding current set menu)
        const existingResult = await pool.query(
          'SELECT id FROM set_menus WHERE LOWER(name) = LOWER($1) AND id != $2 AND archived = FALSE',
          [name, setMenuId]
        );
        
        if (existingResult.rows.length > 0) {
          return res.status(400).json({ error: 'A set menu with this name already exists' });
        }

        const result = await pool.query(
          `UPDATE set_menus
           SET name = $1, dish_ids = $2, updated_at = now()
           WHERE id = $3 AND archived = FALSE
           RETURNING *`,
          [name, dishIds, setMenuId]
        );

        if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Set menu not found' });
        }

        res.json({ setMenu: result.rows[0] });
      } catch (error) {
        console.error('Error updating set menu:', error);
        res.status(500).json({ error: 'Failed to update set menu' });
      }
    });

    app.post('/api/set-menus/:setMenuId/archive', authRequired, async (req, res) => {
      try {
        const { setMenuId } = req.params;
        const { archived } = req.body || {};

        const result = await pool.query(
          `UPDATE set_menus
           SET archived = $1, updated_at = now()
           WHERE id = $2
           RETURNING *`,
          [archived, setMenuId]
        );

        if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Set menu not found' });
        }

        res.json({ setMenu: result.rows[0] });
      } catch (error) {
        console.error('Error archiving set menu:', error);
        res.status(500).json({ error: 'Failed to archive set menu' });
      }
    });

    // Customer auth: registered early via registerCustomerAuthRoutes()

    // Restaurant Order endpoints
    async function restaurantOrderWhereClause(orderId, paramIndex) {
      const raw = String(orderId ?? "").trim();
      if (!raw) return null;
      const isUuid =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
          raw,
        );
      if (isUuid) {
        return { sql: `id = $${paramIndex}::uuid`, value: raw };
      }
      const roCols = await ensureRestaurantOrdersCanonicalColumns();
      return {
        sql: restaurantOrderLookupWhereSql(roCols, paramIndex),
        value: raw,
      };
    }

    const customerAuthRequired = (req, res, next) => {
      const customerId = customerIdFromRequest(req);
      if (!customerId) {
        return res.status(401).json({ error: 'Authentication required' });
      }
      req.customer = { id: customerId };
      next();
    };

    const optionalCustomerAuth = (req, res, next) => {
      const customerId = customerIdFromRequest(req);
      if (customerId) {
        req.customer = { id: customerId };
      }
      next();
    };

    function serializeRestaurantOrderRow(order, parsedItems, channel = 'web') {
      return normalizeRestaurantOrderRow(order, parsedItems, { channel });
    }

    app.post('/api/restaurant/orders', optionalCustomerAuth, async (req, res) => {
      try {
        const {
          items,
          tray_items,
          trayItems,
          fullName,
          phone,
          contactNumber,
          deliveryAddress,
          deliveryLat,
          deliveryLng,
          deliveryTime,
          deliveryNotes,
          totalAmount,
          totalCost,
          guestContactEmail,
          userEmail,
          orderSource,
        } = req.body || {};

        const customerId = req.customer?.id ?? null;
        const submittedEmail = userEmail ?? guestContactEmail;
        const orderEmail = submittedEmail
          ? String(submittedEmail).trim().toLowerCase()
          : null;

        if (!customerId && !orderEmail) {
          return res.status(400).json({
            error: 'Log in or provide userEmail for guest checkout',
          });
        }

        let orderItems = Array.isArray(tray_items)
          ? tray_items
          : Array.isArray(trayItems)
            ? trayItems
            : items;
        if (customerId && (!Array.isArray(orderItems) || orderItems.length === 0)) {
          orderItems = await getTrayDraftItemsByCustomerId(customerId);
        }
        if (!Array.isArray(orderItems) || orderItems.length === 0) {
          return res.status(400).json({ error: 'Items are required' });
        }
        const dishIds = [
          ...new Set(
            orderItems
              .map((item) => item?.dish_id ?? item?.dishId ?? item?.menu_dish_id ?? item?.id)
              .filter((value) => value != null && String(value).trim().isNotEmpty)
              .map((value) => String(value).trim()),
          ),
        ];
        if (dishIds.length > 0) {
          const dishResult = await pool.query(
            `SELECT id::text AS id, name, price, menu_dishes_additional_charge_amount, category, type, meal_type, public_description, allergens
             FROM menu_dishes
             WHERE id::text = ANY($1) AND archived = false`,
            [dishIds],
          );
          const dishesById = new Map(dishResult.rows.map((dish) => [dish.id, dish]));
          orderItems = orderItems.map((raw) => {
            if (!raw || typeof raw !== 'object') return raw;
            const item = { ...raw };
            const dishId = String(
              item.dish_id ?? item.dishId ?? item.menu_dish_id ?? item.id ?? '',
            ).trim();
            const dish = dishesById.get(dishId);
            if (!dish) return item;
            const price = Number(dish.price) || 0;
            const dip = String(item.dip ?? item.selected_sauce ?? item.selectedSauce ?? '').trim();
            const rawDipQty = Number(item.dip_qty ?? item.addOnQuantity ?? 1);
            const dipQty = dip
              ? Math.max(0, Number.isFinite(rawDipQty) ? Math.floor(rawDipQty) : 1)
              : 1;
            const qty = Math.max(1, Number(item.qty ?? item.quantity ?? 1) || 1);
            const additionalCharge = Number(dish.menu_dishes_additional_charge_amount) || 0;
            const extraPerUnit = additionalCharge > 0 ? additionalCharge : 15;
            const addonExtraSubtotal = dip ? Math.max(0, dipQty - 1) * extraPerUnit * qty : 0;
            return {
              ...item,
              dishId,
              dish_id: dishId,
              menu_dish_id: dishId,
              name: dish.name,
              item_name: dish.name,
              dishName: dish.name,
              dish_name: dish.name,
              price,
              dishPrice: price,
              dish_price: price,
              qty,
              quantity: qty,
              dip,
              dip_qty: dipQty,
              selectedSauce: dip || null,
              selected_sauce: dip || null,
              notes: item.notes ?? item.special_instructions ?? item.specialInstructions ?? '',
              line_subtotal: Number((qty * price + addonExtraSubtotal).toFixed(2)),
              addon_extra_subtotal: Number(addonExtraSubtotal.toFixed(2)),
              additional_charge_amount: additionalCharge,
              menu_dishes_additional_charge_amount: additionalCharge,
              dish_category: dish.category,
              dishCategory: dish.category,
              dish_type: dish.type,
              dishType: dish.type,
              meal_type: dish.meal_type,
              mealType: dish.meal_type,
              public_description: dish.public_description,
              allergens: dish.allergens,
              dish: {
                id: dishId,
                name: dish.name,
                price: String(dish.price),
                category: dish.category,
                type: dish.type,
                mealType: dish.meal_type,
              },
            };
          });
        }

        if (!deliveryAddress) {
          return res.status(400).json({ error: 'Delivery address is required' });
        }

        const lat = parseRestaurantCoord(deliveryLat);
        const lng = parseRestaurantCoord(deliveryLng);
        const orderNo = await allocateRestaurantOrderNo();
        const roCols = await ensureRestaurantOrdersCanonicalColumns();
        const orderIdCol = restaurantOrderIdInsertColumn(roCols);
        const itemsInsert = restaurantOrderItemsInsertSql(roCols);
        const itemsJson = JSON.stringify(orderItems);
        const itemsSql = itemsInsert.placeholders.replace(/\$ITEM\$/g, '$6');
        const normalizedSource = (() => {
          const s = String(orderSource || req.body?.platform || 'WEB_APP').trim().toUpperCase();
          if (s === 'MOBILE' || s === 'MOBILE_APP') return 'MOBILE_APP';
          if (s === 'POS_MOBILE' || s === 'POS_WEB') return s;
          return 'WEB_APP';
        })();

        const result = await pool.query(
          `INSERT INTO restaurant_orders (
             ${orderIdCol}, customer_id, user_email, full_name, contact_number,
             ${itemsInsert.columns},
             total_cost, delivery_address, delivery_lat, delivery_lng,
             delivery_time, delivery_notes, payment_mode, order_status, order_source,
             submitted_order_dt_stamp, last_updated_order_status_dt_stamp
           )
           VALUES ($1, $2, $3, $4, $5, ${itemsSql}, $7, $8, $9, $10,
                   COALESCE($11::text, 'NOW'), $12, 'GCASH ONLY', 'PENDING_CASHIER', $13,
                   now(), now())
           RETURNING *`,
          [
            orderNo,
            customerId,
            orderEmail,
            fullName || null,
            contactNumber || phone || null,
            itemsJson,
            totalCost ?? totalAmount ?? 0,
            deliveryAddress,
            lat,
            lng,
            deliveryTime || null,
            deliveryNotes || null,
            normalizedSource,
          ],
        );

        const notifyEmail = customerId
          ? (
              await pool.query(
                'SELECT email, full_name FROM customer_accounts WHERE id = $1 LIMIT 1',
                [customerId],
              )
            ).rows[0]?.email
          : orderEmail;

        if (notifyEmail) {
          await sendCustomerNotificationEmail({
            to: notifyEmail,
            subject: 'Curatering: Order received',
            text:
              `Hello ${fullName || 'Customer'},\n\n` +
              `Your order has been placed.\n` +
              `Order No: ${result.rows[0].order_id}\n` +
              `Total: PHP ${Number(totalCost ?? totalAmount ?? 0).toFixed(2)}\n\n` +
              `Complete payment to submit for cashier review.\n\n` +
              `- Curatering Team`,
          });
        }

        if (customerId) {
          try {
            await clearTrayDraftForCustomer(customerId);
          } catch {
            /* non-fatal */
          }
        }

        res.status(201).json({
          order: serializeRestaurantOrderRow(result.rows[0], orderItems),
        });
      } catch (error) {
        console.error('Error creating restaurant order:', error);
        res.status(500).json({ error: 'Failed to create order', details: error.message });
      }
    });

    app.post('/api/restaurant/orders/:orderId/payment', optionalCustomerAuth, async (req, res) => {
      try {
        const { orderId } = req.params;
        const { paymentReference, paymentProof, guestContactEmail, userEmail } = req.body || {};

        if (!paymentReference && !paymentProof) {
          return res.status(400).json({
            error: 'Payment reference or payment proof is required',
          });
        }

        const lookup = await restaurantOrderWhereClause(orderId, 1);
        if (!lookup) {
          return res.status(400).json({ error: 'Invalid order id' });
        }

        const existing = await pool.query(
          `SELECT * FROM restaurant_orders WHERE ${lookup.sql} LIMIT 1`,
          [lookup.value],
        );
        if (existing.rowCount === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }
        const order = existing.rows[0];

        if (req.customer?.id) {
          if (order.customer_id && String(order.customer_id) !== String(req.customer.id)) {
            return res.status(403).json({ error: 'Order not found' });
          }
        } else {
          const guestEmail = (userEmail ?? guestContactEmail)
            ? String(userEmail ?? guestContactEmail).trim().toLowerCase()
            : null;
          if (
            !guestEmail ||
            !order.user_email ||
            String(order.user_email).toLowerCase() !== guestEmail
          ) {
            return res.status(403).json({ error: 'Guest email does not match order' });
          }
        }

        const payLookup = await restaurantOrderWhereClause(orderId, 3);
        if (!payLookup) {
          return res.status(400).json({ error: 'Invalid order id' });
        }

        const roCols = await ensureRestaurantOrdersCanonicalColumns();
        const paymentSets = buildRestaurantOrderPaymentUpdateSets(roCols);

        const result = await pool.query(
          `UPDATE restaurant_orders
           SET ${paymentSets}
           WHERE ${payLookup.sql}
           RETURNING *`,
          [paymentReference || null, paymentProof || null, payLookup.value],
        );

        if (result.rowCount === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }

        const updated = result.rows[0];
        const parsedItems = parseRestaurantOrderTrayItems(updated);

        try {
          const email = await resolveRestaurantOrderEmail(updated);
          if (email) {
            sendCustomerNotificationEmailAsync({
              to: email,
              subject: 'Curatering: Payment submitted',
              text:
                `Your payment for order ${updated.order_id} is awaiting cashier verification.\n\n` +
                `- Curatering Team`,
            });
          }
        } catch (emailErr) {
          console.error('Payment notification email skipped:', emailErr?.message || emailErr);
        }

        res.json({
          order: serializeRestaurantOrderRow(updated, parsedItems),
        });
      } catch (error) {
        console.error('Error updating payment:', error?.message || error);
        res.status(500).json({ error: 'Failed to update payment' });
      }
    });

    app.get('/api/restaurant/orders/:orderId', customerAuthRequired, async (req, res) => {
      try {
        const { orderId } = req.params;
        
        const lookup = await restaurantOrderWhereClause(orderId, 1);
        if (!lookup) {
          return res.status(400).json({ error: 'Invalid order id' });
        }

        const result = await pool.query(
          `SELECT * FROM restaurant_orders WHERE ${lookup.sql} AND customer_id::text = $2`,
          [lookup.value, req.customer.id],
        );

        if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }

        const order = result.rows[0];
        const parsedItems = parseRestaurantOrderTrayItems(order);

        res.json({ order: serializeRestaurantOrderRow(order, parsedItems) });
      } catch (error) {
        console.error('Error fetching order:', error);
        res.status(500).json({ error: 'Failed to fetch order' });
      }
    });

    app.post('/api/restaurant/orders/:orderId/follow-up', customerAuthRequired, async (req, res) => {
      try {
        await ensureRestaurantOrderWorkflowColumns();
        const { orderId } = req.params;
        const lookup = await restaurantOrderWhereClause(orderId, 1);
        if (!lookup) {
          return res.status(400).json({ error: 'Invalid order id' });
        }

        const existing = await pool.query(
          `SELECT *
           FROM restaurant_orders
           WHERE ${lookup.sql} AND customer_id::text = $2
           LIMIT 1`,
          [lookup.value, req.customer.id],
        );
        if (existing.rowCount === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }

        const order = existing.rows[0];
        const status = String(order.order_status || '').toUpperCase();
        if (status === 'DELIVERED' || status === 'CANCELLED') {
          return res.status(400).json({ error: 'Follow-up is only available for active orders' });
        }

        const last = order.last_customer_followup_at
          ? new Date(order.last_customer_followup_at)
          : null;
        if (last && !Number.isNaN(last.getTime())) {
          const nextAllowedAt = new Date(last.getTime() + 20 * 60 * 1000);
          if (nextAllowedAt > new Date()) {
            return res.status(429).json({
              error: 'Please wait before sending another follow-up',
              nextAllowedAt: nextAllowedAt.toISOString(),
            });
          }
        }

        const updated = await pool.query(
          `UPDATE restaurant_orders
           SET last_customer_followup_at = now(), updated_at = now()
           WHERE id = $1
           RETURNING *`,
          [order.id],
        );
        const updatedOrder = updated.rows[0];
        const followupRecipient =
          process.env.RESTAURANT_FOLLOWUP_EMAIL ||
          process.env.SEED_SUPER_ADMIN_EMAIL ||
          process.env.ADMIN_EMAIL;
        if (followupRecipient) {
          sendCustomerNotificationEmailAsync({
            to: followupRecipient,
            subject: 'Curatering: Customer order follow-up',
            text:
              `A customer requested a follow-up for restaurant order ${updatedOrder.order_id}.\n\n` +
              `Customer: ${updatedOrder.full_name || 'Unknown'}\n` +
              `Status: ${updatedOrder.order_status || 'Unknown'}\n` +
              `Payment status: ${updatedOrder.payment_status || 'pending'}\n\n` +
              `Please review the order in Restaurant Orders.`,
          });
        }

        res.json({
          ok: true,
          nextAllowedAt: new Date(Date.now() + 20 * 60 * 1000).toISOString(),
          order: serializeRestaurantOrderRow(updatedOrder, parseRestaurantOrderTrayItems(updatedOrder)),
        });
      } catch (error) {
        console.error('Error sending restaurant order follow-up:', error);
        res.status(500).json({ error: 'Failed to send follow-up' });
      }
    });

    app.post(
      '/api/restaurant/orders/:orderId/feedback',
      customerAuthRequired,
      async (req, res) => {
        try {
          const { orderId } = req.params;
          const stars = Number(req.body?.stars ?? req.body?.feedback_stars);
          const remarks = String(req.body?.remarks ?? req.body?.feedback_remarks ?? '').trim();

          if (!Number.isFinite(stars) || stars < 1 || stars > 5) {
            return res.status(400).json({ error: 'Rating must be between 1 and 5 stars' });
          }

          const lookup = await restaurantOrderWhereClause(orderId, 1);
          if (!lookup) {
            return res.status(400).json({ error: 'Invalid order id' });
          }

          const existing = await pool.query(
            `SELECT id, customer_id, order_status, feedback_stars
             FROM restaurant_orders WHERE ${lookup.sql} LIMIT 1`,
            [lookup.value],
          );
          if (existing.rowCount === 0) {
            return res.status(404).json({ error: 'Order not found' });
          }
          const order = existing.rows[0];
          if (String(order.customer_id) !== String(req.customer.id)) {
            return res.status(403).json({ error: 'Order not found' });
          }
          if (String(order.order_status).toUpperCase() !== 'DELIVERED') {
            return res.status(400).json({ error: 'Feedback is only available for delivered orders' });
          }
          if (order.feedback_stars != null) {
            return res.status(409).json({ error: 'Feedback was already submitted for this order' });
          }

          const updated = await pool.query(
            `UPDATE restaurant_orders
             SET feedback_stars = $2,
                 feedback_remarks = $3,
                 feedback_submitted_at = now(),
                 updated_at = now()
             WHERE id = $1
             RETURNING *`,
            [order.id, Math.round(stars), remarks || null],
          );

          const parsedItems = parseRestaurantOrderTrayItems(updated.rows[0]);

          res.json({
            ok: true,
            order: serializeRestaurantOrderRow(updated.rows[0], parsedItems),
          });
        } catch (error) {
          console.error('Error saving restaurant order feedback:', error);
          res.status(500).json({ error: 'Failed to save feedback' });
        }
      },
    );

    app.get('/api/restaurant/feedback/:token', async (req, res) => {
      try {
        const payload = jwt.verify(String(req.params.token || ''), JWT_SECRET);
        if (payload?.type !== 'restaurant_feedback' || !payload.orderId) {
          return res.status(400).json({ error: 'Invalid feedback link' });
        }
        const lookup = await restaurantOrderWhereClause(String(payload.orderId), 1);
        if (!lookup) return res.status(400).json({ error: 'Invalid feedback link' });
        const result = await pool.query(
          `SELECT order_id, full_name, order_status, feedback_stars,
                  total_cost, tray_items, created_at, delivery_address
           FROM restaurant_orders
           WHERE ${lookup.sql}
           LIMIT 1`,
          [lookup.value],
        );
        if (result.rowCount === 0) return res.status(404).json({ error: 'Order not found' });
        const order = result.rows[0];
        if (String(order.order_status).toUpperCase() !== 'DELIVERED') {
          return res.status(400).json({ error: 'Feedback is available after delivery' });
        }
        res.json({
          order: {
            order_id: order.order_id,
            full_name: order.full_name,
            total_amount: order.total_cost,
            items: parseRestaurantOrderTrayItems(order),
            created_at: order.created_at,
            delivery_address: order.delivery_address,
            feedback_submitted: order.feedback_stars != null,
          },
        });
      } catch (error) {
        res.status(400).json({ error: 'Invalid or expired feedback link' });
      }
    });

    app.post('/api/restaurant/feedback/:token', async (req, res) => {
      try {
        const payload = jwt.verify(String(req.params.token || ''), JWT_SECRET);
        if (payload?.type !== 'restaurant_feedback' || !payload.orderId) {
          return res.status(400).json({ error: 'Invalid feedback link' });
        }
        const stars = Number(req.body?.stars ?? req.body?.feedback_stars);
        const remarks = String(req.body?.remarks ?? req.body?.feedback_remarks ?? '').trim();
        if (!Number.isFinite(stars) || stars < 1 || stars > 5) {
          return res.status(400).json({ error: 'Rating must be between 1 and 5 stars' });
        }
        const lookup = await restaurantOrderWhereClause(String(payload.orderId), 1);
        if (!lookup) return res.status(400).json({ error: 'Invalid feedback link' });
        const existing = await pool.query(
          `SELECT id, order_status, feedback_stars
           FROM restaurant_orders
           WHERE ${lookup.sql}
           LIMIT 1`,
          [lookup.value],
        );
        if (existing.rowCount === 0) return res.status(404).json({ error: 'Order not found' });
        const order = existing.rows[0];
        if (String(order.order_status).toUpperCase() !== 'DELIVERED') {
          return res.status(400).json({ error: 'Feedback is available after delivery' });
        }
        if (order.feedback_stars != null) {
          return res.status(409).json({ error: 'Feedback was already submitted for this order' });
        }
        await pool.query(
          `UPDATE restaurant_orders
           SET feedback_stars = $2,
               feedback_remarks = $3,
               feedback_submitted_at = now(),
               updated_at = now()
           WHERE id = $1`,
          [order.id, Math.round(stars), remarks || null],
        );
        res.json({ ok: true });
      } catch (error) {
        res.status(400).json({ error: 'Invalid or expired feedback link' });
      }
    });

    app.get('/api/restaurant/orders', customerAuthRequired, async (req, res) => {
      try {
        const roCols = await ensureRestaurantOrdersCanonicalColumns();
        const selectSql = buildRestaurantOrderSelectSql(roCols);

        const acct = await pool.query(
          'SELECT email FROM customer_accounts WHERE id = $1 LIMIT 1',
          [req.customer.id],
        );
        const customerEmail =
          acct.rows[0]?.email != null
            ? String(acct.rows[0].email).trim().toLowerCase()
            : null;

        const emailMatchParts = [];
        if (roCols.has('user_email')) {
          emailMatchParts.push(`lower(COALESCE(user_email::text, '')) = $2`);
        }
        const emailClause =
          customerEmail && emailMatchParts.length > 0
            ? `OR ($2::text IS NOT NULL AND (${emailMatchParts.join(' OR ')}))`
            : '';

        const result = await pool.query(
          `SELECT ${selectSql}
           FROM restaurant_orders
           WHERE customer_id::text = $1 ${emailClause}
           ORDER BY created_at DESC NULLS LAST`,
          customerEmail && emailMatchParts.length > 0
            ? [req.customer.id, customerEmail]
            : [req.customer.id],
        );

        const orders = result.rows.map((order) =>
          serializeRestaurantOrderRow(order, parseRestaurantOrderTrayItems(order)),
        );
        res.json({ orders });
      } catch (error) {
        console.error('Error fetching orders:', error);
        res.status(500).json({ error: 'Failed to fetch orders' });
      }
    });

    // Manager Restaurant Orders endpoints
    app.get('/api/manager/dashboard/summary', managerAuthRequired, async (req, res) => {
      try {
        const now = new Date();
        const year = now.getFullYear();
        const month = now.getMonth() + 1;
        const monthStart = new Date(year, month - 1, 1);
        const nextMonth = new Date(year, month, 1);
        const yearStart = new Date(year, 0, 1);
        const nextYear = new Date(year + 1, 0, 1);
        const parseDate = (raw, fallback) => {
          const d = raw ? new Date(String(raw)) : null;
          return d && !Number.isNaN(d.getTime()) ? d : fallback;
        };
        const rangeStart = parseDate(req.query.start, yearStart);
        const rangeEnd = parseDate(req.query.end, nextYear);
        const restFilters = ['created_at >= $1', 'created_at < $2'];
        const restParams = [rangeStart, rangeEnd];
        const orderSource = String(req.query.orderSource || 'ALL').trim().toUpperCase();
        const orderStatus = String(req.query.orderStatus || 'ALL').trim().toUpperCase();
        const businessSide = String(req.query.businessSide || 'ALL').trim().toUpperCase();
        const cateringStyle = String(req.query.cateringStyle || 'ALL').trim().toUpperCase();
        const includeRestaurant =
          businessSide !== 'CATERING' && businessSide !== 'CATERING_WITH_EVENT';
        const includeCatering = businessSide !== 'RESTAURANT';
        const includeCateringOnly =
          businessSide !== 'CATERING_WITH_EVENT' && cateringStyle !== 'CATERING_WITH_EVENT';
        const includeEventCatering = cateringStyle !== 'CATERING_ONLY';
        const cateringSourceFilter = (() => {
          if (!orderSource || orderSource === 'ALL') return 'TRUE';
          if (orderSource === 'ONLINE' || orderSource === 'WEB_APP') {
            return `lower(coalesce(source, '')) IN ('web', 'web_app', 'new_event', 'online_inquiry', 'customer_website')`;
          }
          if (orderSource === 'MOBILE_APP') {
            return `lower(coalesce(source, '')) IN ('mobile', 'mobile_app', 'customer_mobile')`;
          }
          if (orderSource === 'WALK_IN' || orderSource === 'POS_WEB') {
            return `lower(coalesce(source, '')) IN ('walk_in', 'walk-in', 'pos', 'pos_web', 'staff')`;
          }
          return 'FALSE';
        })();
        const cateringUnionParts = [
          includeCateringOnly
            ? `SELECT status, down_payment_status, full_payment_status, total_cost, created_at, updated_at, source, 'catering' AS style FROM catering_orders`
            : null,
          includeEventCatering
            ? `SELECT status, down_payment_status, full_payment_status, total_cost, created_at, updated_at, source, 'catering_with_event' AS style FROM event_orders`
            : null,
        ].filter(Boolean);
        const cateringUnionSql = cateringUnionParts.length
          ? cateringUnionParts.join(' UNION ALL ')
          : `SELECT NULL::text AS status, NULL::text AS down_payment_status, NULL::text AS full_payment_status, 0::numeric AS total_cost, now() AS created_at, now() AS updated_at, NULL::text AS source, NULL::text AS style WHERE FALSE`;
        const eventOrderCols = await getTableColumnNames('event_orders');
        const cateringOrderCols = await getTableColumnNames('catering_orders');
        const eventPostAnalysisExpr = eventOrderCols.has('post_analysis')
          ? 'post_analysis'
          : `'{}'::jsonb`;
        const cateringPostAnalysisExpr = cateringOrderCols.has('post_analysis')
          ? 'post_analysis'
          : `'{}'::jsonb`;
        if (orderSource && orderSource !== 'ALL') {
          if (orderSource === 'ONLINE') {
            restFilters.push(`order_source IN ('WEB_APP', 'MOBILE_APP')`);
          } else if (orderSource === 'WALK_IN') {
            restFilters.push(`order_source IN ('POS_WEB', 'WALK_IN')`);
          } else {
            restParams.push(orderSource);
            restFilters.push(`order_source = $${restParams.length}`);
          }
        }
        if (orderStatus && orderStatus !== 'ALL') {
          restParams.push(orderStatus);
          restFilters.push(`order_status = $${restParams.length}`);
        }
        const restWhere = `WHERE ${restFilters.join(' AND ')}`;

        const restToday = await pool.query(
          `SELECT
             COUNT(*) FILTER (WHERE order_status = 'PENDING_CASHIER')::int AS pending_confirmations,
             COUNT(*) FILTER (WHERE order_status = 'DELIVERED')::int AS delivered,
             COUNT(*) FILTER (WHERE order_status = 'CANCELLED')::int AS cancelled,
             COALESCE(SUM(total_cost) FILTER (
               WHERE order_status NOT IN ('CANCELLED')
             ), 0)::float AS sales_today,
             COALESCE(SUM(total_cost) FILTER (
               WHERE order_status NOT IN ('CANCELLED')
             ), 0)::float AS sales_year
           FROM restaurant_orders
           ${restWhere}`,
          restParams,
        );
        const r = includeRestaurant ? (restToday.rows[0] || {}) : {};

        const cateringMetrics = await pool.query(
          `SELECT
             COUNT(*) FILTER (
               WHERE status = 'online_inquiries'
                AND created_at >= $1 AND created_at < $2
             )::int AS inquiries_this_month,
             COUNT(*) FILTER (WHERE status IN ('for_down_payment', 'on_going', 'for_full_payment', 'for_processing', 'for_post_analysis'))::int AS accepted_transactions,
             COUNT(*) FILTER (
               WHERE status IN ('for_down_payment', 'for_processing')
                 AND COALESCE(down_payment_status, 'pending') != 'paid'
             )::int AS for_down_payment,
             COUNT(*) FILTER (
               WHERE status IN ('on_going', 'for_processing')
                 AND COALESCE(down_payment_status, 'pending') = 'paid'
                 AND COALESCE(full_payment_status, 'pending') != 'paid'
             )::int AS ongoing,
             COUNT(*) FILTER (
               WHERE status IN ('for_full_payment', 'for_post_analysis')
                 AND COALESCE(down_payment_status, 'pending') = 'paid'
                 AND COALESCE(full_payment_status, 'pending') != 'paid'
             )::int AS for_full_payment,
             COUNT(*) FILTER (WHERE status = 'completed')::int AS completed,
             COUNT(*) FILTER (WHERE status = 'cancelled')::int AS cancelled,
             COALESCE(SUM(total_cost) FILTER (
               WHERE status = 'completed'
                 AND created_at >= date_trunc('day', now())
             ), 0)::float AS sales_today,
             COALESCE(SUM(total_cost) FILTER (
               WHERE status = 'completed'
                 AND created_at >= $1 AND created_at < $2
             ), 0)::float AS sales_year
           FROM (${cateringUnionSql}) combined
           WHERE ${includeCatering ? cateringSourceFilter : 'FALSE'}`,
          [rangeStart, rangeEnd],
        );
        const c = cateringMetrics.rows[0] || {};

        const restaurantSalesYear = Number(r.sales_year) || 0;
        const cateringSalesYear = Number(c.sales_year) || 0;

        const restaurantMonthlyParams = [yearStart, nextYear];
        let restaurantMonthlySourceSql = '';
        if (orderSource && orderSource !== 'ALL') {
          if (orderSource === 'ONLINE') {
            restaurantMonthlySourceSql = `AND order_source IN ('WEB_APP', 'MOBILE_APP')`;
          } else if (orderSource === 'WALK_IN') {
            restaurantMonthlySourceSql = `AND order_source IN ('POS_WEB', 'WALK_IN')`;
          } else {
            restaurantMonthlyParams.push(orderSource);
            restaurantMonthlySourceSql = `AND order_source = $${restaurantMonthlyParams.length}`;
          }
        }
        const restaurantMonthlySales = await pool.query(
          `SELECT
             EXTRACT(MONTH FROM created_at)::int AS month,
             COUNT(*)::int AS orders,
             COALESCE(SUM(total_cost), 0)::float AS sales
           FROM restaurant_orders
           WHERE order_status NOT IN ('CANCELLED')
             AND created_at >= $1 AND created_at < $2
             ${restaurantMonthlySourceSql}
             ${orderStatus && orderStatus !== 'ALL' ? `AND order_status = $${restaurantMonthlyParams.length + 1}` : ''}
           GROUP BY 1
           ORDER BY 1`,
          [
            ...restaurantMonthlyParams,
            ...(orderStatus && orderStatus !== 'ALL' ? [orderStatus] : []),
          ],
        );

        const cateringMonthlySales = await pool.query(
          `SELECT
             EXTRACT(MONTH FROM created_at)::int AS month,
             COUNT(*)::int AS orders,
             COALESCE(SUM(total_cost) FILTER (WHERE status = 'completed'), 0)::float AS sales
           FROM (${cateringUnionSql}) combined
           WHERE status != 'cancelled'
             AND created_at >= $1 AND created_at < $2
             AND ${includeCatering ? cateringSourceFilter : 'FALSE'}
           GROUP BY 1
           ORDER BY 1`,
          [yearStart, nextYear],
        );

        const restaurantFeedback = await pool.query(
          `SELECT
             COUNT(*)::int AS count,
             COALESCE(AVG(feedback_stars), 0)::float AS average_stars,
             COUNT(*) FILTER (WHERE feedback_stars >= 4)::int AS positive_count,
             COUNT(*) FILTER (WHERE feedback_stars = 3)::int AS neutral_count,
             COUNT(*) FILTER (WHERE feedback_stars <= 2)::int AS negative_count
           FROM restaurant_orders
           WHERE feedback_stars IS NOT NULL
             AND COALESCE(feedback_submitted_at, updated_at, created_at) >= $1
             AND COALESCE(feedback_submitted_at, updated_at, created_at) < $2`,
          [rangeStart, rangeEnd],
        );

        const cateringFeedback = await pool.query(
          `SELECT
             COUNT(*) FILTER (WHERE complaints > 0)::int AS count,
             COALESCE(SUM(complaints), 0)::int AS complaint_count
           FROM (
             SELECT COALESCE((${eventPostAnalysisExpr}->>'complaints')::int, 0) AS complaints,
                    COALESCE(updated_at, created_at) AS feedback_at,
                    source
             FROM event_orders
             ${includeEventCatering ? '' : 'WHERE FALSE'}
             UNION ALL
             SELECT COALESCE((${cateringPostAnalysisExpr}->>'complaints')::int, 0) AS complaints,
                    COALESCE(updated_at, created_at) AS feedback_at,
                    source
             FROM catering_orders
             ${includeCateringOnly ? '' : 'WHERE FALSE'}
           ) feedback
           WHERE feedback_at >= $1 AND feedback_at < $2
             AND ${includeCatering ? cateringSourceFilter : 'FALSE'}`,
          [rangeStart, rangeEnd],
        );
        const rf = restaurantFeedback.rows[0] || {};
        const cf = cateringFeedback.rows[0] || {};

        const monthly = Array.from({ length: 12 }, (_, i) => ({
          month: i + 1,
          restaurantSales: 0,
          restaurantOrders: 0,
          cateringSales: 0,
          cateringOrders: 0,
        }));
        if (includeRestaurant) for (const row of restaurantMonthlySales.rows) {
          const idx = Number(row.month) - 1;
          if (idx >= 0 && idx < 12) {
            monthly[idx].restaurantSales = Number(row.sales) || 0;
            monthly[idx].restaurantOrders = Number(row.orders) || 0;
          }
        }
        if (includeCatering) for (const row of cateringMonthlySales.rows) {
          const idx = Number(row.month) - 1;
          if (idx >= 0 && idx < 12) {
            monthly[idx].cateringSales = Number(row.sales) || 0;
            monthly[idx].cateringOrders = Number(row.orders) || 0;
          }
        }

        res.json({
          restaurant: {
            pendingConfirmations: Number(r.pending_confirmations) || 0,
            delivered: Number(r.delivered) || 0,
            cancelled: Number(r.cancelled) || 0,
            salesToday: Number(r.sales_today) || 0,
            salesThisYear: restaurantSalesYear,
            feedback: {
              count: Number(rf.count) || 0,
              averageStars: Number(rf.average_stars) || 0,
              positiveCount: Number(rf.positive_count) || 0,
              neutralCount: Number(rf.neutral_count) || 0,
              negativeCount: Number(rf.negative_count) || 0,
              complaintCount: 0,
            },
          },
          catering: {
            inquiriesThisMonth: Number(c.inquiries_this_month) || 0,
            acceptedTransactions: Number(c.accepted_transactions) || 0,
            forDownPayment: Number(c.for_down_payment) || 0,
            ongoing: Number(c.ongoing) || 0,
            forFullPayment: Number(c.for_full_payment) || 0,
            completed: Number(c.completed) || 0,
            cancelled: Number(c.cancelled) || 0,
            salesToday: Number(c.sales_today) || 0,
            salesThisYear: cateringSalesYear,
            feedback: {
              count: Number(cf.count) || 0,
              averageStars: 0,
              positiveCount: 0,
              neutralCount: 0,
              negativeCount: Number(cf.count) || 0,
              complaintCount: Number(cf.complaint_count) || 0,
            },
          },
          salesThisYear: {
            restaurant: restaurantSalesYear,
            catering: cateringSalesYear,
            all: restaurantSalesYear + cateringSalesYear,
          },
          monthlySales: monthly.map((m) => ({
            ...m,
            totalSales: m.restaurantSales + m.cateringSales,
            totalOrders: m.restaurantOrders + m.cateringOrders,
          })),
        });
      } catch (e) {
        console.error('dashboard summary', e);
        res.status(500).json({ error: 'Failed to load dashboard summary' });
      }
    });

    app.get('/api/manager/reports/summary', managerAuthRequired, async (req, res) => {
      try {
        const now = new Date();
        const year = Number(req.query.year) || now.getFullYear();
        const month = Number(req.query.month) || now.getMonth() + 1;
        const periodStart = new Date(year, month - 1, 1);
        const periodEnd = new Date(year, month, 1);
        const annual = String(req.query.annual || '') === '1';
        const rangeStart = annual ? new Date(year, 0, 1) : periodStart;
        const rangeEnd = annual ? new Date(year + 1, 0, 1) : periodEnd;

        const roCols = await getTableColumnNames('restaurant_orders');
        const roTotalCol = roCols.has('total_cost') ? 'total_cost' : '0';
        const roStatusCol = roCols.has('order_status')
          ? 'order_status'
          : roCols.has('status')
            ? 'status'
            : null;
        const roItemsCol = roCols.has('tray_items') ? 'tray_items' : null;
        const roStatusFilter = roStatusCol
          ? `AND upper(COALESCE(${roStatusCol}::text, '')) NOT IN ('CANCELLED')`
          : '';
        const roItemsSelect = roItemsCol ? `${roItemsCol} AS items` : "'[]'::jsonb AS items";
        const eventOrderCols = await getTableColumnNames('event_orders');
        const cateringOrderCols = await getTableColumnNames('catering_orders');
        const eventPostAnalysisExpr = eventOrderCols.has('post_analysis')
          ? 'post_analysis'
          : `'{}'::jsonb`;
        const cateringPostAnalysisExpr = cateringOrderCols.has('post_analysis')
          ? 'post_analysis'
          : `'{}'::jsonb`;

        const eventOrders = await pool.query(
          `SELECT event_type, guest_count, menu, total_cost, schedule_slots, status, customer_name,
                  COALESCE(event_title, '') AS event_title, created_at
           FROM event_orders
           WHERE status = 'completed' AND created_at >= $1 AND created_at < $2`,
          [rangeStart, rangeEnd],
        );

        const cateringOrders = await pool.query(
          `SELECT 'Catering' AS event_type, guest_count, menu, total_cost, schedule_slots, status, customer_name,
                  '' AS event_title, created_at
           FROM catering_orders
           WHERE status = 'completed' AND created_at >= $1 AND created_at < $2`,
          [rangeStart, rangeEnd],
        );

        function aggregateCateringRows(rows) {
          let totalSales = 0;
          let guestTotal = 0;
          let guestCountN = 0;
          const dishCounts = {};
          const eventTypeCounts = {};
          for (const row of rows) {
            totalSales += Number(row.total_cost) || 0;
            const gc = Number(row.guest_count) || 0;
            if (gc > 0) {
              guestTotal += gc;
              guestCountN += 1;
            }
            const et = String(row.event_type || 'Unspecified').trim() || 'Unspecified';
            eventTypeCounts[et] = (eventTypeCounts[et] || 0) + 1;
            let menu = row.menu;
            if (typeof menu === 'string') {
              try { menu = JSON.parse(menu); } catch { menu = []; }
            }
            if (Array.isArray(menu)) {
              for (const item of menu) {
                const name = String(item?.dishName || item?.dish_name || 'Unknown').trim() || 'Unknown';
                dishCounts[name] = (dishCounts[name] || 0) + 1;
              }
            }
          }
          return { totalSales, guestTotal, guestCountN, dishCounts, eventTypeCounts };
        }
        const cateringOnlyMetrics = aggregateCateringRows(cateringOrders.rows);
        const cateringEventsMetrics = aggregateCateringRows(eventOrders.rows);

        const restaurantOrders = await pool.query(
          `SELECT ${roItemsSelect}, ${roTotalCol} AS total_amount, created_at
                  ${roStatusCol ? `, ${roStatusCol} AS status` : ''}
           FROM restaurant_orders
           WHERE created_at >= $1 AND created_at < $2
             ${roStatusFilter}`,
          [rangeStart, rangeEnd],
        );

        const dishCountsRest = {};
        let restaurantSales = 0;
        const daysWithOrders = new Set();
        for (const row of restaurantOrders.rows) {
          restaurantSales += Number(row.total_amount) || 0;
          const day = row.created_at?.toISOString?.()?.slice(0, 10);
          if (day) daysWithOrders.add(day);
          let items = row.items;
          if (typeof items === 'string') {
            try { items = JSON.parse(items); } catch { items = []; }
          }
          if (Array.isArray(items)) {
            for (const item of items) {
              const name = String(item?.name || item?.dishName || 'Unknown').trim() || 'Unknown';
              const qty = Number(item?.quantity) || 1;
              dishCountsRest[name] = (dishCountsRest[name] || 0) + qty;
            }
          }
        }

        const daySpan = Math.max(
          1,
          Math.ceil((rangeEnd - rangeStart) / (24 * 60 * 60 * 1000)),
        );
        const avgOrdersPerDay = restaurantOrders.rowCount / daySpan;

        let webViews = 0;
        let mobileViews = 0;
        const trafficCols = await getTableColumnNames('site_page_views');
        if (trafficCols.size > 0 && trafficCols.has('platform')) {
          const traffic = await pool.query(
            `SELECT platform, COUNT(*)::int AS views
             FROM site_page_views
             WHERE created_at >= $1 AND created_at < $2
             GROUP BY platform`,
            [rangeStart, rangeEnd],
          );
          for (const t of traffic.rows) {
            if (t.platform === 'mobile') mobileViews = Number(t.views) || 0;
            else webViews += Number(t.views) || 0;
          }
        }

        let accountsWeb = 0;
        let accountsMobile = 0;
        const caCols = await getTableColumnNames('customer_accounts');
        if (caCols.has('registration_platform')) {
          const archivedFilter = caCols.has('archived') ? 'AND archived = FALSE' : '';
          const accounts = await pool.query(
            `SELECT registration_platform, COUNT(*)::int AS n
             FROM customer_accounts
             WHERE is_verified = TRUE ${archivedFilter}
               AND created_at >= $1 AND created_at < $2
             GROUP BY registration_platform`,
            [rangeStart, rangeEnd],
          );
          for (const a of accounts.rows) {
            if (a.registration_platform === 'mobile') {
              accountsMobile = Number(a.n) || 0;
            } else {
              accountsWeb += Number(a.n) || 0;
            }
          }
        }

        const topDishes = Object.entries(cateringOnlyMetrics.dishCounts)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 15)
          .map(([name, count]) => ({ name, count }));
        const topEventTypes = Object.entries(cateringEventsMetrics.eventTypeCounts)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 15)
          .map(([name, count]) => ({ name, count }));
        const topRestaurantDishes = Object.entries(dishCountsRest)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 15)
          .map(([name, count]) => ({ name, count }));

        const restaurantFeedback = await pool.query(
          `SELECT
             COUNT(*)::int AS count,
             COALESCE(AVG(feedback_stars), 0)::float AS average_stars,
             COUNT(*) FILTER (WHERE feedback_stars >= 4)::int AS positive_count,
             COUNT(*) FILTER (WHERE feedback_stars = 3)::int AS neutral_count,
             COUNT(*) FILTER (WHERE feedback_stars <= 2)::int AS negative_count
           FROM restaurant_orders
           WHERE feedback_stars IS NOT NULL
             AND COALESCE(feedback_submitted_at, updated_at, created_at) >= $1
             AND COALESCE(feedback_submitted_at, updated_at, created_at) < $2`,
          [rangeStart, rangeEnd],
        );
        const cateringFeedback = await pool.query(
          `SELECT
             COUNT(*) FILTER (WHERE complaints > 0)::int AS count,
             COALESCE(SUM(complaints), 0)::int AS complaint_count
           FROM (
             SELECT COALESCE((${eventPostAnalysisExpr}->>'complaints')::int, 0) AS complaints,
                    COALESCE(updated_at, created_at) AS feedback_at
             FROM event_orders
             UNION ALL
             SELECT COALESCE((${cateringPostAnalysisExpr}->>'complaints')::int, 0) AS complaints,
                    COALESCE(updated_at, created_at) AS feedback_at
             FROM catering_orders
           ) feedback
           WHERE feedback_at >= $1 AND feedback_at < $2`,
          [rangeStart, rangeEnd],
        );
        const rf = restaurantFeedback.rows[0] || {};
        const cf = cateringFeedback.rows[0] || {};

        res.json({
          period: { year, month: annual ? null : month, annual },
          catering: {
            orderCount: cateringOrders.rowCount,
            totalSales: cateringOnlyMetrics.totalSales,
            averageGuestCount: cateringOnlyMetrics.guestCountN > 0
              ? cateringOnlyMetrics.guestTotal / cateringOnlyMetrics.guestCountN
              : 0,
            topDishes,
            topEventTypes: [],
            feedback: {
              count: Number(cf.count) || 0,
              averageStars: 0,
              positiveCount: 0,
              neutralCount: 0,
              negativeCount: Number(cf.count) || 0,
              complaintCount: Number(cf.complaint_count) || 0,
            },
          },
          cateringEvents: {
            orderCount: eventOrders.rowCount,
            totalSales: cateringEventsMetrics.totalSales,
            averageGuestCount: cateringEventsMetrics.guestCountN > 0
              ? cateringEventsMetrics.guestTotal / cateringEventsMetrics.guestCountN
              : 0,
            topDishes: [],
            topEventTypes,
            feedback: {
              count: Number(cf.count) || 0,
              averageStars: 0,
              positiveCount: 0,
              neutralCount: 0,
              negativeCount: Number(cf.count) || 0,
              complaintCount: Number(cf.complaint_count) || 0,
            },
          },
          restaurant: {
            orderCount: restaurantOrders.rowCount,
            totalSales: restaurantSales,
            averageOrdersPerDay: avgOrdersPerDay,
            webPageViews: webViews,
            mobilePageViews: mobileViews,
            customerAccountsWeb: accountsWeb,
            customerAccountsMobile: accountsMobile,
            topDishes: topRestaurantDishes,
            feedback: {
              count: Number(rf.count) || 0,
              averageStars: Number(rf.average_stars) || 0,
              positiveCount: Number(rf.positive_count) || 0,
              neutralCount: Number(rf.neutral_count) || 0,
              negativeCount: Number(rf.negative_count) || 0,
              complaintCount: 0,
            },
          },
        });
      } catch (e) {
        console.error('reports summary', e);
        res.status(500).json({ error: 'Failed to load report summary' });
      }
    });

    // Get all restaurant orders for managers
    app.get('/api/manager/restaurant/orders', managerAuthRequired, async (req, res) => {
      const startTime = Date.now();
      try {
        const { status, limit = 50 } = req.query;
        const roCols = await ensureRestaurantOrdersCanonicalColumns();
        const selectSql = buildRestaurantOrderSelectSql(roCols);
        const statusCol = roCols.has('order_status')
          ? 'order_status'
          : roCols.has('status')
            ? 'status'
            : 'order_status';

        let query = `
          SELECT ${selectSql}
          FROM restaurant_orders
          ORDER BY created_at DESC NULLS LAST
          LIMIT $1
        `;
        let params = [limit];

        if (status) {
          const statusValues = status.split(',');
          if (statusValues.length === 1) {
            query = `
              SELECT ${selectSql}
              FROM restaurant_orders
              WHERE ${statusCol} = $1
              ORDER BY created_at DESC NULLS LAST
              LIMIT $2
            `;
            params = [statusValues[0], limit];
          } else {
            query = `
              SELECT ${selectSql}
              FROM restaurant_orders
              WHERE ${statusCol} IN (${statusValues.map((_, i) => `$${i + 1}`).join(', ')})
              ORDER BY created_at DESC NULLS LAST
              LIMIT $${statusValues.length + 1}
            `;
            params = [...statusValues, limit];
          }
        }

        // Add retry logic for connection issues
        let result;
        let retries = 0;
        const maxRetries = 3;
        
        while (retries < maxRetries) {
          try {
            result = await pool.query(query, params);
            break; // Success, exit retry loop
          } catch (error) {
            retries++;
            console.log(`Restaurant orders query attempt ${retries} failed:`, error.message);
            
            if (retries >= maxRetries) {
              throw error; // Re-throw after max retries
            }
            
            // Wait before retry (exponential backoff)
            await new Promise(resolve => setTimeout(resolve, Math.pow(2, retries) * 100));
          }
        }
        
        const processedOrders = result.rows.map((order) =>
          serializeRestaurantOrderRow(order, parseRestaurantOrderTrayItems(order), 'staff'),
        );
        
        const endTime = Date.now();
        console.log(`Restaurant orders query took ${endTime - startTime}ms for ${processedOrders.length} orders`);
        
        res.json({ orders: processedOrders });
      } catch (error) {
        console.error('Error fetching restaurant orders after retries:', error);
        
        // Provide more specific error messages
        let errorMessage = 'Failed to fetch orders';
        if (error.message.includes('Connection terminated')) {
          errorMessage = 'Database connection error. Please try again.';
        } else if (error.message.includes('timeout')) {
          errorMessage = 'Request timed out. Please try again.';
        }
        
        res.status(500).json({ error: errorMessage });
      }
    });

    // Update restaurant order status
    app.put('/api/manager/restaurant/orders/:orderId', managerAuthRequired, async (req, res) => {
      try {
        const { orderId } = req.params;
        const { status, delivery_tracking_url, payment_status } = req.body || {};
        const deliveryUrl = String(delivery_tracking_url || '').trim();
        const hasDeliveryUrl = deliveryUrl.length > 0;
        
        const updateFields = [];
        const updateValues = [];
        let paramIndex = 1;
        let nextStatus = null;

        if (status) {
          const normalizedStatus = String(status).trim().toUpperCase();
          const allowedStatuses = [
            'PENDING_CASHIER',
            'IN_PREPARATION',
            'OUT_FOR_DELIVERY',
            'DELIVERED',
            'CANCELLED',
          ];
          if (!allowedStatuses.includes(normalizedStatus)) {
            return res.status(400).json({
              error: `Invalid status: ${status}. Allowed: ${allowedStatuses.join(', ')}`,
            });
          }
          nextStatus = normalizedStatus;
        }

        if (hasDeliveryUrl) {
          updateFields.push(`delivery_tracking_url = $${paramIndex++}`);
          updateValues.push(deliveryUrl);
          nextStatus = 'OUT_FOR_DELIVERY';
        }

        if (nextStatus) {
          updateFields.push(`order_status = $${paramIndex++}`);
          updateValues.push(nextStatus);
        }
        
        if (payment_status === 'paid' || payment_status === 'confirmed') {
          updateFields.push(`payment_confirmed_initial = TRUE`);
        }
        
        updateFields.push(`updated_at = now()`);

        const lookup = await restaurantOrderWhereClause(orderId, paramIndex);
        if (!lookup) {
          return res.status(400).json({ error: 'Invalid order id' });
        }
        updateValues.push(lookup.value);

        const query = `
          UPDATE restaurant_orders 
          SET ${updateFields.join(', ')}
          WHERE ${lookup.sql}
          RETURNING *
        `;

        const result = await pool.query(query, updateValues);
        
        if (result.rowCount === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }

        const effectiveStatus = nextStatus;

        // Auto-calculate loyalty points when order is delivered
        if (effectiveStatus === 'DELIVERED') {
          const order = result.rows[0];
          const customerId = order.customer_id;
          const totalAmount = parseFloat(order.total_cost || 0);
          
          // Default restaurant loyalty points: 100 min order to earn 2 points (2% rate)
          const minimumCost = 100.0;
          const pointsApplication = 2; // 2% of total cost
          
          if (totalAmount >= minimumCost) {
            // Calculate points with rounding rule: .2-.6 down, .7-.9 up
            const rawPoints = (totalAmount * pointsApplication) / 100;
            const decimal = rawPoints % 1;
            let points = Math.floor(rawPoints);
            
            if (decimal >= 0.7) {
              points += 1;
            }
            
            // Update order with calculated points
            const pointsLookup = await restaurantOrderWhereClause(orderId, 2);
            if (pointsLookup) {
              await pool.query(
                `UPDATE restaurant_orders
                 SET loyalty_points_restaurant_obtained = $1
                 WHERE ${pointsLookup.sql}`,
                [points, pointsLookup.value],
              );
            }
            
            // Update customer's total loyalty points
            await pool.query(
              `UPDATE customer_accounts 
               SET restaurant_loyalty_points = restaurant_loyalty_points + $1,
                   updated_at = now()
               WHERE id = $2`,
              [points, customerId]
            );
          }
        }

        const updatedOrder = result.rows[0];
        const notifyEmail = await resolveRestaurantOrderEmail(updatedOrder);
        if (notifyEmail) {
          const feedbackText = effectiveStatus === 'DELIVERED'
            ? `\nYour order is complete. Share quick feedback here: ${restaurantFeedbackLink(updatedOrder)}\n` +
              `Registered customers can also open My Orders to review the order and feedback form.\n`
            : '';
          await sendCustomerNotificationEmail({
            to: notifyEmail,
            subject: "Curatering: Restaurant order status updated",
            text:
              `Hello ${updatedOrder.full_name || "Customer"},\n\n` +
              `Your restaurant order (${orderId}) has a status update.\n` +
              `${effectiveStatus ? `New status: ${effectiveStatus}\n` : ""}` +
              `${payment_status ? `Payment review: ${payment_status}\n` : ""}` +
              feedbackText +
              `\n` +
              `- Curatering Team`,
          });
        }

        const out = result.rows[0];
        if (out?.order_status != null) out.status = out.order_status;
        res.json({ order: out });
      } catch (error) {
        console.error('Error updating restaurant order:', error);
        res.status(500).json({ error: 'Failed to update order' });
      }
    });

    function managerRestaurantOrderIdFromRequest(req) {
      for (const value of [
        req.params?.orderId,
        req.body?.id,
        req.body?.orderId,
        req.body?.order_id,
        req.body?.order_no,
        req.body?.orderNo,
        req.body?.manager_order_id,
        req.body?.restaurant_order_id,
      ]) {
        const s = String(value ?? '').trim();
        if (s && s.toLowerCase() !== 'null' && s.toLowerCase() !== 'undefined') {
          return s;
        }
      }
      return '';
    }

    const confirmRestaurantOrderPayment = async (req, res) => {
      try {
        const orderId = managerRestaurantOrderIdFromRequest(req);
        if (!orderId) {
          return res.status(400).json({ error: 'orderId is required' });
        }

        const { amountPaid } = req.body || {};
        const paid = Number(amountPaid);
        if (!Number.isFinite(paid) || paid <= 0) {
          return res.status(400).json({ error: 'amountPaid is required' });
        }

        const lookup = await restaurantOrderWhereClause(orderId, 1);
        if (!lookup) {
          return res.status(400).json({ error: 'Invalid order id' });
        }
        const existing = await pool.query(
          `SELECT * FROM restaurant_orders WHERE ${lookup.sql} LIMIT 1`,
          [lookup.value],
        );
        if (existing.rowCount === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }
        const order = existing.rows[0];
        const total = Number(order.total_cost || 0);
        if (paid < total) {
          return res.status(400).json({
            error: 'insufficient_payment',
            total,
            amountPaid: paid,
            shortfall: Number((total - paid).toFixed(2)),
          });
        }

        const changeGiven = Number((paid - total).toFixed(2));
        const confirmLookup = await restaurantOrderWhereClause(orderId, 3);
        if (!confirmLookup) {
          return res.status(400).json({ error: 'Invalid order id' });
        }
        const result = await pool.query(
          `UPDATE restaurant_orders
           SET amount_paid = $1,
               change_given = $2,
               payment_confirmed_initial = TRUE,
               order_status = 'IN_PREPARATION',
               cashier_amount_received_initial = $1,
               updated_at = now()
           WHERE ${confirmLookup.sql}
           RETURNING *`,
          [paid, changeGiven, confirmLookup.value],
        );

        const updated = result.rows[0];
        const email = await resolveRestaurantOrderEmail(updated);
        if (email) {
          await sendCustomerNotificationEmail({
            to: email,
            subject: 'Curatering: Payment confirmed',
            text:
              `Your payment for order ${updated.order_id} was confirmed.\n` +
              `Your order is now being prepared.\n\n` +
              `- Curatering Team`,
          });
        }

        if (updated?.order_status != null) updated.status = updated.order_status;
        res.json({ order: updated, changeGiven });
      } catch (error) {
        console.error('confirm-payment:', error);
        res.status(500).json({ error: 'Failed to confirm payment' });
      }
    };

    app.post(
      '/api/manager/restaurant/orders//confirm-payment',
      managerAuthRequired,
      confirmRestaurantOrderPayment,
    );
    app.post(
      '/api/manager/restaurant/orders/confirm-payment',
      managerAuthRequired,
      confirmRestaurantOrderPayment,
    );
    app.post(
      '/api/manager/restaurant/orders/:orderId/confirm-payment',
      managerAuthRequired,
      confirmRestaurantOrderPayment,
    );

    const notifyInsufficientRestaurantPayment = async (req, res) => {
      try {
        const orderId = managerRestaurantOrderIdFromRequest(req);
        if (!orderId) {
          return res.status(400).json({ error: 'orderId is required' });
        }

        const { amountPaid, message } = req.body || {};
        const lookup = await restaurantOrderWhereClause(orderId, 1);
        if (!lookup) {
          return res.status(400).json({ error: 'Invalid order id' });
        }
        const existing = await pool.query(
          `SELECT * FROM restaurant_orders WHERE ${lookup.sql} LIMIT 1`,
          [lookup.value],
        );
        if (existing.rowCount === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }
        const order = existing.rows[0];
        const email = await resolveRestaurantOrderEmail(order);
        if (!email) {
          return res.status(400).json({ error: 'No email on file for this order' });
        }
        const total = Number(order.total_cost || 0);
        const paid = Number(amountPaid ?? 0);
        await sendCustomerNotificationEmail({
          to: email,
          subject: 'Curatering: Payment issue on your order',
          text:
            (message ||
              `We could not confirm payment for order ${order.order_id}.\n` +
                `Order total: PHP ${total.toFixed(2)}\n` +
                `Amount received: PHP ${paid.toFixed(2)}\n` +
                `Please submit the correct payment or contact us.\n`) +
            `\n\n- Curatering Team`,
        });
        res.json({ ok: true });
      } catch (error) {
        console.error('notify-insufficient-payment:', error);
        res.status(500).json({ error: 'Failed to send notification' });
      }
    };

    app.post(
      '/api/manager/restaurant/orders//notify-insufficient-payment',
      managerAuthRequired,
      notifyInsufficientRestaurantPayment,
    );
    app.post(
      '/api/manager/restaurant/orders/notify-insufficient-payment',
      managerAuthRequired,
      notifyInsufficientRestaurantPayment,
    );
    app.post(
      '/api/manager/restaurant/orders/:orderId/notify-insufficient-payment',
      managerAuthRequired,
      notifyInsufficientRestaurantPayment,
    );

    app.post(
      '/api/manager/restaurant/orders/:orderId/cancel',
      managerAuthRequired,
      async (req, res) => {
        try {
          const { orderId } = req.params;
          const lookup = await restaurantOrderWhereClause(orderId, 1);
          const result = await pool.query(
            `UPDATE restaurant_orders
             SET order_status = 'CANCELLED', updated_at = now()
             WHERE ${lookup.sql}
             RETURNING *`,
            [lookup.value],
          );
          if (result.rowCount === 0) {
            return res.status(404).json({ error: 'Order not found' });
          }
          const order = result.rows[0];
          if (order.order_status != null) order.status = order.order_status;
          const email = await resolveRestaurantOrderEmail(order);
          if (email) {
            await sendCustomerNotificationEmail({
              to: email,
              subject: 'Curatering: Order cancelled',
              text:
                `Your order ${order.order_id} has been cancelled.\n\n` +
                `- Curatering Team`,
            });
          }
          res.json({ order });
        } catch (error) {
          console.error('cancel restaurant order:', error);
          res.status(500).json({ error: 'Failed to cancel order' });
        }
      },
    );

    const inventoryRowToJson = (row) => {
      const qty = Number(row.quantity ?? 0);
      const min = row.min_stock_level != null ? Number(row.min_stock_level) : 0;
      return {
        id: row.id,
        itemCode: row.item_code,
        name: row.item_name,
        category: row.category,
        quantity: qty,
        unitCost: row.unit_cost != null ? Number(row.unit_cost) : 0,
        unit: row.unit,
        notes: row.description,
        lastUpdated: row.updated_at,
        lowStock: min > 0 ? qty <= min : false,
        available: String(row.status || 'active').toLowerCase() === 'active',
        status: row.status || 'active',
        archived: row.archived === true,
      };
    };

    app.get('/api/inventory', authRequired, async (req, res) => {
      try {
        const archived = req.query.archived === 'true' || req.query.archived === '1';
        const r = await pool.query(
          `SELECT * FROM inventory WHERE archived = $1 ORDER BY item_name ASC`,
          [archived]
        );
        res.json({ items: r.rows.map(inventoryRowToJson) });
      } catch (e) {
        console.error('inventory list', e);
        res.status(500).json({ error: 'Failed to load inventory' });
      }
    });

    app.post('/api/inventory', authRequired, async (req, res) => {
      try {
        const b = req.body || {};
        const name = (b.name || '').toString().trim();
        const category = (b.category || '').toString().trim();
        if (!name || !category) {
          return res.status(400).json({ error: 'Name and category are required' });
        }
        const quantity = Number(b.quantity) || 0;
        const unit = (b.unit || 'pcs').toString().trim();
        const unitCost = b.unitCost != null && b.unitCost !== '' ? Number(b.unitCost) : null;
        const notes = b.notes != null ? String(b.notes) : null;
        const minStock = b.minStockLevel != null ? Number(b.minStockLevel) : 0;
        const status = b.available === false ? 'inactive' : 'active';
        const existing = await pool.query(
          `SELECT *
           FROM inventory
           WHERE archived = FALSE
             AND lower(trim(item_name)) = lower(trim($1))
             AND lower(trim(category)) = lower(trim($2))
           LIMIT 1`,
          [name, category],
        );
        if (existing.rowCount > 0) {
          return res.status(409).json({
            error: 'Inventory item already exists',
            item: inventoryRowToJson(existing.rows[0]),
          });
        }
        const itemCode = await generateSequentialId('ITM', 4);
        const r = await pool.query(
          `INSERT INTO inventory (item_code, item_name, description, category, quantity, unit, unit_cost, min_stock_level, status, archived)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,FALSE) RETURNING *`,
          [itemCode, name, notes, category, quantity, unit, unitCost, minStock, status],
        );
        res.status(201).json({ item: inventoryRowToJson(r.rows[0]) });
      } catch (e) {
        console.error('inventory create', e);
        res.status(500).json({ error: 'Failed to create inventory item' });
      }
    });

    app.put('/api/inventory/:id', authRequired, async (req, res) => {
      try {
        const { id } = req.params;
        const b = req.body || {};
        const name = (b.name || '').toString().trim();
        const category = (b.category || '').toString().trim();
        if (!name || !category) {
          return res.status(400).json({ error: 'Name and category are required' });
        }
        const quantity = Number(b.quantity) || 0;
        const unit = (b.unit || 'pcs').toString().trim();
        const unitCost = b.unitCost != null && b.unitCost !== '' ? Number(b.unitCost) : null;
        const notes = b.notes != null ? String(b.notes) : null;
        const minStock = b.minStockLevel != null ? Number(b.minStockLevel) : 0;
        const status = b.available === false ? 'inactive' : 'active';
        const r = await pool.query(
          `UPDATE inventory SET
            item_name = $1,
            description = $2,
            category = $3,
            quantity = $4,
            unit = $5,
            unit_cost = $6,
            min_stock_level = $7,
            status = $8,
            updated_at = now()
           WHERE id = $9::uuid AND archived = FALSE
           RETURNING *`,
          [name, notes, category, quantity, unit, unitCost, minStock, status, id],
        );
        if (r.rowCount === 0) {
          return res.status(404).json({ error: 'Item not found or is archived' });
        }
        res.json({ item: inventoryRowToJson(r.rows[0]) });
      } catch (e) {
        console.error('inventory update', e);
        res.status(500).json({ error: 'Failed to update inventory item' });
      }
    });

    app.post('/api/inventory/:id/archive', authRequired, async (req, res) => {
      try {
        const { id } = req.params;
        const archived = (req.body || {}).archived === true;
        const r = await pool.query(
          `UPDATE inventory SET archived = $1, updated_at = now() WHERE id = $2::uuid RETURNING *`,
          [archived, id],
        );
        if (r.rowCount === 0) {
          return res.status(404).json({ error: 'Item not found' });
        }
        res.json({ item: inventoryRowToJson(r.rows[0]) });
      } catch (e) {
        console.error('inventory archive', e);
        res.status(500).json({ error: 'Failed to archive inventory item' });
      }
    });

    app.delete('/api/inventory/:id', authRequired, async (req, res) => {
      try {
        const { id } = req.params;
        const r = await pool.query(
          `DELETE FROM inventory WHERE id = $1::uuid AND archived = TRUE`,
          [id],
        );
        if (r.rowCount === 0) {
          return res.status(400).json({
            error: 'Item not found, or delete is only allowed for archived items.',
          });
        }
        res.json({ ok: true });
      } catch (e) {
        console.error('inventory delete', e);
        res.status(500).json({ error: 'Failed to delete inventory item' });
      }
    });

    // Get customer event/catering orders
    app.get('/api/customer/events/orders', customerAuthRequired, async (req, res) => {
      try {
        await ensureOrderCateringIdColumns();
        await ensureCateringEventOrdersCanonicalColumns();
        const customerId = req.customer.id;
        const customerResult = await pool.query(
          `SELECT email FROM customer_accounts WHERE id = $1 LIMIT 1;`,
          [customerId]
        );
        if (customerResult.rowCount === 0) {
          return res.status(404).json({ error: 'Customer not found' });
        }
        const customerEmail = customerResult.rows[0].email;

        const eventCols = await getTableColumnNames('event_orders');
        const cateringCols = await getTableColumnNames('catering_orders');
        const unionSql = buildCustomerCateringOrdersSql(eventCols, cateringCols);

        const result = await pool.query(unionSql, [customerEmail]);

        const orders = result.rows.map((row) => normalizeCustomerCateringOrderRow(row));
        res.json({ orders });
      } catch (error) {
        console.error('Error fetching customer event orders:', error);
        res.status(500).json({ error: 'Failed to fetch event orders' });
      }
    });

    app.get(
      '/api/customer/events/orders/:orderId/seating',
      customerAuthRequired,
      async (req, res) => {
        try {
          const customerId = req.customer.id;
          const { orderId } = req.params;
          const cr = await pool.query(
            `SELECT email FROM customer_accounts WHERE id = $1 LIMIT 1`,
            [customerId],
          );
          if (cr.rowCount === 0) {
            return res.status(404).json({ error: 'Customer not found' });
          }
          const email = cr.rows[0].email;
          const eventCols = await getTableColumnNames('event_orders');
          const seatingExpr = eventCols.has('seating_plan')
            ? "COALESCE(seating_plan, '{}'::jsonb)"
            : "'{}'::jsonb";
          const ev = await pool.query(
            `SELECT ${seatingExpr} AS "seatingPlan"
             FROM event_orders
             WHERE id::text = $1 AND lower(email_address) = lower($2)
             LIMIT 1`,
            [orderId, email],
          );
          if (ev.rowCount > 0) {
            return res.json({ seatingPlan: ev.rows[0].seatingPlan });
          }
          const cat = await pool.query(
            `SELECT 1 FROM catering_orders WHERE id::text = $1 AND lower(email_address) = lower($2)`,
            [orderId, email],
          );
          if (cat.rowCount > 0) {
            return res.json({ seatingPlan: {} });
          }
          return res.status(404).json({ error: 'Order not found' });
        } catch (error) {
          console.error('Error fetching customer seating:', error);
          res.status(500).json({ error: 'Failed to fetch seating plan' });
        }
      },
    );

    async function saveCustomerEventOrderSeating(req, res) {
      try {
        const customerId = req.customer.id;
        const { orderId } = req.params;
        const { seatingPlan } = req.body || {};
        const n = normalizeSeatingPlan(seatingPlan);
        if (!n.ok) {
          return res.status(400).json({ error: n.error });
        }
        const cr = await pool.query(
          `SELECT email FROM customer_accounts WHERE id = $1 LIMIT 1`,
          [customerId],
        );
        if (cr.rowCount === 0) {
          return res.status(404).json({ error: 'Customer not found' });
        }
        const email = cr.rows[0].email;
        const result = await pool.query(
          `UPDATE event_orders
             SET seating_plan = $1::jsonb, updated_at = now()
             WHERE id::text = $2
               AND lower(email_address) = lower($3)
               AND status IN ('on_going', 'for_full_payment', 'for_processing', 'for_post_analysis')
             RETURNING id`,
          [JSON.stringify(n.plan), orderId, email],
        );
        if (result.rowCount === 0) {
          return res.status(404).json({
            error:
              'Order not found, not owned by customer, not in an editable status, or not an event order.',
          });
        }
        return res.json({ ok: true, seatingPlan: n.plan });
      } catch (error) {
        console.error('Error saving customer seating:', error);
        res.status(500).json({ error: 'Failed to save seating plan' });
      }
    }

    app.put(
      '/api/customer/events/orders/:orderId/seating',
      customerAuthRequired,
      saveCustomerEventOrderSeating,
    );

    app.post(
      '/api/customer/events/orders/:orderId/seating',
      customerAuthRequired,
      saveCustomerEventOrderSeating,
    );

    app.post('/api/customer/events/orders/:orderId/respond', customerAuthRequired, async (req, res) => {
      try {
        const customerId = req.customer.id;
        const { orderId } = req.params;
        const { action } = req.body || {};

        const normalizedAction = String(action || '').trim().toLowerCase();
        if (!['confirm_inquiry', 'cancel_inquiry'].includes(normalizedAction)) {
          return res.status(400).json({
            error: "Invalid action. Allowed: confirm_inquiry, cancel_inquiry",
          });
        }

        const customerResult = await pool.query(
          `SELECT email, full_name FROM customer_accounts WHERE id = $1 LIMIT 1;`,
          [customerId]
        );
        if (customerResult.rowCount === 0) {
          return res.status(404).json({ error: 'Customer not found' });
        }

        const customerEmail = customerResult.rows[0].email;
        const customerName = customerResult.rows[0].full_name || "Customer";
        const nextStatus = normalizedAction === 'confirm_inquiry' ? 'for_down_payment' : 'cancelled';

        await ensureOrderCateringIdColumns();
        const eventCols = await getTableColumnNames('event_orders');
        const cateringCols = await getTableColumnNames('catering_orders');

        const tryUpdateByTable = async (tableName) => {
          const cols = tableName === 'event_orders' ? eventCols : cateringCols;
          const result = await pool.query(
            `UPDATE ${tableName}
             SET status = $1, updated_at = now()
             WHERE id::text = $2
               AND lower(email_address) = lower($3)
               AND status = 'online_inquiries'
             RETURNING id, ${cateringIdSelectAlias(cols)}, status, updated_at as "updatedAt"`,
            [nextStatus, orderId, customerEmail]
          );
          return result.rows[0] || null;
        };

        let updatedOrder = await tryUpdateByTable('event_orders');
        let orderType = 'event';
        if (!updatedOrder) {
          updatedOrder = await tryUpdateByTable('catering_orders');
          orderType = 'catering';
        }

        if (!updatedOrder) {
          return res.status(404).json({
            error: 'Inquiry not found, not owned by customer, or no longer actionable.',
          });
        }

        try {
          await sendCustomerNotificationEmail({
            to: customerEmail,
            subject: normalizedAction === 'confirm_inquiry'
              ? 'Curatering: Inquiry confirmed'
              : 'Curatering: Inquiry cancelled',
            text:
              `Hello ${customerName},\n\n` +
              (normalizedAction === 'confirm_inquiry'
                ? 'You confirmed your catering inquiry. It is now moved to for processing.\n' +
                  'Open My Caterings in the app, tap your booking, and use the Seating layout section to view or adjust your floor plan while the event is in processing.\n'
                : 'You cancelled your catering inquiry.\n') +
              `Order ID: ${updatedOrder.id}\n\n` +
              `- Curatering Team`,
          });
        } catch (mailError) {
          console.error('Inquiry response email failed (non-fatal):', mailError);
        }

        return res.json({
          success: true,
          orderType,
          action: normalizedAction,
          order: updatedOrder,
        });
      } catch (error) {
        console.error('Error responding to customer inquiry:', error);
        res.status(500).json({ error: 'Failed to update inquiry response' });
      }
    });

    app.patch('/api/customer/events/orders/:orderId/edit', customerAuthRequired, async (req, res) => {
      try {
        const customerId = req.customer.id;
        const { orderId } = req.params;
        const { guestCount, address, scheduleSlots, menu, venueOnly } = req.body || {};

        if (!Number.isFinite(Number(guestCount)) || Number(guestCount) <= 0) {
          return res.status(400).json({ error: 'guestCount must be a positive number' });
        }
        if (typeof address !== 'string' || !address.trim()) {
          return res.status(400).json({ error: 'address is required' });
        }

        const customerResult = await pool.query(
          `SELECT email FROM customer_accounts WHERE id = $1 LIMIT 1;`,
          [customerId]
        );
        if (customerResult.rowCount === 0) {
          return res.status(404).json({ error: 'Customer not found' });
        }
        const customerEmail = customerResult.rows[0].email;

        await ensureOrderCateringIdColumns();
        const eventCols = await getTableColumnNames('event_orders');
        const cateringCols = await getTableColumnNames('catering_orders');

        if (venueOnly === true) {
          const tryVenueOnly = async (tableName) => {
            const cols = tableName === 'event_orders' ? eventCols : cateringCols;
            const result = await pool.query(
              `UPDATE ${tableName}
               SET guest_count = $1, address = $2, updated_at = now()
               WHERE id::text = $3
                 AND lower(email_address) = lower($4)
                 AND status IN ('on_going', 'for_full_payment', 'for_processing', 'for_post_analysis')
               RETURNING
                 id,
                 ${cateringIdSelectAlias(cols)},
                 guest_count as "guestCount",
                 address,
                 status,
                 updated_at as "updatedAt"`,
              [Number(guestCount), address.trim(), orderId, customerEmail],
            );
            return result.rows[0] || null;
          };
          let updatedOrder = await tryVenueOnly('event_orders');
          let orderType = 'event';
          if (!updatedOrder) {
            updatedOrder = await tryVenueOnly('catering_orders');
            orderType = 'catering';
          }
          if (!updatedOrder) {
            return res.status(404).json({
              error: 'Order not found, not owned by customer, or not editable in this status.',
            });
          }
          return res.json({ success: true, orderType, order: updatedOrder });
        }

        if (!Array.isArray(scheduleSlots) || scheduleSlots.length === 0) {
          return res.status(400).json({ error: 'At least one schedule slot is required' });
        }
        if (!Array.isArray(menu) || menu.length === 0) {
          return res.status(400).json({ error: 'At least one dish is required' });
        }

        const sanitizedSlots = scheduleSlots
          .filter((slot) => slot && typeof slot === 'object')
          .map((slot) => ({
            date: String(slot.date || '').trim(),
            startTime: String(slot.startTime || slot.start_time || '').trim(),
            endTime: String(slot.endTime || slot.end_time || '').trim(),
          }))
          .filter((slot) => slot.date && slot.startTime && slot.endTime);
        if (sanitizedSlots.length === 0) {
          return res.status(400).json({ error: 'Invalid schedule slot format' });
        }

        const sanitizedMenu = menu
          .filter((item) => item && typeof item === 'object')
          .map((item) => {
            const dishName = String(
              item.dishName || item.dish_name || item.name || '',
            ).trim();
            const paxOption = String(item.paxOption || item.pax_option || '').trim();
            return {
              dishName,
              ...(paxOption ? { paxOption } : {}),
            };
          })
          .filter((item) => item.dishName);
        if (sanitizedMenu.length === 0) {
          return res.status(400).json({ error: 'Invalid menu format' });
        }

        const tryUpdateByTable = async (tableName) => {
          const cols = tableName === 'event_orders' ? eventCols : cateringCols;
          const result = await pool.query(
            `UPDATE ${tableName}
             SET
               guest_count = $1,
               address = $2,
               schedule_slots = $3,
               menu = $4,
               updated_at = now()
             WHERE id::text = $5
               AND lower(email_address) = lower($6)
               AND status IN ('online_inquiries', 'for_down_payment', 'on_going', 'for_full_payment', 'for_processing', 'for_post_analysis')
             RETURNING
               id,
               ${cateringIdSelectAlias(cols)},
               guest_count as "guestCount",
               address,
               schedule_slots as "scheduleSlots",
               menu,
               status,
               updated_at as "updatedAt"`,
            [
              Number(guestCount),
              address.trim(),
              JSON.stringify(sanitizedSlots),
              JSON.stringify(sanitizedMenu),
              orderId,
              customerEmail,
            ]
          );
          return result.rows[0] || null;
        };

        let updatedOrder = await tryUpdateByTable('event_orders');
        let orderType = 'event';
        if (!updatedOrder) {
          updatedOrder = await tryUpdateByTable('catering_orders');
          orderType = 'catering';
        }

        if (!updatedOrder) {
          return res.status(404).json({
            error: 'Inquiry not found, not owned by customer, or no longer editable.',
          });
        }

        return res.json({
          success: true,
          orderType,
          order: updatedOrder,
        });
      } catch (error) {
        console.error('Error editing customer inquiry:', error);
        res.status(500).json({ error: 'Failed to edit inquiry' });
      }
    });

    // Get customer profile (for My Profile page)
    app.get('/api/customer/profile', customerAuthRequired, async (req, res) => {
      try {
        const customerId = req.customer.id;

        const accountResult = await pool.query(
          `SELECT * FROM customer_accounts WHERE id = $1`,
          [customerId],
        );

        if (accountResult.rows.length === 0) {
          return res.status(404).json({ error: 'Customer not found' });
        }

        const account = accountResult.rows[0];
        const restaurantPoints = Number(account.restaurant_loyalty_points ?? 0);
        const cateringPoints = Number(account.catering_loyalty_points ?? 0);

        res.json({
          id: account.id != null ? String(account.id) : account.id,
          email: account.email,
          fullName: account.full_name,
          phone: customerPhoneFromRow(account),
          createdAt:
            account.created_at instanceof Date
              ? account.created_at.toISOString()
              : account.created_at,
          loyaltyPoints: restaurantPoints + cateringPoints,
          restaurantLoyaltyPoints: restaurantPoints,
          cateringLoyaltyPoints: cateringPoints,
          deliveryAddress: account.delivery_address || null,
          deliveryLat:
            account.delivery_lat != null ? Number(account.delivery_lat) : null,
          deliveryLng:
            account.delivery_lng != null ? Number(account.delivery_lng) : null,
        });
      } catch (error) {
        console.error('Error fetching customer profile:', error);
        res.status(500).json({ error: 'Failed to fetch profile' });
      }
    });

    // Update customer profile
    app.put('/api/customer/profile', customerAuthRequired, async (req, res) => {
      try {
        const customerId = req.customer.id;
        const { fullName, phone, deliveryAddress, deliveryLat, deliveryLng } = req.body || {};

        // Update customer_accounts
        if (fullName || phone) {
          const updates = [];
          const values = [];
          let paramCount = 0;

          if (fullName) {
            paramCount++;
            updates.push(`full_name = $${paramCount}`);
            values.push(fullName);
          }

          if (phone) {
            paramCount++;
            updates.push(`contact_number = $${paramCount}`);
            values.push(phone);
          }

          // Add updated_at (no parameter needed for now())
          updates.push(`updated_at = now()`);

          // Add customerId for WHERE clause
          paramCount++;
          values.push(customerId);

          await pool.query(
            `UPDATE customer_accounts SET ${updates.join(', ')} WHERE id = $${paramCount}`,
            values
          );
        }

        if (
          deliveryAddress !== undefined ||
          deliveryLat !== undefined ||
          deliveryLng !== undefined
        ) {
          const deliveryUpdates = [];
          const deliveryValues = [];
          let p = 0;

          if (deliveryAddress !== undefined) {
            p += 1;
            deliveryUpdates.push(`delivery_address = $${p}`);
            deliveryValues.push(deliveryAddress);
          }
          if (deliveryLat !== undefined) {
            p += 1;
            deliveryUpdates.push(`delivery_lat = $${p}`);
            deliveryValues.push(deliveryLat);
          }
          if (deliveryLng !== undefined) {
            p += 1;
            deliveryUpdates.push(`delivery_lng = $${p}`);
            deliveryValues.push(deliveryLng);
          }

          deliveryUpdates.push('updated_at = now()');
          p += 1;
          deliveryValues.push(customerId);

          await pool.query(
            `UPDATE customer_accounts SET ${deliveryUpdates.join(', ')} WHERE id = $${p}`,
            deliveryValues,
          );
        }

        res.json({ success: true, message: 'Profile updated successfully' });
      } catch (error) {
        console.error('Error updating customer profile:', error);
        res.status(500).json({ error: 'Failed to update profile' });
      }
    });

    // Change customer password
    app.put('/api/customer/password', customerAuthRequired, async (req, res) => {
      try {
        const customerId = req.customer.id;
        const { currentPassword, newPassword } = req.body || {};

        if (!currentPassword || !newPassword) {
          return res.status(400).json({ error: 'Current password and new password are required' });
        }

        if (newPassword.length < 8) {
          return res.status(400).json({ error: 'New password must be at least 8 characters' });
        }

        // Get current password hash
        const result = await pool.query(
          'SELECT password_hash FROM customer_accounts WHERE id = $1',
          [customerId]
        );

        if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Customer not found' });
        }

        // Verify current password
        const validPassword = await bcrypt.compare(currentPassword, result.rows[0].password_hash);
        if (!validPassword) {
          return res.status(401).json({ error: 'Current password is incorrect' });
        }

        // Hash new password and update
        const newPasswordHash = await bcrypt.hash(newPassword, 10);
        await pool.query(
          'UPDATE customer_accounts SET password_hash = $1, updated_at = now() WHERE id = $2',
          [newPasswordHash, customerId]
        );

        res.json({ success: true, message: 'Password changed successfully' });
      } catch (error) {
        console.error('Error changing password:', error);
        res.status(500).json({ error: 'Failed to change password' });
      }
    });

    // Loyalty: customer points (manager + super admin)
    app.get('/api/loyalty/customers', authRequired, async (req, res) => {
      try {
        const userResult = await pool.query('SELECT role FROM users WHERE id = $1', [req.user.id]);
        const role = userResult.rows[0]?.role;
        if (!userResult.rows.length || !['manager', 'super_admin', 'admin', 'supervisor'].includes(role)) {
          return res.status(403).json({ error: 'Manager access required' });
        }

        const result = await pool.query(
          `SELECT id, email, full_name, contact_number AS phone, is_verified, archived, created_at,
             COALESCE(restaurant_loyalty_points, 0) as restaurant_loyalty_points,
             COALESCE(catering_loyalty_points, 0) as catering_loyalty_points,
             (COALESCE(restaurant_loyalty_points, 0) + COALESCE(catering_loyalty_points, 0)) as loyalty_points
           FROM customer_accounts
           WHERE archived = FALSE
           ORDER BY created_at DESC`
        );

        res.json({ customers: result.rows });
      } catch (error) {
        console.error('Error fetching loyalty customers:', error);
        res.status(500).json({ error: 'Failed to fetch customers' });
      }
    });

    app.get('/api/admin/customers/:customerId/orders', authRequired, async (req, res) => {
      try {
        const userResult = await pool.query('SELECT role FROM users WHERE id = $1', [req.user.id]);
        const role = userResult.rows[0]?.role;
        if (!userResult.rows.length || !['manager', 'super_admin', 'admin', 'supervisor'].includes(role)) {
          return res.status(403).json({ error: 'Manager access required' });
        }

        const { customerId } = req.params;
        const customerResult = await pool.query(
          `SELECT id, email FROM customer_accounts WHERE id::text = $1 LIMIT 1`,
          [customerId],
        );
        if (customerResult.rowCount === 0) {
          return res.status(404).json({ error: 'Customer not found' });
        }
        const customerEmail = String(customerResult.rows[0].email || '').trim().toLowerCase();

        const roCols = await ensureRestaurantOrdersCanonicalColumns();
        await ensureOrderCateringIdColumns();
        await ensureCateringEventOrdersCanonicalColumns();
        const restaurantSelect = buildRestaurantOrderSelectSql(roCols);
        const restaurantResult = await pool.query(
          `SELECT ${restaurantSelect}
           FROM restaurant_orders
           WHERE customer_id::text = $1
           ORDER BY created_at DESC NULLS LAST`,
          [customerId],
        );
        const restaurantOrders = restaurantResult.rows.map((order) => {
          const normalized = normalizeRestaurantOrderRow(order, parseRestaurantOrderTrayItems(order), {
            channel: 'staff',
          });
          return {
            id: normalized.id,
            order_no: normalized.order_no || normalized.order_id,
            event_title: 'Restaurant order',
            created_at: normalized.created_at,
            total_amount: normalized.total_amount || normalized.total_cost || 0,
            status: normalized.order_status || normalized.status,
            order_type: 'restaurant',
            loyalty_points_obtained:
              normalized.loyalty_points_restaurant_obtained || normalized.points_earned || 0,
          };
        });

        const eventResult = await pool.query(
          `SELECT id, catering_id AS order_no, event_title, created_at, total_cost AS total_amount,
                  status, order_type, 0 AS loyalty_points_obtained
           FROM event_orders
           WHERE customer_id::text = $1
              OR ($2 <> '' AND lower(email_address) = $2)
           ORDER BY created_at DESC NULLS LAST`,
          [customerId, customerEmail],
        ).catch(() => ({ rows: [] }));

        const cateringResult = await pool.query(
          `SELECT id, catering_id AS order_no, 'Catering order' AS event_title, created_at,
                  total_cost AS total_amount, status, order_type, 0 AS loyalty_points_obtained
           FROM catering_orders
           WHERE customer_id::text = $1
              OR ($2 <> '' AND lower(email_address) = $2)
           ORDER BY created_at DESC NULLS LAST`,
          [customerId, customerEmail],
        ).catch(() => ({ rows: [] }));

        const orders = [
          ...restaurantOrders,
          ...eventResult.rows,
          ...cateringResult.rows,
        ].sort((a, b) => new Date(b.created_at || 0) - new Date(a.created_at || 0));

        res.json({ orders });
      } catch (error) {
        console.error('Error fetching customer loyalty orders:', error);
        res.status(500).json({ error: 'Failed to fetch customer orders' });
      }
    });

    // Customer Account Management (Super Admin only)
    app.get('/api/admin/customers', authRequired, async (req, res) => {
      try {
        const userResult = await pool.query('SELECT role FROM users WHERE id = $1', [req.user.id]);
        if (userResult.rows.length === 0 || userResult.rows[0].role !== 'super_admin') {
          return res.status(403).json({ error: 'Super admin access required' });
        }

        const includeArchived =
          String(req.query.includeArchived || "").toLowerCase() === "true";
        const whereClause = includeArchived ? "" : "WHERE COALESCE(archived, FALSE) = FALSE";

        const result = await pool.query(
          `SELECT id, email, full_name, contact_number AS phone, is_verified,
             COALESCE(archived, FALSE) AS archived, created_at,
             COALESCE(restaurant_loyalty_points, 0) as restaurant_loyalty_points,
             COALESCE(catering_loyalty_points, 0) as catering_loyalty_points,
             (COALESCE(restaurant_loyalty_points, 0) + COALESCE(catering_loyalty_points, 0)) as loyalty_points
           FROM customer_accounts
           ${whereClause}
           ORDER BY created_at DESC`,
        );

        res.json({ customers: result.rows });
      } catch (error) {
        console.error('Error fetching customers:', error);
        res.status(500).json({ error: 'Failed to fetch customers' });
      }
    });

    app.post('/api/admin/recalculate-loyalty-points', authRequired, async (req, res) => {
      try {
        const userResult = await pool.query('SELECT role FROM users WHERE id = $1', [req.user.id]);
        if (userResult.rows.length === 0 || userResult.rows[0].role !== 'super_admin') {
          return res.status(403).json({ error: 'Super admin access required' });
        }

        const customersResult = await pool.query(`SELECT id FROM customer_accounts WHERE archived = FALSE`);
        let updatedCount = 0;

        for (const customer of customersResult.rows) {
          const customerId = customer.id;

          const restaurantPoints = await pool.query(
            `SELECT COALESCE(SUM(COALESCE(loyalty_points_restaurant_obtained, 0)), 0) as total
             FROM restaurant_orders
             WHERE customer_id::text = $1 AND order_status = 'DELIVERED'`,
            [customerId]
          );

          const cateringPoints = await pool.query(
            `SELECT COALESCE(SUM(COALESCE(loyalty_points_catering_obtained, points_earned, 0)), 0) as total
             FROM catering_orders
             WHERE customer_id = $1 AND status = 'completed'`,
            [customerId]
          );

          const eventPoints = await pool.query(
            `SELECT COALESCE(SUM(points_earned), 0) as total FROM event_orders WHERE customer_id = $1 AND status = 'completed'`,
            [customerId]
          );

          const restaurantTotal = restaurantPoints.rows[0].total || 0;
          const cateringTotal = cateringPoints.rows[0].total || 0;

          // Update loyalty points directly in customer_accounts
          await pool.query(
            `UPDATE customer_accounts
             SET restaurant_loyalty_points = $1,
                 catering_loyalty_points = $2,
                 updated_at = now()
             WHERE id = $3`,
            [restaurantTotal, cateringTotal, customerId]
          );
          updatedCount++;
        }

        res.json({ success: true, updatedCount });
      } catch (error) {
        console.error('Error recalculating loyalty points:', error);
        res.status(500).json({ error: 'Failed to recalculate loyalty points' });
      }
    });

    app.get('/api/admin/customers/:customerId', authRequired, async (req, res) => {
      try {
        const { customerId } = req.params;
        
        // Check if user is super admin
        const userResult = await pool.query(
          'SELECT role FROM users WHERE id = $1',
          [req.user.id]
        );
        
        if (userResult.rows.length === 0 || userResult.rows[0].role !== 'super_admin') {
          return res.status(403).json({ error: 'Super admin access required' });
        }

        const customerResult = await pool.query(
          `SELECT id, email, full_name, contact_number AS phone, is_verified,
                  COALESCE(archived, FALSE) AS archived, created_at,
                  COALESCE(restaurant_loyalty_points, 0) as restaurant_loyalty_points,
                  COALESCE(catering_loyalty_points, 0) as catering_loyalty_points
           FROM customer_accounts
           WHERE id = $1`,
          [customerId]
        );

        if (customerResult.rows.length === 0) {
          return res.status(404).json({ error: 'Customer not found' });
        }

        const customer = customerResult.rows[0];
        const restaurantLoyaltyPoints = customer.restaurant_loyalty_points || 0;
        const cateringLoyaltyPoints = customer.catering_loyalty_points || 0;
        const totalLoyaltyPoints = restaurantLoyaltyPoints + cateringLoyaltyPoints;

        // Get customer orders
        // TODO: Fix customer_id column issue - using id for testing
        const ordersResult = await pool.query(
          `SELECT id, total_cost, order_status AS status, created_at
           FROM restaurant_orders
           WHERE customer_id::text = $1
           ORDER BY created_at DESC`,
          [customerId]
        );

        // Calculate total spent
        const totalSpent = ordersResult.rows.reduce((sum, order) => {
          return sum + parseFloat(order.total_cost || 0);
        }, 0);

        res.json({
          customer: customerResult.rows[0],
          orders: ordersResult.rows,
          loyaltyPoints: totalLoyaltyPoints,
          restaurantLoyaltyPoints,
          cateringLoyaltyPoints,
          totalSpent,
        });
      } catch (error) {
        console.error('Error fetching customer details:', error);
        res.status(500).json({ error: 'Failed to fetch customer details' });
      }
    });

    app.put('/api/admin/customers/:customerId/archive', authRequired, async (req, res) => {
      try {
        const { customerId } = req.params;
        const { archived } = req.body || {};
        
        // Check if user is super admin
        const userResult = await pool.query(
          'SELECT role FROM users WHERE id = $1',
          [req.user.id]
        );
        
        if (userResult.rows.length === 0 || userResult.rows[0].role !== 'super_admin') {
          return res.status(403).json({ error: 'Super admin access required' });
        }

        const result = await pool.query(
          `UPDATE customer_accounts
           SET archived = $1, updated_at = now()
           WHERE id = $2
           RETURNING *`,
          [archived, customerId]
        );

        if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Customer not found' });
        }

        res.json({ customer: result.rows[0] });
      } catch (error) {
        console.error('Error archiving customer:', error);
        res.status(500).json({ error: 'Failed to archive customer' });
      }
    });

    // Import dishes from CSV
    app.post('/api/menu/dishes/import-csv', authRequired, async (req, res) => {
      try {
        const { csvData, csvType } = req.body || {};
        
        if (!csvData || !csvType) {
          return res.status(400).json({ error: 'CSV data and type are required' });
        }

        const lines = csvData.split('\n');
        const headers = lines[0].split(',').map(h => h.trim());
        let imported = 0;
        let errors = [];
        
        // Track set menus to create for catering import
        const setMenusToCreate = new Map(); // setName -> [dishNames]

        for (let i = 1; i < lines.length; i++) {
          const line = lines[i].trim();
          if (!line) continue;

          try {
            const values = line.split(',').map(v => v.trim().replace(/^"|"$/g, ''));
            
            if (csvType === 'restaurant') {
              // 2sa.csv format: TYPE,DISH,SIZE,PRICE,SAUCES,TAG,CATEGORY
              const type = values[0] || '';
              const name = values[1] || '';
              const size = values[2] || '';
              const price = values[3] || '0';
              const sauces = values[4] ? values[4].split(',').map(s => s.trim()) : [];
              const tag = values[5] || '';
              const category = values[6] || 'restaurant';
              
              // Create pax options based on size
              let paxOptions = ['1 pax'];
              if (size === 'TRAY') {
                paxOptions = ['10-20 pax', '25-40 pax', '50-70 pax', '80-100 pax', '100+ pax'];
              }

              const mealTypeSaved = type ? await upsertMenuMealType(type) : '';
              await pool.query(
                `INSERT INTO menu_dishes (name, price, category, pax_options, sauces, ingredients, type, meal_type)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                 ON CONFLICT DO NOTHING`,
                [name, price, category, JSON.stringify(paxOptions), JSON.stringify(sauces), JSON.stringify([tag]), '', mealTypeSaved]
              );
              imported++;
            } else if (csvType === 'catering') {
              // sads.csv format: SET NAME,SET DISHES,INGREDIENTS,TAG,CATEGORY
              const setName = values[0] || '';
              const dishName = values[1] || '';
              const ingredients = values[2] ? values[2].split(',').map(i => i.trim()) : [];
              const tag = values[3] || '';
              const category = values[4] || 'catering';
              
              // Track for set menu creation
              if (setName && !setMenusToCreate.has(setName)) {
                setMenusToCreate.set(setName, []);
              }
              if (setName && dishName) {
                setMenusToCreate.get(setName).push(dishName);
              }
              
              await pool.query(
                `INSERT INTO menu_dishes (name, price, category, pax_options, ingredients, type)
                 VALUES ($1, $2, $3, $4, $5, $6)
                 ON CONFLICT DO NOTHING`,
                [dishName, '0.00', category, JSON.stringify(['10-20 pax', '25-40 pax', '50-70 pax', '80-100 pax', '100+ pax']), JSON.stringify(ingredients), setName]
              );
              imported++;
            } else if (csvType === 'catering-dishes') {
              // sadv.csv format: DISHES,INGREDIENTS,TAG,CATEGORY
              const dishName = values[0] || '';
              const ingredients = values[1] ? values[1].split(',').map(i => i.trim()) : [];
              const tag = values[2] || '';
              const category = values[3] || 'catering';
              
              await pool.query(
                `INSERT INTO menu_dishes (name, price, category, pax_options, ingredients, type)
                 VALUES ($1, $2, $3, $4, $5, $6)
                 ON CONFLICT DO NOTHING`,
                [dishName, '0.00', category, JSON.stringify(['10-20 pax', '25-40 pax', '50-70 pax', '80-100 pax', '100+ pax']), JSON.stringify(ingredients), tag]
              );
              imported++;
            }
          } catch (err) {
            errors.push({ line: i + 1, error: err.message });
          }
        }
        
        // Create set menus for catering import
        let setMenusCreated = 0;
        if (csvType === 'catering' && setMenusToCreate.size > 0) {
          for (const [setName, dishNames] of setMenusToCreate.entries()) {
            try {
              // Get dish IDs for this set
              const dishResult = await pool.query(
                `SELECT id FROM menu_dishes WHERE name = ANY($1) AND type = $2`,
                [dishNames, setName]
              );
              const dishIds = dishResult.rows.map(r => r.id);
              
              if (dishIds.length > 0) {
                // Check if set menu already exists
                const existingResult = await pool.query(
                  `SELECT id FROM set_menus WHERE name = $1`,
                  [setName]
                );
                
                if (existingResult.rows.length > 0) {
                  // Update existing set menu
                  await pool.query(
                    `UPDATE set_menus SET dish_ids = $1, updated_at = now() WHERE name = $2`,
                    [JSON.stringify(dishIds), setName]
                  );
                } else {
                  // Create new set menu
                  await pool.query(
                    `INSERT INTO set_menus (name, dish_ids) VALUES ($1, $2)`,
                    [setName, JSON.stringify(dishIds)]
                  );
                }
                setMenusCreated++;
              }
            } catch (err) {
              console.error(`Error creating set menu ${setName}:`, err);
              errors.push({ line: 0, error: `Failed to create set menu ${setName}: ${err.message}` });
            }
          }
        }

        res.json({ 
          message: `Imported ${imported} dishes${setMenusCreated > 0 ? ` and created ${setMenusCreated} set menus` : ''}`,
          imported,
          setMenusCreated,
          errors: errors.slice(0, 10) // Limit errors returned
        });
      } catch (error) {
        console.error('Error importing dishes from CSV:', error);
        res.status(500).json({ error: 'Failed to import dishes from CSV' });
      }
    });

    // Get all set menus
    app.get('/api/menu/set-menus', async (req, res) => {
      try {
        const result = await pool.query(
          `SELECT id, name, dish_ids, archived, created_at, updated_at 
           FROM set_menus 
           WHERE archived = false 
           ORDER BY name`
        );
        res.json({ setMenus: result.rows });
      } catch (error) {
        console.error('Error fetching set menus:', error);
        res.status(500).json({ error: 'Failed to fetch set menus' });
      }
    });

    // Create a new set menu
    app.post('/api/menu/set-menus', authRequired, async (req, res) => {
      try {
        const { name } = req.body || {};
        
        if (!name) {
          return res.status(400).json({ error: 'Set menu name is required' });
        }

        const result = await pool.query(
          `INSERT INTO set_menus (name, dish_ids) VALUES ($1, $2) RETURNING *`,
          [name, JSON.stringify([])]
        );
        
        res.json({ setMenu: result.rows[0] });
      } catch (error) {
        console.error('Error creating set menu:', error);
        res.status(500).json({ error: 'Failed to create set menu' });
      }
    });

    // Delete a set menu
    app.delete('/api/menu/set-menus/:id', authRequired, async (req, res) => {
      try {
        const { id } = req.params;
        
        await pool.query(
          `DELETE FROM set_menus WHERE id = $1`,
          [id]
        );
        
        res.json({ success: true });
      } catch (error) {
        console.error('Error deleting set menu:', error);
        res.status(500).json({ error: 'Failed to delete set menu' });
      }
    });

    // Add dish to a set menu
    app.post('/api/menu/dishes/:dishId/add-to-set', authRequired, async (req, res) => {
      try {
        const { dishId } = req.params;
        const { setName } = req.body || {};
        
        if (!setName) {
          return res.status(400).json({ error: 'Set name is required' });
        }

        // Get current set_menus for the dish
        const dishResult = await pool.query(
          `SELECT set_menus FROM menu_dishes WHERE id = $1`,
          [dishId]
        );
        
        if (dishResult.rows.length === 0) {
          return res.status(404).json({ error: 'Dish not found' });
        }
        
        let currentSets = dishResult.rows[0].set_menus || [];
        
        // Add the set if not already present
        if (!currentSets.includes(setName)) {
          currentSets.push(setName);
          
          await pool.query(
            `UPDATE menu_dishes SET set_menus = $1, updated_at = now() WHERE id = $2`,
            [JSON.stringify(currentSets), dishId]
          );
        }
        
        res.json({ success: true, setMenus: currentSets });
      } catch (error) {
        console.error('Error adding dish to set:', error);
        res.status(500).json({ error: 'Failed to add dish to set' });
      }
    });

    // Remove dish from a set menu
    app.post('/api/menu/dishes/:dishId/remove-from-set', authRequired, async (req, res) => {
      try {
        const { dishId } = req.params;
        const { setName } = req.body || {};
        
        if (!setName) {
          return res.status(400).json({ error: 'Set name is required' });
        }

        // Get current set_menus for the dish
        const dishResult = await pool.query(
          `SELECT set_menus FROM menu_dishes WHERE id = $1`,
          [dishId]
        );
        
        if (dishResult.rows.length === 0) {
          return res.status(404).json({ error: 'Dish not found' });
        }
        
        let currentSets = dishResult.rows[0].set_menus || [];
        
        // Remove the set
        currentSets = currentSets.filter(s => s !== setName);
        
        await pool.query(
          `UPDATE menu_dishes SET set_menus = $1, updated_at = now() WHERE id = $2`,
          [JSON.stringify(currentSets), dishId]
        );
        
        res.json({ success: true, setMenus: currentSets });
      } catch (error) {
        console.error('Error removing dish from set:', error);
        res.status(500).json({ error: 'Failed to remove dish from set' });
      }
    });

    // Get dishes by set name
    app.get('/api/menu/dishes/by-set/:setName', async (req, res) => {
      try {
        const { setName } = req.params;
        
        const result = await pool.query(
          `SELECT id, name, price, menu_dishes_additional_charge_amount, category, pax_options, sauces, supports_addons, ingredients,
                  image_base64, archived, type, set_menus, created_at, updated_at,
                  public_description, allergens
           FROM menu_dishes 
           WHERE set_menus @> $1::jsonb AND archived = false
           ORDER BY name`,
          [JSON.stringify([setName])]
        );
        
        res.json({ dishes: result.rows });
      } catch (error) {
        console.error('Error fetching dishes by set:', error);
        res.status(500).json({ error: 'Failed to fetch dishes' });
      }
    });

    // Serve Flutter web build (optional). If missing, host the SPA on Vercel/domain and keep API-only here.
    const webBuildPath = resolveWebBuildPath();
    if (webBuildPath) {
      console.log("Serving static web files from:", webBuildPath);
      app.use(express.static(webBuildPath));
      app.get("*", (req, res, next) => {
        if (req.path.startsWith("/api")) return next();
        res.sendFile(path.join(webBuildPath, "index.html"));
      });
    } else {
      console.warn(
        "[static] No Flutter web build found (index.html). Unset WEB_BUILD_PATH on Railway if it points to a non-existent path, or add `curatering/build/web` to the deploy artifact.",
      );
    }

    // Cart API routes
    app.get('/api/cart', CartAPI.getCart);
    app.post('/api/cart/sync', CartAPI.syncCart);
    app.post('/api/cart/clear', CartAPI.clearCart);

    await ensureCustomerTrayDraftsSchema();
    app.get('/api/tray-draft', customerAuthRequired, getTrayDraft);
    app.put('/api/tray-draft', customerAuthRequired, saveTrayDraft);
    app.post('/api/tray-draft', customerAuthRequired, saveTrayDraft);
    app.delete('/api/tray-draft', customerAuthRequired, clearTrayDraft);

    await ensureRestaurantOrderWorkflowColumns();
    await ensureRestaurantPosColumns(pool);
    scheduleAutoCancelJob();
    startAiAnalyticsScheduler();
    registerPosRoutes(app, {
      pool,
      authRequired,
      restaurantOrderWhereClause,
      allocateRestaurantOrderNo,
      sendCustomerNotificationEmail,
      resolveRestaurantOrderEmail,
      restaurantFeedbackLink,
    });

    routesRegistered = true;
    console.log('[startup] All API routes registered after DB init');
}

runDatabaseBootstrap();

export default sql;
