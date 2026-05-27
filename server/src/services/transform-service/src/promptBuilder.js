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

const SPATIAL_TOKENS = [
  'center of room',
  'floor area filled with',
  'main hall placement',
  'foreground seating area'
];

function normalizeLocation(value) {
  const text = String(value || '').toLowerCase();
  if (/\b(middle|center|centre)\b/.test(text)) return 'center';
  if (/\b(side wall|wall|side)\b/.test(text)) return 'side wall';
  if (/\b(floor|empty floor|floor area)\b/.test(text)) return 'floor area';
  if (/\b(front|foreground)\b/.test(text)) return 'foreground seating area';
  if (/\b(main hall|hall)\b/.test(text)) return 'main hall';
  return text;
}

function compileInsertObject(item) {
  const object = String(item && (item.object || item.item || item.name) || '').trim();
  const location = normalizeLocation(item && (item.location || item.position || item.placement));
  if (!object) return '';
  if (location === 'center') return `center ${object} centerpiece`;
  if (location === 'side wall') return `add ${object} near side wall`;
  if (location === 'floor area') return `add ${object} on floor area`;
  if (location === 'foreground seating area') return `add ${object} in foreground seating area`;
  if (location === 'main hall') return `add ${object} in main hall placement`;
  return `add ${object}`;
}

function buildPrompt(plannerOutput, strategyOutput) {
  const verb = `transform venue into ${plannerOutput.theme} event`;
  const venueEdit = 'add decor on top of venue photo';
  const emptyFloor = 'empty floor to be filled with event furniture';

  const visuals = dedupeArray(
    plannerOutput.objects_to_add || plannerOutput.visual_elements || []
  ).slice(0, 8);
  const inserts = (plannerOutput.insert_objects || [])
    .map(compileInsertObject)
    .filter(Boolean)
    .slice(0, 8);
  const decor = (plannerOutput.decor || []).filter(Boolean).slice(0, 8);
  const replacements = (plannerOutput.objects_to_replace || [])
    .filter(Boolean)
    .map((item) => `replace ${item}`)
    .slice(0, 4);
  const lighting = plannerOutput.lighting_style ? [plannerOutput.lighting_style] : [];
  const quality = ['photorealistic'];

  const parts = [
    verb,
    venueEdit,
    emptyFloor,
    ...SPATIAL_TOKENS,
    ...inserts,
    ...visuals,
    ...decor,
    ...replacements,
    ...lighting,
    ...quality
  ].filter(Boolean);

  const prompt = dedupeArray(parts).join(', ');
  const refinement_prompt = prompt;

  return { prompt, refinement_prompt };
}

module.exports = { buildPrompt };
