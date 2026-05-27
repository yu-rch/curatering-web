import { z } from "zod";

const ALLOWED_POSITIONS = [
  "center",
  "surrounding",
  "left side",
  "right side",
  "background",
  "ceiling",
  "floor area",
];

export const SCENE_PLANNER_SYSTEM_PROMPT = `
You are a spatial scene design AI.

Rules:
- Return ONLY valid JSON.
- Must define a single main_centerpiece.
- Must not duplicate focal objects.
- Must assign spatial positions logically.
- Must prefer physical objects over abstract concepts.
- Never output more than one center/centerpiece object.
- Put supporting furniture and props in secondary_objects.
- Put ambient decorations only in decor_elements.
`.trim();

export const SceneGraphSchema = z.object({
  main_centerpiece: z.string().trim().min(1),
  secondary_objects: z.array(z.string().trim().min(1)).min(0).max(8),
  character_element: z.string().trim().optional(),
  decor_elements: z.array(z.string().trim().min(1)).min(0).max(12),
  layout_notes: z.string().trim().default(""),
});

function clean(value) {
  return String(value || "").replace(/\s+/g, " ").trim();
}

function cleanObject(value) {
  return clean(value)
    .replace(/\b(center|centre|middle)\b/gi, "")
    .replace(/\bcenterpiece\b/gi, "")
    .replace(/\s+/g, " ")
    .trim();
}

function list(value, max = 12) {
  const raw = Array.isArray(value) ? value : [];
  const out = [];
  const seen = new Set();
  for (const item of raw) {
    const text = clean(item);
    if (!text) continue;
    const key = cleanObject(text).toLowerCase();
    if (!key || seen.has(key)) continue;
    seen.add(key);
    out.push(text);
    if (out.length >= max) break;
  }
  return out;
}

function normalizeLocation(value) {
  const text = clean(value).toLowerCase();
  if (/\b(middle|center|centre)\b/.test(text)) return "center";
  if (/\b(left)\b/.test(text)) return "left side";
  if (/\b(right)\b/.test(text)) return "right side";
  if (/\b(ceiling|chandelier|overhead)\b/.test(text)) return "ceiling";
  if (/\b(backdrop|background|back wall|arch|stage)\b/.test(text)) return "background";
  if (/\b(tables?|chairs?|seating|floor)\b/.test(text)) return "floor area";
  if (/\b(surrounding|around)\b/.test(text)) return "surrounding";
  return "";
}

function objectKey(value) {
  return cleanObject(value).toLowerCase();
}

function insertObjects(raw) {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((item) => {
      if (!item || typeof item !== "object" || Array.isArray(item)) return null;
      const object = clean(item.object || item.item || item.name);
      if (!object) return null;
      return {
        object,
        location: normalizeLocation(item.location || item.position || item.placement),
      };
    })
    .filter(Boolean);
}

function fallbackCenter(input, raw, candidates) {
  const explicitCenter = insertObjects(raw?.insert_objects).find(
    (item) => item.location === "center",
  );
  if (explicitCenter?.object) return explicitCenter.object;

  const direct = clean(raw?.main_centerpiece);
  if (direct) return direct;

  const lookup = [input?.prompt, input?.notes, input?.custom_instructions]
    .map((value) => clean(value).toLowerCase())
    .join(" ");
  const middleMatch = lookup.match(
    /\b(?:middle|center|centre)\b(?:\s+of\s+\w+)?\s+([a-z0-9 -]{3,60})/i,
  );
  if (middleMatch?.[1]) return middleMatch[1].split(",")[0].trim();

  return candidates[0] || "main themed centerpiece";
}

function positionForObject(object, index) {
  const text = clean(object).toLowerCase();
  if (/\b(photo booth|booth)\b/.test(text)) return "background";
  if (/\b(chandelier|ceiling|fairy light|string light)\b/.test(text)) return "ceiling";
  if (/\b(backdrop|arch|drapery|stage|castle)\b/.test(text)) return "background";
  if (/\b(tables?|chairs?|seating|furniture)\b/.test(text)) return "floor area";
  return ["surrounding", "left side", "right side", "floor area", "background"][
    index % 5
  ];
}

export function normalizeSceneGraph(raw = {}, input = {}) {
  const rawInsertObjects = insertObjects(raw.insert_objects);
  const rawObjects = [
    ...list(raw.secondary_objects, 8),
    ...list(raw.objects_to_add, 10),
    ...rawInsertObjects.map((item) => item.object),
  ];
  const mainCenterpiece = cleanObject(fallbackCenter(input, raw, rawObjects));
  const mainKey = objectKey(mainCenterpiece);

  const secondary = [];
  const seenSecondary = new Set([mainKey]);
  for (const item of rawObjects) {
    const cleaned = cleanObject(item);
    const key = objectKey(cleaned);
    if (!cleaned || !key || seenSecondary.has(key)) continue;
    seenSecondary.add(key);
    secondary.push(cleaned);
    if (secondary.length >= 8) break;
  }

  const character = cleanObject(raw.character_element);
  const decor = [];
  const seenDecor = new Set([mainKey, ...seenSecondary]);
  for (const item of [...list(raw.decor_elements, 12), ...list(raw.decor, 12)]) {
    const cleaned = cleanObject(item);
    const key = objectKey(cleaned);
    if (!cleaned || !key || seenDecor.has(key)) continue;
    seenDecor.add(key);
    decor.push(cleaned);
    if (decor.length >= 12) break;
  }

  return SceneGraphSchema.parse({
    main_centerpiece: mainCenterpiece || "main themed centerpiece",
    secondary_objects: secondary,
    character_element: character || undefined,
    decor_elements: decor,
    layout_notes: clean(raw.layout_notes || input?.notes || input?.custom_instructions),
  });
}

export function compileScenePrompt(scene, { globalStyle = "" } = {}) {
  const normalized = normalizeSceneGraph(scene);
  const style = clean(globalStyle || normalized.layout_notes || "themed");
  const parts = [
    `transform venue into ${style} event`,
    "add decor on top of venue photo",
    "empty floor to be filled with event furniture",
    `center ${normalized.main_centerpiece} centerpiece`,
  ];

  normalized.secondary_objects.forEach((object, index) => {
    const position = positionForObject(object, index);
    if (position === "surrounding") {
      parts.push(`add ${object} surrounding main centerpiece`);
    } else {
      parts.push(`add ${object} on ${position}`);
    }
  });

  if (normalized.character_element) {
    parts.push(`add ${normalized.character_element} near main centerpiece`);
  }

  parts.push(...normalized.decor_elements.map((item) => `ambient ${item}`));
  parts.push("photorealistic");
  return parts.join(", ");
}

export function sceneToLegacyPlan(scene, { theme = "" } = {}) {
  const normalized = normalizeSceneGraph(scene);
  return {
    theme: clean(theme) || normalized.layout_notes || "themed",
    main_centerpiece: normalized.main_centerpiece,
    secondary_objects: normalized.secondary_objects,
    character_element: normalized.character_element,
    decor_elements: normalized.decor_elements,
    layout_notes: normalized.layout_notes,
    insert_objects: [
      { object: normalized.main_centerpiece, location: "center" },
      ...normalized.secondary_objects.map((object, index) => ({
        object,
        location: positionForObject(object, index),
      })),
    ],
    objects_to_add: [
      normalized.main_centerpiece,
      ...normalized.secondary_objects,
      ...(normalized.character_element ? [normalized.character_element] : []),
    ],
    decor: normalized.decor_elements,
  };
}
