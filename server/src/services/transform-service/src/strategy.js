// Generation Strategy Engine
// Implements mapping from planner metadata + user input to SD 1.5 settings

function lerp(a, b, t) {
  return a + (b - a) * t;
}

const MODE_PRESETS = {
  preserve: { denoise: 0.50, controlnet: 0.85, cfg: 7.0 },
  modify: { denoise: 0.65, controlnet: 0.65, cfg: 7.0 },
  rebuild: { denoise: 0.72, controlnet: 0.55, cfg: 7.0 }
};

function strengthFor(intensity) {
  if (intensity < 0.4) return 0.50;
  if (intensity < 0.7) return 0.65;
  return 0.72;
}

function controlnetFor(intensity) {
  if (intensity < 0.4) return 0.85;
  if (intensity < 0.7) return 0.65;
  return 0.55;
}

function preprocessorFor(intensity) {
  return 'canny';
}

function modeFor(intensity) {
  if (intensity < 0.4) return 'preserve';
  if (intensity < 0.7) return 'modify';
  return 'rebuild';
}

function computeStrategy(plannerOutput, input) {
  const intensity = Math.max(0, Math.min(1, input.transformation_intensity || plannerOutput.transformation_strength || 0.5));
  const mode = modeFor(intensity);

  const preset = MODE_PRESETS[mode] || MODE_PRESETS.modify;

  const denoise = strengthFor(intensity);
  const controlnet_strength = controlnetFor(intensity);
  const cfg_scale = preset.cfg;
  const steps = 30;

  const prompt_aggressiveness = Math.round(lerp(0, 1, intensity) * 100) / 100;

  return {
    mode,
    intensity: +intensity.toFixed(2),
    denoise: +denoise.toFixed(3),
    controlnet_strength: +controlnet_strength.toFixed(3),
    preprocessor: preprocessorFor(intensity),
    cfg_scale: +cfg_scale.toFixed(2),
    steps,
    prompt_aggressiveness
  };
}

module.exports = { computeStrategy, MODE_PRESETS };
