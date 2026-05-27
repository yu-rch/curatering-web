// OpenAI Transformation Planner: uses OpenAI when API key is present,
// otherwise falls back to a deterministic local planner for testing.

const fs = require('fs');
const path = require('path');

const systemPrompt = fs.readFileSync(path.join(__dirname, '..', 'openai_system_prompt.txt'), 'utf8');

function sanitizeTheme(theme) {
  if (!theme) return 'themed event';
  return theme.trim();
}

const THEME_DECOR_MAP = {
  cinderella: [
    'princess figure wearing royal blue dress',
    'royal blue drapery',
    'glass slipper centerpiece',
    'castle arch backdrop',
    'crystal chandeliers'
  ],
  rustic: ['wooden tables', 'string lights', 'greenery centerpieces'],
  'modern luxury': ['gold accents', 'marble decor', 'minimalist floral arrangements'],
  luxury: ['crystal chandeliers', 'white floral centerpieces', 'gold accents', 'cream drapery'],
  corporate: ['LED stage backdrop', 'minimalist floral arrangements', 'gold-accented podium'],
};

function mappedObjects(theme) {
  const lookup = String(theme || '').toLowerCase();
  const out = [];
  for (const [key, values] of Object.entries(THEME_DECOR_MAP)) {
    if (lookup.includes(key)) out.push(...values);
  }
  return [...new Set(out)];
}

function normalizeLocation(value) {
  const text = String(value || '').toLowerCase();
  if (/\b(middle|center|centre)\b/.test(text)) return 'center';
  if (/\b(side wall|wall|side)\b/.test(text)) return 'side wall';
  if (/\b(floor|empty floor|floor area)\b/.test(text)) return 'floor area';
  if (/\b(front|foreground)\b/.test(text)) return 'foreground seating area';
  if (/\b(main hall|hall)\b/.test(text)) return 'main hall';
  return '';
}

function locationForObject(object, input) {
  const lookup = [
    input.prompt,
    input.notes,
    input.custom_instructions,
    input.theme,
    object
  ].map((value) => String(value || '').toLowerCase()).join(' ');
  const explicit = normalizeLocation(lookup);
  if (explicit) return explicit;
  if (lookup.includes('photo booth')) return 'side wall';
  if (/\b(tables?|chairs?|seating|floor)\b/.test(lookup)) return 'floor area';
  if (/\b(backdrop|arch|stage)\b/.test(lookup)) return 'main hall';
  return '';
}

function mainCenterpieceFor(input, objects) {
  const lookup = [
    input.prompt,
    input.notes,
    input.custom_instructions,
  ].map((value) => String(value || '').toLowerCase()).join(' ');
  const middleMatch = lookup.match(/\b(?:middle|center|centre)\b\s+([a-z0-9 -]{3,60})/i);
  if (middleMatch && middleMatch[1]) return middleMatch[1].split(',')[0].trim();
  return objects[0] || 'main themed centerpiece';
}

async function callOpenAI(input) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) throw new Error('OPENAI_API_KEY not set');

  const userContent = JSON.stringify({ input }, null, 0);

  const resp = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userContent }
      ],
      temperature: 0.0,
      max_tokens: 400
    })
  });

  if (!resp.ok) {
    const txt = await resp.text();
    throw new Error(`OpenAI error: ${resp.status} ${txt}`);
  }

  const body = await resp.json();
  const content = body.choices && body.choices[0] && body.choices[0].message && body.choices[0].message.content;
  if (!content) throw new Error('OpenAI returned empty content');

  // Expect content to be JSON only
  let parsed;
  try {
    parsed = JSON.parse(content);
  } catch (err) {
    throw new Error('Failed to parse OpenAI planner JSON: ' + err.message);
  }

  return parsed;
}

// Deterministic simple planner for scaffolding. Replace with real OpenAI call.
async function localPlanner(input) {
  const theme = sanitizeTheme(input.theme);
  const intensity = typeof input.transformation_intensity === 'number' ? input.transformation_intensity : 0.5;
  const preserve_structure = intensity < 0.6;
  const preserve_lighting = intensity < 0.5;

  const tokens = theme
    .toLowerCase()
    .replace(/[^a-z0-9 ]/g, ' ')
    .split(/\s+/)
    .filter(Boolean);

  const objects_to_add = mappedObjects(theme);
  for (const t of tokens) {
    if (objects_to_add.length >= 6) break;
    if (['and', 'the', 'of', 'in', 'a', 'an', 'with', 'for'].includes(t)) continue;
    if (!['luxury', 'beautiful', 'elegant', 'vibe', 'atmosphere'].includes(t)) {
      objects_to_add.push(`${t} themed backdrop`);
    }
  }

  if (objects_to_add.length === 0) objects_to_add.push('round banquet tables', 'floral centerpieces');

  const lighting_style = preserve_lighting ? 'warm room lighting' : 'warm candle lighting';

  const objects = [...new Set(objects_to_add)].slice(0, 8);
  const main_centerpiece = mainCenterpieceFor(input, objects);
  const mainKey = main_centerpiece.toLowerCase();
  return {
    main_centerpiece,
    secondary_objects: objects.filter((object) => object.toLowerCase() !== mainKey).slice(0, 8),
    character_element: '',
    decor_elements: lighting_style ? [lighting_style] : [],
    layout_notes: 'center main centerpiece, floor area furniture, background decor, ceiling lighting',
  };
}

async function callPlanner(input) {
  if (process.env.OPENAI_API_KEY) {
    try {
      return await callOpenAI(input);
    } catch (err) {
      console.error('OpenAI planner failed, falling back to local planner:', err.message);
      return await localPlanner(input);
    }
  }
  return await localPlanner(input);
}

module.exports = { systemPrompt, callPlanner };
