import {
  compileScenePrompt,
  normalizeSceneGraph,
} from "./sceneEngine.js";

const NEGATIVE_PROMPT = [
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
];

function clean(value) {
  return String(value || "").replace(/\s+/g, " ").trim();
}

export function resolveIntensity(input = {}) {
  const raw =
    input.intensity ??
    input.transformation_intensity ??
    input.transformationIntensity ??
    0.8;
  const value = Number(raw);
  return Number.isFinite(value) ? Math.min(1, Math.max(0, value)) : 0.8;
}

export function getStrength(intensity) {
  const value = resolveIntensity({ intensity });
  if (value < 0.4) return 0.75;
  if (value < 0.7) return 0.82;
  return 0.9;
}

export function getControlNet(intensity) {
  const value = resolveIntensity({ intensity });
  if (value < 0.4) return 0.85;
  if (value < 0.7) return 0.65;
  return 0.55;
}

export function getMode(intensity) {
  const value = resolveIntensity({ intensity });
  if (value < 0.4) return "preserve";
  if (value < 0.7) return "modify";
  return "rebuild";
}

export function buildNegativePrompt() {
  return NEGATIVE_PROMPT.join(", ");
}

function validateScene(scene = {}) {
  const text = [
    scene.main_centerpiece,
    ...(scene.secondary_objects || []),
    scene.character_element,
    ...(scene.decor_elements || []),
    scene.layout_notes,
  ]
    .map((item) => clean(item).toLowerCase())
    .join(" ");

  const missing = [];
  if (!text.includes("table")) missing.push("missing_tables");
  if (!text.includes("center") && !text.includes("centerpiece")) {
    missing.push("missing_centerpiece");
  }
  if (!text.includes("floor") && !text.includes("seating")) {
    missing.push("empty_floor_risk");
  }

  return {
    valid: missing.length === 0,
    issues: missing,
  };
}

function repairScene(scene = {}, issues = []) {
  const fixed = {
    ...scene,
    secondary_objects: [...(scene.secondary_objects || [])],
    decor_elements: [...(scene.decor_elements || [])],
  };

  if (issues.includes("missing_centerpiece") && !fixed.main_centerpiece) {
    fixed.main_centerpiece = "large central themed centerpiece";
  }
  if (issues.includes("missing_tables")) {
    fixed.secondary_objects.push("round banquet tables");
  }
  if (issues.includes("empty_floor_risk")) {
    fixed.secondary_objects.push("fully furnished floor area seating");
    fixed.layout_notes = [
      fixed.layout_notes,
      "empty floor to be filled with event furniture",
    ]
      .filter(Boolean)
      .join(", ");
  }

  return normalizeSceneGraph(fixed);
}

export function autoSceneCorrector(input = {}) {
  const scene = normalizeSceneGraph(input.scene_graph || {}, input);
  const validation = validateScene(scene);
  const correctedScene = validation.valid ? scene : repairScene(scene, validation.issues);
  return {
    scene_graph: correctedScene,
    prompt: compileScenePrompt(correctedScene, {
      globalStyle: [input.theme || input.style, input.event_type].filter(Boolean).join(" "),
    }),
    corrected: !validation.valid,
    validation,
  };
}

export { compileScenePrompt };
