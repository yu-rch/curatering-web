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
  cinderella: ['royal blue drapery', 'glass slipper centerpiece', 'crystal chandeliers'],
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

  return {
    transformation_type: input.style_mode || 'theme_transformation',
    transformation_strength: +intensity.toFixed(2),
    preserve_structure,
    preserve_lighting,
    theme,
    objects_to_add: [...new Set(objects_to_add)].slice(0, 8),
    objects_to_replace: [],
    lighting_style,
    mood: input.mood || 'playful luxury',
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
