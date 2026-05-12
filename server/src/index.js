import "dotenv/config";
import express from "express";
import cors from "cors";
import jwt from "jsonwebtoken";
import bcrypt from "bcryptjs";
import nodemailer from "nodemailer";
import postgres from 'postgres'
import path from 'path'
import fs from 'fs/promises'
import { fileURLToPath } from 'url'
import {
  initDb,
  pool,
  poolQueryWithRetry,
  generateUserId,
  generateSequentialId,
} from "./db.js";
import CartAPI from './cart_api.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const websiteContentPath = path.join(__dirname, "website-content.json");

const app = express();
app.use(cors({
  origin: [
    'http://localhost:3000',
    'http://localhost:49798',
    'http://localhost:*',
    'https://curatering.up.railway.app'
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  preflightContinue: true
}));

// Handle CORS preflight requests properly
app.use((req, res, next) => {
  if (req.method === 'OPTIONS') {
    console.log('CORS preflight request:', {
      origin: req.headers.origin,
      method: req.headers['access-control-request-method'],
      headers: req.headers['access-control-request-headers']
    });
    
    // Set CORS headers for preflight
    res.header('Access-Control-Allow-Origin', req.headers.origin || '*');
    res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With');
    res.header('Access-Control-Allow-Credentials', 'true');
    res.status(200).end();
    return;
  }
  next();
});
app.use(express.json({ limit: "50mb" }));

// Health check endpoint
app.get('/health', (req, res) => {
  console.log('Health check requested at:', new Date().toISOString());
  res.status(200).json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    service: 'curatering-backend',
    port: PORT,
    environment: process.env.NODE_ENV || 'development'
  });
});
app.use(express.urlencoded({ limit: "50mb", extended: true }));

const PORT = process.env.PORT ? Number(process.env.PORT) : 3000;
const JWT_SECRET = process.env.JWT_SECRET || "dev-change-me";
const connectionString = process.env.DATABASE_URL;
const sql = postgres(connectionString);

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

const allowedRoles = new Set(["admin", "manager", "supervisor", "super_admin", "cashier"]);
const allowedHelpStatuses = new Set(["unresolved", "resolved"]);

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
  const catering = await pool.query(
    `SELECT
        id,
        source,
        status,
        null AS "eventTitle",
        'catering' AS "eventType",
        null AS "formalityLevel",
        customer_name AS "customerName",
        contact_person AS "contactPerson",
        contact_number AS "contactNumber",
        email_address AS "emailAddress",
        schedule_slots AS "scheduleSlots",
        address,
        order_type AS "orderType",
        guest_count AS "guestCount",
        menu,
        theme_design AS "themeDesign",
        post_analysis AS "postAnalysis",
        total_cost AS "totalCost",
        final_status AS "finalStatus",
        created_at
       FROM catering_orders
       WHERE id = $1`,
    [id],
  );
  if (catering.rows.length > 0) return catering.rows[0];
  const ev = await pool.query(
    `SELECT
        id,
        source,
        status,
        event_title AS "eventTitle",
        event_type AS "eventType",
        formality_level AS "formalityLevel",
        customer_name AS "customerName",
        contact_person AS "contactPerson",
        contact_number AS "contactNumber",
        email_address AS "emailAddress",
        schedule_slots AS "scheduleSlots",
        address,
        order_type AS "orderType",
        guest_count AS "guestCount",
        menu,
        theme_design AS "themeDesign",
        post_analysis AS "postAnalysis",
        total_cost AS "totalCost",
        final_status AS "finalStatus",
        created_at
       FROM event_orders
       WHERE id = $1`,
    [id],
  );
  return ev.rows[0] || null;
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
    expiresIn: "30m",
  });
}
// OTP generation
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

//Email Transporter
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.TRANSPORTER_EMAIL,
    pass: process.env.TRANSPORTER_PASSWORD,
  },
});
// Send OTP function
async function sendOtpEmail(email, otp) {
  await transporter.sendMail({
    from: process.env.TRANSPORTER_EMAIL,
    to: email,
    subject: "Verify your Curatering account.",
    text: `Welcome to Curatering! \n\n If you did not request this email, please ignore this message. \n\n Your OTP is ${otp}. \n This OTP will expire in 10 minutes`,
  });
}

// Send Password Reset Email function
async function sendPasswordResetEmail(email, resetCode, fullName) {
  await transporter.sendMail({
    from: process.env.TRANSPORTER_EMAIL,
    to: email,
    subject: "Password Reset - Curatering",
    text: `Hello ${fullName || 'Customer'},\n\nYou requested to reset your password for your Curatering account.\n\nYour password reset code is: ${resetCode}\n\nThis code will expire in 30 minutes.\n\nIf you did not request this password reset, please ignore this email and your password will remain unchanged.\n\nBest regards,\nCuratering Team`,
  });
}

// Send Password Changed Email function
async function sendPasswordChangedEmail(email, fullName) {
  await transporter.sendMail({
    from: process.env.TRANSPORTER_EMAIL,
    to: email,
    subject: "Your Password Has Been Changed - Curatering",
    text: `Hello ${fullName || 'Customer'},\n\nYour password for your Curatering account has been successfully changed.\n\nIf you did not make this change, please contact us immediately.\n\nBest regards,\nCuratering Team`,
  });
}

