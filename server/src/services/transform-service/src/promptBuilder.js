// SD 1.5 Prompt Builder
// Builds compact prompts from planner output and strategy settings

function dedupeArray(arr) {
  const seen = new Set();
  const out = [];
  for (const s of arr) {
    const k = s.toLowerCase();
    if (!seen.has(k)) {
      seen.add(k);
      out.push(s);
    }
  }
  return out;
}

function buildPrompt(plannerOutput, strategyOutput) {
  const verb = `transform venue into ${plannerOutput.theme} event`;

  const visuals = dedupeArray(
    plannerOutput.objects_to_add || plannerOutput.visual_elements || []
  ).slice(0, 8);
  const replacements = (plannerOutput.objects_to_replace || [])
    .filter(Boolean)
    .map((item) => `replace ${item}`)
    .slice(0, 4);
  const lighting = plannerOutput.lighting_style ? [plannerOutput.lighting_style] : [];
  const quality = ['photorealistic'];

  const parts = [verb, ...visuals, ...replacements, ...lighting, ...quality].filter(Boolean);

  const prompt = dedupeArray(parts).join(', ');
  const refinement_prompt = prompt;

  return { prompt, refinement_prompt };
}

module.exports = { buildPrompt };
