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

const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

const DEFAULT_MODEL = "gpt-4.1-mini";

/* -----------------------------
   OPENAI CALL WRAPPER
----------------------------- */

async function chatJson(system, user) {
  const res = await client.chat.completions.create({
    model: process.env.OPENAI_MODEL || DEFAULT_MODEL,
    response_format: { type: "json_object" },
    messages: [
      { role: "system", content: system },
      { role: "user", content: user },
    ],
    temperature: 0.3,
  });

  return JSON.parse(res.choices[0].message.content);
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