async function sendCustomerNotificationEmail({ to, subject, text }) {
  if (!to) return;
  if (!process.env.TRANSPORTER_EMAIL || !process.env.TRANSPORTER_PASSWORD) {
    console.warn("Skipping customer email notification: transporter credentials missing");
    return;
  }
  try {
    await transporter.sendMail({
      from: process.env.TRANSPORTER_EMAIL,
      to,
      subject,
      text,
    });
  } catch (error) {
    console.error("Failed to send customer notification email:", error?.message || error);
  }
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

function requireRoles(req, res, next, allowed) {
  const role = req.user?.role;
  if (role === "super_admin") return next();
  if (!allowed.has(role)) {
    return res.status(403).json({ message: "Not allowed" });
  }
  return next();
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
    console.log("Login attempt:", { email, passwordLength: password?.length });
    
    if (!email || !password) {
      console.log("Missing email or password");
      return res
        .status(400)
        .json({ message: "email and password are required" });
    }

    const result = await pool.query(
      `SELECT id, email, full_name, role, archived, password_hash, page_permissions, is_verified
       FROM users
       WHERE email = $1
       LIMIT 1;`,
      [email],
    );

    console.log("User query result:", {
      rowCount: result.rowCount,
      userFound: result.rowCount > 0,
      email: email
    });

    if (result.rowCount === 0) {
      console.log("User not found for email:", email);
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const user = result.rows[0];
    console.log("User data:", {
      id: user.id,
      email: user.email,
      role: user.role,
      archived: user.archived,
      is_verified: user.is_verified
    });
    
    if (user.archived) {
      console.log("Account is archived");
      return res.status(401).json({ message: "Account archived" });
    }

    const ok = await bcrypt.compare(password, user.password_hash);
    console.log("Password comparison result:", ok);
    
    if (!ok) {
      console.log("Password mismatch for email:", email);
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const token = signToken({ userId: user.id, role: user.role });
    console.log("Login successful for:", email);
    
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
       VALUES ($1, $2, $3, $4, 'unresolved')
       RETURNING id;`,
      ['guest', 'Contact Us', `${name} (${email})`, message],
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
           AND status IN ('for_processing', 'for_post_analysis')
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

//create account
app.post("/api/super-admin/users", authRequired, requireSuperAdmin, async (req, res) => {
    try {
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
      const existing = await pool.query(
        `SELECT id FROM users WHERE email = $1`,
        [email]
      );

      if (existing.rows.length > 0) {
        return res.status(400).json({ message: "Email already exists" });
      }
      
      const userId = generateUserId();
      await pool.query(
        `INSERT INTO users 
        (id, email, password_hash, full_name, role, birthday, contact_number, employment_type, archived, is_verified, otp_code, otp_expiry)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, FALSE, FALSE, $9, $10);`,
        [userId, email, passwordHash, fullName, role, birthday || null, contactNumber || null, employmentType || null, otp, expiry],
      );

      await sendOtpEmail(email, otp);

      await logAction({
        userId: req.user.id,
        feature: "",
        action: "created account (OTP sent)",
        other: { email, role },
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

    const result = await pool.query(`SELECT * FROM users WHERE email = $1`, [
      email,
    ]);

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

      await pool.query(
        `UPDATE users SET page_permissions = $1::jsonb WHERE id = $2;`,
        [JSON.stringify(pagePermissions), userId],
      );

      await logAction({
        userId: req.user.id,
        feature: "",
        action: "updated page permissions",
        other: { userId },
      });

      return res.json({ ok: true });
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
  requireSuperAdmin,
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
  requireSuperAdmin,
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

// Manager: create/list/finalize event orders
async function readWebsiteContent() {
  try {
    const raw = await fs.readFile(websiteContentPath, "utf8");
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch (error) {
    if (error?.code === "ENOENT") return {};
    throw error;
  }
}

async function writeWebsiteContent(content) {
  await fs.writeFile(
    websiteContentPath,
    JSON.stringify(content ?? {}, null, 2),
    "utf8",
  );
}

app.get("/api/website-content", async (req, res) => {
  try {
    const content = await readWebsiteContent();
    return res.json({ content });
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
      await logAction({
        userId: req.user.id,
        feature: "Website Content",
        action: "updated website content",
      });
      return res.json({ ok: true });
    } catch (e) {
      console.error(e);
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
      } = req.body || {};

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
        !themeDesign
      ) {
        return res.status(400).json({ message: "Missing required fields" });
      }

      // For catering+event orders, require event-specific fields
      if (!isCateringOnly && (!eventTitle || !eventType || !formalityLevel)) {
        return res.status(400).json({ message: "Missing required event fields" });
      }

      let result;
      
      if (isCateringOnly) {
        // Use separate catering_orders table for catering-only orders
        result = await pool.query(
          `INSERT INTO catering_orders
            (source, status, order_type, customer_name, contact_person, contact_number, email_address,
             schedule_slots, address, guest_count, menu, theme_design, created_by, updated_by)
          VALUES
            ('new_event', 'for_processing', 'catering', $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
           RETURNING id;`,
          [
            customerName,
            contactPerson,
            contactNumber,
            emailAddress,
            JSON.stringify(scheduleSlots),
            address,
            Number(guestCount),
            JSON.stringify(menu),
            JSON.stringify(themeDesign),
            req.user.id,
            req.user.id,
          ]
        );
      } else {
        // Use event_orders table for catering+event orders
        result = await pool.query(
          `INSERT INTO event_orders
            (source, status, event_title, order_type, event_type, formality_level,
             customer_name, contact_person, contact_number, email_address,
             schedule_slots, address, guest_count, menu, theme_design,
             created_by, updated_by)
           VALUES
            ('new_event', 'for_processing', $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
           RETURNING id;`,
          [
            eventTitle,
            orderType,
            eventType,
            formalityLevel,
            customerName,
            contactPerson,
            contactNumber,
            emailAddress,
            JSON.stringify(scheduleSlots),
            address,
            Number(guestCount),
            JSON.stringify(menu),
            JSON.stringify(themeDesign),
            req.user.id,
            req.user.id,
          ]
        );
      }

      await logAction({
        userId: req.user.id,
        feature: "Events",
        action: "submitted new event",
        other: { orderId: result.rows[0].id },
      });

      return res.json({ ok: true, id: result.rows[0].id });
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

app.get(
  "/api/manager/events/orders",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "admin", "super_admin"])),
  async (req, res) => {
    const { status } = req.query || {};
    if (!status)
      return res
        .status(400)
        .json({ message: "status query param is required" });

    const compact = String(req.query.compact || "") === "1";
    const themeCol = themeDesignListColumn(compact);

    const result = await pool.query(
      `SELECT
        id,
        source,
        status,
        null AS "eventTitle",
        'catering' AS "eventType",
        null AS "formalityLevel",
        customer_name AS "customerName",
        contact_person AS "contactPerson",
        contact_number AS "contactNumber",
        email_address AS "emailAddress",
        schedule_slots AS "scheduleSlots",
        address,
        order_type AS "orderType",
        guest_count AS "guestCount",
        menu,
        ${themeCol},
        post_analysis AS "postAnalysis",
        total_cost AS "totalCost",
        final_status AS "finalStatus",
        created_at
       FROM catering_orders
       WHERE
         status = $1
         OR ($1 = 'new_event' AND source = 'new_event' AND status = 'for_processing')
         OR (status = 'cancelled' AND $1 = 'completed')
       UNION ALL
       SELECT
        id,
        source,
        status,
        event_title AS "eventTitle",
        event_type AS "eventType",
        formality_level AS "formalityLevel",
        customer_name AS "customerName",
        contact_person AS "contactPerson",
        contact_number AS "contactNumber",
        email_address AS "emailAddress",
        schedule_slots AS "scheduleSlots",
        address,
        order_type AS "orderType",
        guest_count AS "guestCount",
        menu,
        ${themeCol},
        post_analysis AS "postAnalysis",
        total_cost AS "totalCost",
        final_status AS "finalStatus",
        created_at
       FROM event_orders
       WHERE
         status = $1
         OR ($1 = 'new_event' AND source = 'new_event' AND status = 'for_processing')
         OR (status = 'cancelled' AND $1 = 'completed')
       ORDER BY created_at DESC
       LIMIT 500;`,
      [status],
    );

    let orders = result.rows;
    if (compact) {
      orders = orders.map(compactEventOrderRow);
    }
    return res.json({ orders });
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
      const nextStatus = isPostChanges ? 'online_inquiries' : 'for_processing';

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
             theme_design AS "themeDesign",
             total_cost AS "totalCost"
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

      const mergedThemeDesign = {
        ...(themeDesign || {}),
        managerUpdateNotice: {
          action: normalizedAction,
          preferencesChanged: changedFields.length > 0,
          changedFields,
          postedAt: new Date().toISOString(),
        },
      };

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
               updated_at = now()
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
            ],
          )
        : await pool.query(
            `UPDATE catering_orders
             SET
               customer_name = $1,
               contact_person = $2,
               contact_number = $3,
               email_address = $4,
               schedule_slots = $5,
               address = $6,
               guest_count = $7,
               menu = $8,
               theme_design = $9,
               status = $10,
               total_cost = $11,
               updated_by = $12,
               updated_at = now()
             WHERE id = $13
               AND source = 'online_inquiry'
               AND status = 'online_inquiries'
             RETURNING id;`,
            [
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
            ],
          );

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
              `Estimated total: PHP ${Number(totalCost || 0).toFixed(2)}.\n\n` +
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
              `Your inquiry (${orderId}) has been confirmed and is now being processed.\n\n` +
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
    const { status } = req.query || {};
    if (!status)
      return res
        .status(400)
        .json({ message: "status query param is required" });

    const compact = String(req.query.compact || "") === "1";
    const themeCol = themeDesignListColumn(compact);

    const result = await pool.query(
      `SELECT
        id,
        source,
        status,
        null AS "eventTitle",
        'catering' AS "eventType",
        null AS "formalityLevel",
        customer_name AS "customerName",
        contact_person AS "contactPerson",
        contact_number AS "contactNumber",
        email_address AS "emailAddress",
        schedule_slots AS "scheduleSlots",
        address,
        order_type AS "orderType",
        guest_count AS "guestCount",
        menu,
        ${themeCol},
        post_analysis AS "postAnalysis",
        total_cost AS "totalCost",
        final_status AS "finalStatus",
        created_at
       FROM catering_orders
       WHERE
         status = $1
         OR ($1 = 'new_event' AND source = 'new_event' AND status = 'for_processing')
         OR (status = 'cancelled' AND $1 = 'completed')
       UNION ALL
       SELECT
        id,
        source,
        status,
        event_title AS "eventTitle",
        event_type AS "eventType",
        formality_level AS "formalityLevel",
        customer_name AS "customerName",
        contact_person AS "contactPerson",
        contact_number AS "contactNumber",
        email_address AS "emailAddress",
        schedule_slots AS "scheduleSlots",
        address,
        order_type AS "orderType",
        guest_count AS "guestCount",
        menu,
        ${themeCol},
        post_analysis AS "postAnalysis",
        total_cost AS "totalCost",
        final_status AS "finalStatus",
        created_at
       FROM event_orders
       WHERE
         status = $1
         OR ($1 = 'new_event' AND source = 'new_event' AND status = 'for_processing')
         OR (status = 'cancelled' AND $1 = 'completed')
       ORDER BY created_at DESC
       LIMIT 500;`,
      [status],
    );

    let orders = result.rows;
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
           AND status = 'for_post_analysis'
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
           AND status = 'for_processing'
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
      guestCount,
      menu,
      themeDesign,
      source = 'web', // 'web' or 'mobile'
    } = req.body || {};

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
      !Array.isArray(menu) ||
      !themeDesign
    ) {
      return res.status(400).json({ message: "Missing required fields" });
    }

    // Only validate event-specific fields for catering+event
    if (!isCateringOnly) {
      if (!eventTitle || !eventType || !formalityLevel) {
        return res.status(400).json({ message: "Missing required event fields" });
      }
    }

    // Generate inquiry ID based on source: INQ-000000 (web) or MINQ-000000 (mobile)
    const idPrefix = source === 'mobile' ? 'MINQ' : 'INQ';
    const inquiryId = await generateSequentialId(idPrefix, 6);

    let result;
    if (isCateringOnly) {
      // Use catering_orders table for catering-only orders
      result = await pool.query(
        `INSERT INTO catering_orders
          (source, status, order_type, inquiry_id, customer_name, contact_person, contact_number, email_address,
           schedule_slots, address, guest_count, menu, theme_design)
        VALUES
          ('online_inquiry', 'online_inquiries', 'catering', $1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         RETURNING id, inquiry_id;`,
        [
          inquiryId,
          customerName,
          contactPerson,
          contactNumber,
          emailAddress,
          JSON.stringify(scheduleSlots),
          address,
          Number(guestCount),
          JSON.stringify(menu),
          JSON.stringify(themeDesign),
        ]
      );
    } else {
      // Use event_orders table for catering+event orders
      result = await pool.query(
        `INSERT INTO event_orders
          (source, status, event_title, order_type, event_type, formality_level, inquiry_id,
           customer_name, contact_person, contact_number, email_address,
           schedule_slots, address, guest_count, menu, theme_design)
         VALUES
          ('online_inquiry', 'online_inquiries',
           $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
         RETURNING id, inquiry_id;`,
        [
          eventTitle,
          'catering_event',
          eventType,
          formalityLevel,
          inquiryId,
          customerName,
          contactPerson,
          contactNumber,
          emailAddress,
          JSON.stringify(scheduleSlots),
          address,
          Number(guestCount),
          JSON.stringify(menu),
          JSON.stringify(themeDesign),
        ]
      );
    }

    await sendCustomerNotificationEmail({
      to: emailAddress,
      subject: "Curatering: Inquiry received",
      text:
        `Hello ${customerName || "Customer"},\n\n` +
        `We received your inquiry (${result.rows[0].inquiry_id}).\n` +
        `Our team will review it and contact you soon.\n\n` +
        `- Curatering Team`,
    });

    return res.json({ ok: true, id: result.rows[0].id, inquiryId: result.rows[0].inquiry_id });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ message: "Failed to create online inquiry" });
  }
});

// Debug endpoint to check test account
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

// Accept an order (move to post-analysis)
app.post(
  "/api/events/orders/:orderId/accept",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "supervisor", "admin"])),
  async (req, res) => {
    try {
      const { orderId } = req.params;

      const result = await pool.query(
        `UPDATE event_orders
         SET
           status = 'for_post_analysis',
           updated_by = $1,
           updated_at = now()
         WHERE id = $2
           AND status = 'for_processing'
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
            `Your event order (${orderId}) status is now for post analysis.\n\n` +
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
    // Create default test super admin for development
    const testEmail = "admin@curatering.test";
    const testPassword = "admin123";
    const testFullName = "Test Super Admin";
    const existing = await pool.query(
      `SELECT id FROM users WHERE email = $1 LIMIT 1;`,
      [testEmail],
    );
    
    if (existing.rowCount === 0) {
      const passwordHash = await bcrypt.hash(testPassword, 10);
      const userId = generateUserId();
      await pool.query(
        `INSERT INTO users (id, email, password_hash, full_name, role, archived, is_verified)
         VALUES ($1, $2, $3, $4, 'super_admin', FALSE, TRUE);`,
        [userId, testEmail, passwordHash, testFullName],
      );
    } else {}
    return;
  }

  const existing = await pool.query(
    `SELECT id FROM users WHERE email = $1 LIMIT 1;`,
    [email],
  );
  if (existing.rowCount > 0) return;

  const passwordHash = await bcrypt.hash(password, 10);
  const userId = generateUserId();
  await pool.query(
    `INSERT INTO users (id, email, password_hash, full_name, role, archived)
     VALUES ($1, $2, $3, $4, 'super_admin', FALSE);`,
    [userId, email, passwordHash, fullName],
  );
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

runInitDbWithRetries()
  .then(() => seedSuperAdminIfNeeded())
  .then(async () => {
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
        const { paymentType, status, referenceNumber } = req.body || {};

        if (!paymentType || !status) {
          return res.status(400).json({ error: 'paymentType and status are required' });
        }

        if (!['down_payment', 'full_payment'].includes(paymentType)) {
          return res.status(400).json({ error: 'Invalid paymentType. Must be down_payment or full_payment' });
        }

        if (!['paid', 'pending', 'cancelled'].includes(status)) {
          return res.status(400).json({ error: 'Invalid status. Must be paid, pending, or cancelled' });
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

        // Build update query with reference number if provided
        let updateQuery = `UPDATE ${tableName} SET ${statusColumn} = $1`;
        const queryParams = [status];

        if (referenceNumber && referenceNumber.trim()) {
          const refColumn = paymentType === 'down_payment' ? 'down_payment_reference' : 'full_payment_reference';
          updateQuery += `, ${refColumn} = $2`;
          queryParams.push(referenceNumber.trim());
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

// Loyalty Rewards API endpoints
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
    app.get('/api/menu/dishes', async (req, res) => {
      let retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          const result = await pool.query(
            `SELECT id, name, price, category, pax_options, sauces, ingredients,
                    image_base64, archived, available, archived_at, created_at, updated_at, type, set_menus
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
            `SELECT id, name, price, category, pax_options, sauces, ingredients,
                    image_base64, archived, available, archived_at, created_at, updated_at, type, set_menus
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
            `SELECT id, name, price, category, pax_options, sauces, ingredients,
                    image_base64, archived, available, archived_at, created_at, updated_at, type, set_menus
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
          `SELECT id, name, price, category, pax_options, sauces, ingredients,
                  image_base64, archived, available, archived_at, created_at, updated_at, type, set_menus
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
          ingredients,
          imageBase64,
          type,
          available,
        } = req.body || {};
        
        if (!name || !price) {
          return res.status(400).json({ error: 'Name and price are required' });
        }

        const result = await pool.query(
          `INSERT INTO menu_dishes (name, price, category, pax_options, sauces, ingredients, image_base64, type, set_menus, available)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
           RETURNING *`,
          [
            name,
            price,
            category || 'catering',
            JSON.stringify(paxOptions || []),
            JSON.stringify(sauces || []),
            JSON.stringify(ingredients || []),
            imageBase64 || null,
            type || '',
            JSON.stringify([]),
            available !== false,
          ]
        );
        
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
          ingredients,
          imageBase64,
          type,
          available,
        } = req.body || {};
        
        const result = await pool.query(
          `UPDATE menu_dishes
           SET name = $1, price = $2, category = $3, pax_options = $4, 
               sauces = $5, ingredients = $6, image_base64 = $7, type = $8, set_menus = $9,
               available = $10, updated_at = now()
           WHERE id = $11
           RETURNING *`,
          [
            name,
            price,
            category,
            JSON.stringify(paxOptions),
            JSON.stringify(sauces),
            JSON.stringify(ingredients),
            imageBase64,
            type,
            JSON.stringify(req.body.setMenus || []),
            available !== false,
            dishId,
          ]
        );
        
        if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Dish not found' });
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

    // Customer Authentication endpoints
    app.post('/api/customer/signup', async (req, res) => {
      try {
        const { email, password, fullName, phone } = req.body || {};
        
        if (!email || !password || !fullName) {
          return res.status(400).json({ error: 'Email, password, and full name are required' });
        }

        // Check if customer already exists
        const existingCustomer = await pool.query(
          'SELECT id FROM customer_accounts WHERE email = $1',
          [email.toLowerCase()]
        );
        
        console.log('Existing customer check:', { found: existingCustomer.rows.length > 0, count: existingCustomer.rows.length });
        
        if (existingCustomer.rows.length > 0) {
          console.log('Rejecting signup: Email already registered -', email.toLowerCase());
          return res.status(400).json({ error: 'Email already registered' });
        }

        // Generate sequential customer ID (CUS-0001, CUS-0002, etc.)
        const customerId = await generateSequentialId('CUS', 4);
        
        const passwordHash = await bcrypt.hash(password, 10);
        const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
        const otpExpiry = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

        const result = await pool.query(
          `INSERT INTO customer_accounts (id, email, password_hash, full_name, phone, otp_code, otp_expiry)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           RETURNING id, email, full_name, is_verified`,
          [customerId, email.toLowerCase(), passwordHash, fullName, phone || null, otpCode, otpExpiry]
        );

        // Create customer profile with 0 loyalty points
        await pool.query(
          `INSERT INTO customer_profiles (customer_id, loyalty_points)
           VALUES ($1, $2)
           ON CONFLICT (customer_id) DO NOTHING`,
          [customerId, 0]
        );

        // Send OTP email
        try {
          await sendOtpEmail(email, otpCode);
        } catch (emailError) {
          console.error('Failed to send OTP email:', emailError);
          // Still return success since account was created, but log the email error
        }

        res.status(201).json({ 
          customer: result.rows[0],
          message: 'Account created. Please verify your email with the OTP sent.'
        });
      } catch (error) {
        console.error('Error signing up customer:', error);
        res.status(500).json({ error: 'Failed to create account' });
      }
    });

    app.post('/api/customer/verify-otp', async (req, res) => {
      try {
        const { email, otpCode } = req.body || {};
        
        if (!email || !otpCode) {
          return res.status(400).json({ error: 'Email and OTP code are required' });
        }

        const result = await pool.query(
          `SELECT id, otp_expiry FROM customer_accounts 
           WHERE email = $1 AND otp_code = $2 AND is_verified = FALSE`,
          [email.toLowerCase(), otpCode]
        );

        if (result.rows.length === 0) {
          return res.status(400).json({ error: 'Invalid OTP or email' });
        }

        if (new Date() > result.rows[0].otp_expiry) {
          return res.status(400).json({ error: 'OTP has expired' });
        }

        await pool.query(
          `UPDATE customer_accounts 
           SET is_verified = TRUE, otp_code = NULL, otp_expiry = NULL 
           WHERE id = $1`,
          [result.rows[0].id]
        );

        res.json({ message: 'Email verified successfully' });
      } catch (error) {
        console.error('Error verifying OTP:', error);
        res.status(500).json({ error: 'Failed to verify OTP' });
      }
    });

    app.post('/api/customer/login', async (req, res) => {
      try {
        const { email, password } = req.body || {};
        
        if (!email || !password) {
          return res.status(400).json({ error: 'Email and password are required' });
        }

        const result = await pool.query(
          'SELECT * FROM customer_accounts WHERE email = $1 AND archived = FALSE',
          [email.toLowerCase()]
        );

        if (result.rows.length === 0) {
          return res.status(401).json({ error: 'Invalid email or password' });
        }

        const customer = result.rows[0];
        const isValidPassword = await bcrypt.compare(password, customer.password_hash);

        if (!isValidPassword) {
          return res.status(401).json({ error: 'Invalid email or password' });
        }

        if (!customer.is_verified) {
          // Resend OTP
          const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
          const otpExpiry = new Date(Date.now() + 10 * 60 * 1000);
          
          await pool.query(
            `UPDATE customer_accounts 
             SET otp_code = $1, otp_expiry = $2 
             WHERE id = $3`,
            [otpCode, otpExpiry, customer.id]
          );
          
          // Send OTP email
          try {
            await sendOtpEmail(email, otpCode);
          } catch (emailError) {
            console.error('Failed to send OTP email:', emailError);
          }
          
          return res.status(403).json({ 
            error: 'Email not verified',
            requiresVerification: true,
            message: 'Please verify your email with the OTP sent.'
          });
        }

        const token = jwt.sign(
          { customerId: customer.id, role: 'customer' },
          JWT_SECRET,
          { expiresIn: '7d' }
        );

        await sendCustomerNotificationEmail({
          to: customer.email,
          subject: "Curatering: Login detected",
          text:
            `Hello ${customer.full_name || "Customer"},\n\n` +
            `Your account was just used to log in.\n` +
            `If this wasn't you, please reset your password immediately.\n\n` +
            `- Curatering Team`,
        });

        res.json({ 
          token,
          customer: {
            id: customer.id,
            email: customer.email,
            fullName: customer.full_name,
            phone: customer.phone
          }
        });
      } catch (error) {
        console.error('Error logging in customer:', error);
        res.status(500).json({ error: 'Failed to login' });
      }
    });

    // Forgot Password endpoint
    app.post('/api/customer/forgot-password', async (req, res) => {
      try {
        const { email } = req.body || {};
        
        if (!email) {
          return res.status(400).json({ error: 'Email is required' });
        }

        // Check if customer exists
        const customerResult = await pool.query(
          'SELECT id, email, full_name FROM customer_accounts WHERE email = $1',
          [email.toLowerCase()]
        );

        if (customerResult.rows.length === 0) {
          // Don't reveal if email exists or not for security
          return res.json({ message: 'If an account exists, a reset code will be sent' });
        }

        const customer = customerResult.rows[0];
        
        // Generate 6-digit reset code
        const resetCode = Math.floor(100000 + Math.random() * 900000).toString();
        
        // Store reset code with expiration (30 minutes)
        await pool.query(
          `UPDATE customer_accounts 
           SET reset_code = $1, reset_code_expires = NOW() + INTERVAL '30 minutes'
           WHERE id = $2`,
          [resetCode, customer.id]
        );

        // Send reset code via email
        try {
          await sendPasswordResetEmail(customer.email, resetCode, customer.full_name);
          console.log(`Password reset code sent to ${customer.email}: ${resetCode}`);
        } catch (emailError) {
          console.error('Failed to send password reset email:', emailError);
          // Still return success to avoid revealing email issues
        }

        res.json({ message: 'Reset code sent to your email' });
      } catch (error) {
        console.error('Error in forgot password:', error);
        res.status(500).json({ error: 'Failed to process request' });
      }
    });

    // Reset Password endpoint
    app.post('/api/customer/reset-password', async (req, res) => {
      try {
        const { email, resetCode, newPassword } = req.body || {};
        
        if (!email || !resetCode || !newPassword) {
          return res.status(400).json({ error: 'Email, reset code, and new password are required' });
        }

        if (newPassword.length < 6) {
          return res.status(400).json({ error: 'Password must be at least 6 characters' });
        }

        // Find customer with valid reset code
        const customerResult = await pool.query(
          `SELECT id, email, full_name FROM customer_accounts 
           WHERE email = $1 
           AND reset_code = $2 
           AND reset_code_expires > NOW()`,
          [email.toLowerCase(), resetCode]
        );

        if (customerResult.rows.length === 0) {
          return res.status(400).json({ error: 'Invalid or expired reset code' });
        }

        const customer = customerResult.rows[0];
        
        // Hash new password
        const hashedPassword = await bcrypt.hash(newPassword, 10);
        
        // Update password and clear reset code
        await pool.query(
          `UPDATE customer_accounts 
           SET password_hash = $1, reset_code = NULL, reset_code_expires = NULL
           WHERE id = $2`,
          [hashedPassword, customer.id]
        );

        // Send password changed notification email
        try {
          await sendPasswordChangedEmail(customer.email, customer.full_name);
        } catch (emailError) {
          console.error('Failed to send password changed email:', emailError);
        }

        res.json({ message: 'Password reset successful' });
      } catch (error) {
        console.error('Error resetting password:', error);
        res.status(500).json({ error: 'Failed to reset password' });
      }
    });

    // Restaurant Order endpoints
    const customerAuthRequired = (req, res, next) => {
      const token = req.headers.authorization?.replace('Bearer ', '');
      
      if (!token) {
        return res.status(401).json({ error: 'Authentication required' });
      }

      try {
        const decoded = jwt.verify(token, JWT_SECRET);
        if (decoded.role !== 'customer') {
          console.log('Auth failed: role is', decoded.role, 'expected customer');
          return res.status(403).json({ error: 'Customer access required' });
        }
        req.customer = { id: decoded.customerId };
        next();
      } catch (error) {
        console.log('Token verification failed:', error.message);
        return res.status(401).json({ error: 'Invalid or expired token', details: error.message });
      }
    };

    app.post('/api/restaurant/orders', customerAuthRequired, async (req, res) => {
      try {
        const { items, fullName, phone, deliveryAddress, deliveryLat, deliveryLng, deliveryNotes, totalAmount } = req.body || {};
        const customerId = req.customer.id;

        if (!items || !Array.isArray(items) || items.length === 0) {
          return res.status(400).json({ error: 'Items are required' });
        }

        if (!deliveryAddress) {
          return res.status(400).json({ error: 'Delivery address is required' });
        }

        // Generate sequential order number (ORD-0001, ORD-0002, etc.)
        const orderNo = await generateSequentialId('ORD', 4);

        const result = await pool.query(
          `INSERT INTO restaurant_orders (order_no, customer_id, full_name, phone, items, total_amount, delivery_address, delivery_lat, delivery_lng, delivery_notes)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
           RETURNING *`,
          [orderNo, customerId, fullName || null, phone || null, JSON.stringify(items), totalAmount || 0, deliveryAddress, deliveryLat, deliveryLng, deliveryNotes || null]
        );

        const customerResult = await pool.query(
          "SELECT email, full_name FROM customer_accounts WHERE id = $1 LIMIT 1",
          [customerId],
        );
        if (customerResult.rowCount > 0) {
          await sendCustomerNotificationEmail({
            to: customerResult.rows[0].email,
            subject: "Curatering: Checkout received",
            text:
              `Hello ${customerResult.rows[0].full_name || "Customer"},\n\n` +
              `Your checkout has been received successfully.\n` +
              `Order No: ${result.rows[0].order_no}\n` +
              `Total: PHP ${Number(totalAmount || 0).toFixed(2)}\n\n` +
              `- Curatering Team`,
          });
        }

        res.status(201).json({ order: result.rows[0] });
      } catch (error) {
        console.error('Error creating restaurant order:', error);
        console.error('Request body:', req.body);
        console.error('Customer ID:', req.customer?.id);
        res.status(500).json({ error: 'Failed to create order', details: error.message });
      }
    });

    app.post('/api/restaurant/orders/:orderId/payment', customerAuthRequired, async (req, res) => {
      try {
        const { orderId } = req.params;
        const { paymentReference } = req.body || {};
        
        if (!paymentReference) {
          return res.status(400).json({ error: 'Payment reference is required' });
        }

        const result = await pool.query(
          `UPDATE restaurant_orders
           SET payment_reference = $1, payment_status = 'paid', status = 'confirmed', updated_at = now()
           WHERE id = $2 AND (customer_id = $3 OR id::text = $3)
           RETURNING *`,
          [paymentReference, orderId, req.customer.id]
        );

        if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }

        res.json({ order: result.rows[0] });
      } catch (error) {
        console.error('Error updating payment:', error);
        res.status(500).json({ error: 'Failed to update payment' });
      }
    });

    app.get('/api/restaurant/orders/:orderId', customerAuthRequired, async (req, res) => {
      try {
        const { orderId } = req.params;
        
        const result = await pool.query(
          'SELECT * FROM restaurant_orders WHERE id = $1 AND (customer_id::text = $2 OR id::text = $2)',
          [orderId, req.customer.id]
        );

        if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }

        res.json({ order: result.rows[0] });
      } catch (error) {
        console.error('Error fetching order:', error);
        res.status(500).json({ error: 'Failed to fetch order' });
      }
    });

    app.get('/api/restaurant/orders', customerAuthRequired, async (req, res) => {
      try {
        const result = await pool.query(
          'SELECT * FROM restaurant_orders WHERE (customer_id::text = $1 OR id::text = $1) ORDER BY created_at DESC',
          [req.customer.id]
        );
        const orders = result.rows.map((order) => {
          // `items` is expected to be JSON, but legacy/invalid rows can exist.
          // Avoid crashing the whole endpoint (which leads to 500 in the client).
          let parsedItems = order.items;
          if (typeof order.items === 'string') {
            const trimmed = order.items.trim();
            if (trimmed.length > 0) {
              try {
                parsedItems = JSON.parse(trimmed);
              } catch (e) {
                parsedItems = [];
              }
            } else {
              parsedItems = [];
            }
          }
          if (!Array.isArray(parsedItems)) parsedItems = [];
          return { ...order, items: parsedItems };
        });
        res.json({ orders });
      } catch (error) {
        console.error('Error fetching orders:', error);
        res.status(500).json({ error: 'Failed to fetch orders' });
      }
    });

    // Manager Restaurant Orders endpoints
    const managerAuthRequired = (req, res, next) => {
      const token = req.headers.authorization?.replace('Bearer ', '');
      
      if (!token) {
        return res.status(401).json({ error: 'No token provided' });
      }
      
      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'dev-change-me');
        // Allow all admin-level roles to access restaurant orders
        const adminRoles = ['admin', 'manager', 'supervisor', 'super_admin'];
        if (!adminRoles.includes(decoded.role)) {
          console.log(`Access denied for role: ${decoded.role}`);
          return res.status(403).json({ error: 'Manager access required' });
        }
        req.manager = decoded;
        next();
      } catch (error) {
        console.log('Token verification error:', error.message);
        return res.status(401).json({ error: 'Invalid token' });
      }
    };

    // Get all restaurant orders for managers
    app.get('/api/manager/restaurant/orders', managerAuthRequired, async (req, res) => {
      const startTime = Date.now();
      try {
        const { status, limit = 50 } = req.query;
        
        // Use a simpler, faster query with only essential fields
        let query = `
          SELECT id, full_name, phone, items, total_amount, 
                 delivery_address, status, payment_status, 
                 created_at, updated_at
          FROM restaurant_orders 
          ORDER BY created_at DESC 
          LIMIT $1
        `;
        let params = [limit];
        
        if (status) {
          const statusValues = status.split(',');
          if (statusValues.length === 1) {
            query = `
              SELECT id, full_name, phone, items, total_amount, 
                     delivery_address, status, payment_status, 
                     created_at, updated_at
              FROM restaurant_orders 
              WHERE status = $1 
              ORDER BY created_at DESC 
              LIMIT $2
            `;
            params = [statusValues[0], limit];
          } else {
            query = `
              SELECT id, full_name, phone, items, total_amount, 
                     delivery_address, status, payment_status, 
                     created_at, updated_at
              FROM restaurant_orders 
              WHERE status IN (${statusValues.map((_, i) => `$${i + 1}`).join(', ')}) 
              ORDER BY created_at DESC 
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
        
        // Process items JSON to reduce client-side processing
        const processedOrders = result.rows.map(order => ({
          ...order,
          items: typeof order.items === 'string' ? JSON.parse(order.items) : order.items
        }));
        
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
        
        const updateFields = [];
        const updateValues = [];
        let paramIndex = 1;

        if (status) {
          // Validate status against allowed values
          const allowedStatuses = ['pending', 'confirmed', 'preparing', 'out_for_delivery', 'delivered', 'cancelled'];
          if (!allowedStatuses.includes(status)) {
            return res.status(400).json({ error: `Invalid status: ${status}. Allowed statuses: ${allowedStatuses.join(', ')}` });
          }
          updateFields.push(`status = $${paramIndex++}`);
          updateValues.push(status);
        }
        
        if (delivery_tracking_url) {
          updateFields.push(`delivery_tracking_url = $${paramIndex++}`);
          updateValues.push(delivery_tracking_url);
        }
        
        if (payment_status) {
          updateFields.push(`payment_status = $${paramIndex++}`);
          updateValues.push(payment_status);
        }
        
        updateFields.push(`updated_at = now()`);
        updateValues.push(orderId);

        const query = `
          UPDATE restaurant_orders 
          SET ${updateFields.join(', ')}
          WHERE id = $${paramIndex}
          RETURNING *
        `;

        const result = await pool.query(query, updateValues);
        
        if (result.rowCount === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }

        // Auto-calculate loyalty points when order is delivered
        if (status === 'delivered') {
          const order = result.rows[0];
          const customerId = order.customer_id;
          const totalAmount = parseFloat(order.total_amount || 0);
          
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
            await pool.query(
              `UPDATE restaurant_orders SET points_earned = $1 WHERE id = $2`,
              [points, orderId]
            );
            
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

        const customerResult = await pool.query(
          "SELECT email, full_name FROM customer_accounts WHERE id = $1 LIMIT 1",
          [orderId],
        );
        if (customerResult.rowCount > 0) {
          await sendCustomerNotificationEmail({
            to: customerResult.rows[0].email,
            subject: "Curatering: Restaurant order status updated",
            text:
              `Hello ${customerResult.rows[0].full_name || "Customer"},\n\n` +
              `Your restaurant order (${orderId}) has a status update.\n` +
              `${status ? `New status: ${status}\n` : ""}` +
              `${payment_status ? `Payment status: ${payment_status}\n` : ""}\n` +
              `- Curatering Team`,
          });
        }

        res.json({ order: result.rows[0] });
      } catch (error) {
        console.error('Error updating restaurant order:', error);
        res.status(500).json({ error: 'Failed to update order' });
      }
    });

    // Get customer event/catering orders
    app.get('/api/customer/events/orders', customerAuthRequired, async (req, res) => {
      try {
        const customerId = req.customer.id;
        const customerResult = await pool.query(
          `SELECT email FROM customer_accounts WHERE id = $1 LIMIT 1;`,
          [customerId]
        );
        if (customerResult.rowCount === 0) {
          return res.status(404).json({ error: 'Customer not found' });
        }
        const customerEmail = customerResult.rows[0].email;

        // Query both event_orders and catering_orders by customer email.
        const result = await pool.query(
          `SELECT 
            id, 
            inquiry_id as "inquiryId",
            event_title as "eventTitle", 
            event_type as "eventType", 
            status, 
            guest_count as "guestCount",
            schedule_slots as "scheduleSlots",
            menu,
            total_cost as "totalCost",
            theme_design as "themeDesign",
            created_at as "createdAt",
            'event' as order_type
          FROM event_orders 
          WHERE lower(email_address) = lower($1)
          UNION ALL
          SELECT 
            id,
            inquiry_id as "inquiryId",
            NULL as "eventTitle",
            'catering' as "eventType",
            status,
            guest_count as "guestCount",
            schedule_slots as "scheduleSlots",
            menu,
            total_cost as "totalCost",
            theme_design as "themeDesign",
            created_at as "createdAt",
            'catering' as order_type
          FROM catering_orders
          WHERE lower(email_address) = lower($1)
          ORDER BY "createdAt" DESC`,
          [customerEmail]
        );

        res.json({ orders: result.rows });
      } catch (error) {
        console.error('Error fetching customer event orders:', error);
        res.status(500).json({ error: 'Failed to fetch event orders' });
      }
    });

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
        const nextStatus = normalizedAction === 'confirm_inquiry' ? 'for_processing' : 'cancelled';

        const tryUpdateByTable = async (tableName) => {
          const result = await pool.query(
            `UPDATE ${tableName}
             SET status = $1, updated_at = now()
             WHERE id::text = $2
               AND lower(email_address) = lower($3)
               AND status = 'online_inquiries'
             RETURNING id, inquiry_id as "inquiryId", status, updated_at as "updatedAt"`,
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
                ? 'You confirmed your catering inquiry. It is now moved to for processing.\n'
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
        const { guestCount, address, scheduleSlots, menu } = req.body || {};

        if (!Number.isFinite(Number(guestCount)) || Number(guestCount) <= 0) {
          return res.status(400).json({ error: 'guestCount must be a positive number' });
        }
        if (typeof address !== 'string' || !address.trim()) {
          return res.status(400).json({ error: 'address is required' });
        }
        if (!Array.isArray(scheduleSlots) || scheduleSlots.length === 0) {
          return res.status(400).json({ error: 'At least one schedule slot is required' });
        }
        if (!Array.isArray(menu) || menu.length === 0) {
          return res.status(400).json({ error: 'At least one dish is required' });
        }

        const customerResult = await pool.query(
          `SELECT email FROM customer_accounts WHERE id = $1 LIMIT 1;`,
          [customerId]
        );
        if (customerResult.rowCount === 0) {
          return res.status(404).json({ error: 'Customer not found' });
        }
        const customerEmail = customerResult.rows[0].email;

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
               AND status = 'online_inquiries'
             RETURNING
               id,
               inquiry_id as "inquiryId",
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

    async function getCustomerProfileColumns() {
      const result = await pool.query(
        `SELECT column_name
         FROM information_schema.columns
         WHERE table_schema = 'public'
           AND table_name = 'customer_profiles'`,
      );
      const cols = new Set(result.rows.map((r) => r.column_name));
      return {
        hasCustomerId: cols.has('customer_id'),
        hasUserEmail: cols.has('user_email'),
        hasId: cols.has('id'),
      };
    }

    // Get customer profile (for My Profile page)
    app.get('/api/customer/profile', customerAuthRequired, async (req, res) => {
      try {
        const customerId = req.customer.id;

        // Get customer account info with loyalty points
        const accountResult = await pool.query(
          `SELECT id, email, full_name, phone, created_at,
                  restaurant_loyalty_points, catering_loyalty_points
           FROM customer_accounts
           WHERE id = $1`,
          [customerId]
        );

        if (accountResult.rows.length === 0) {
          return res.status(404).json({ error: 'Customer not found' });
        }

        const account = accountResult.rows[0];

        // Get delivery address from customer_profiles
        const profileColumns = await getCustomerProfileColumns();
        let profileResult = { rows: [] };
        if (profileColumns.hasCustomerId) {
          profileResult = await pool.query(
            `SELECT delivery_address, delivery_lat, delivery_lng
             FROM customer_profiles
             WHERE customer_id = $1
             LIMIT 1`,
            [customerId],
          );
        } else if (profileColumns.hasUserEmail) {
          profileResult = await pool.query(
            `SELECT delivery_address, delivery_lat, delivery_lng
             FROM customer_profiles
             WHERE user_email = $1
             LIMIT 1`,
            [account.email],
          );
        } else if (profileColumns.hasId) {
          profileResult = await pool.query(
            `SELECT delivery_address, delivery_lat, delivery_lng
             FROM customer_profiles
             WHERE id::text = $1
             LIMIT 1`,
            [customerId],
          );
        }
        const profile = profileResult.rows[0] || {};

        const restaurantPoints = account.restaurant_loyalty_points || 0;
        const cateringPoints = account.catering_loyalty_points || 0;

        res.json({
          id: account.id,
          email: account.email,
          fullName: account.full_name,
          phone: account.phone,
          createdAt: account.created_at,
          loyaltyPoints: restaurantPoints + cateringPoints,
          restaurantLoyaltyPoints: restaurantPoints,
          cateringLoyaltyPoints: cateringPoints,
          deliveryAddress: profile.delivery_address || null,
          deliveryLat: profile.delivery_lat || null,
          deliveryLng: profile.delivery_lng || null,
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
            updates.push(`phone = $${paramCount}`);
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

        // Update or insert customer_profiles (for address and coordinates)
        if (deliveryAddress !== undefined || deliveryLat !== undefined || deliveryLng !== undefined) {
          const profileColumns = await getCustomerProfileColumns();
          const accountResult = await pool.query(
            `SELECT email FROM customer_accounts WHERE id = $1 LIMIT 1`,
            [customerId],
          );
          const customerEmail = accountResult.rows[0]?.email ?? null;

          if (profileColumns.hasCustomerId) {
            if (profileColumns.hasUserEmail) {
              await pool.query(
                `INSERT INTO customer_profiles (customer_id, user_email, delivery_address, delivery_lat, delivery_lng)
                 VALUES ($1, $2, $3, $4, $5)
                 ON CONFLICT (customer_id)
                 DO UPDATE SET
                   user_email = COALESCE(EXCLUDED.user_email, customer_profiles.user_email),
                   delivery_address = COALESCE(EXCLUDED.delivery_address, customer_profiles.delivery_address),
                   delivery_lat = COALESCE(EXCLUDED.delivery_lat, customer_profiles.delivery_lat),
                   delivery_lng = COALESCE(EXCLUDED.delivery_lng, customer_profiles.delivery_lng),
                   updated_at = now()`,
                [customerId, customerEmail, deliveryAddress, deliveryLat, deliveryLng],
              );
            } else {
              await pool.query(
                `INSERT INTO customer_profiles (customer_id, delivery_address, delivery_lat, delivery_lng)
                 VALUES ($1, $2, $3, $4)
                 ON CONFLICT (customer_id)
                 DO UPDATE SET
                   delivery_address = COALESCE(EXCLUDED.delivery_address, customer_profiles.delivery_address),
                   delivery_lat = COALESCE(EXCLUDED.delivery_lat, customer_profiles.delivery_lat),
                   delivery_lng = COALESCE(EXCLUDED.delivery_lng, customer_profiles.delivery_lng),
                   updated_at = now()`,
                [customerId, deliveryAddress, deliveryLat, deliveryLng],
              );
            }
          } else if (profileColumns.hasUserEmail) {
            await pool.query(
              `INSERT INTO customer_profiles (user_email, delivery_address, delivery_lat, delivery_lng)
               VALUES ($1, $2, $3, $4)
               ON CONFLICT (user_email)
               DO UPDATE SET
                 delivery_address = COALESCE(EXCLUDED.delivery_address, customer_profiles.delivery_address),
                 delivery_lat = COALESCE(EXCLUDED.delivery_lat, customer_profiles.delivery_lat),
                 delivery_lng = COALESCE(EXCLUDED.delivery_lng, customer_profiles.delivery_lng),
                 updated_at = now()`,
              [customerEmail, deliveryAddress, deliveryLat, deliveryLng],
            );
          } else {
            return res.status(500).json({ error: 'Unsupported customer profile schema' });
          }
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

    // Customer Account Management (Super Admin only)
    app.get('/api/admin/customers', authRequired, async (req, res) => {
      try {
        const userResult = await pool.query('SELECT role FROM users WHERE id = $1', [req.user.id]);
        if (userResult.rows.length === 0 || userResult.rows[0].role !== 'super_admin') {
          return res.status(403).json({ error: 'Super admin access required' });
        }

        // Fetch customers with loyalty points directly from customer_accounts
        const result = await pool.query(
          `SELECT id, email, full_name, phone, is_verified, archived, created_at,
             COALESCE(restaurant_loyalty_points, 0) as restaurant_loyalty_points,
             COALESCE(catering_loyalty_points, 0) as catering_loyalty_points,
             (COALESCE(restaurant_loyalty_points, 0) + COALESCE(catering_loyalty_points, 0)) as loyalty_points
           FROM customer_accounts
           WHERE archived = FALSE
           ORDER BY created_at DESC`
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
            `SELECT COALESCE(SUM(points_earned), 0) as total FROM restaurant_orders WHERE customer_id = $1 AND status = 'delivered'`,
            [customerId]
          );

          const cateringPoints = await pool.query(
            `SELECT COALESCE(SUM(points_earned), 0) as total FROM catering_orders WHERE customer_id = $1 AND status = 'completed'`,
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
          `SELECT id, email, full_name, phone, is_verified, archived, created_at,
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
          `SELECT id, total_amount, status, payment_status, created_at
           FROM restaurant_orders
           WHERE id = $1
           ORDER BY created_at DESC`,
          [customerId]
        );

        // Calculate total spent
        const totalSpent = ordersResult.rows.reduce((sum, order) => {
          return sum + parseFloat(order.total_amount || 0);
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

              await pool.query(
                `INSERT INTO menu_dishes (name, price, category, pax_options, sauces, ingredients, type)
                 VALUES ($1, $2, $3, $4, $5, $6, $7)
                 ON CONFLICT DO NOTHING`,
                [name, price, category, JSON.stringify(paxOptions), JSON.stringify(sauces), JSON.stringify([tag]), type]
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
          `SELECT id, name, price, category, pax_options, sauces, ingredients,
                  image_base64, archived, type, set_menus, created_at, updated_at
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

    // Serve Flutter web build files (production).
    // Allow overriding via WEB_BUILD_PATH env var to support different deploy layouts.
    const webBuildPath = process.env.WEB_BUILD_PATH || path.join(__dirname, '../../curatering/build/web');
    console.log('Serving static web files from:', webBuildPath);
    app.use(express.static(webBuildPath));

    // Health check endpoint for Railway
    app.get('/health', (req, res) => {
      res.status(200).json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        port: PORT,
        environment: process.env.NODE_ENV || 'development'
      });
    });

    // Cart API routes
app.get('/api/cart', CartAPI.getCart);
app.post('/api/cart/sync', CartAPI.syncCart);
app.post('/api/cart/clear', CartAPI.clearCart);

// SPA fallback - serve index.html for all non-API routes
app.get('*', (req, res) => {
  if (!req.path.startsWith('/api')) {
    res.sendFile(path.join(webBuildPath, 'index.html'));
  }
});
    
    app.listen(PORT, () => {
      console.log(`Curatering server listening on port ${PORT}`);
      console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log(`Database URL configured: ${connectionString ? 'Yes' : 'No'}`);
      console.log(`Health check available at: https://curatering.up.railway.app/health`);
    });
  })
  .catch((err) => {
    console.error("Failed to init DB/server:", err);
    process.exit(1);
  });

export default sql;
