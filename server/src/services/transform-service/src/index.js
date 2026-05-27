require('dotenv').config();
const express = require('express');
const bodyParser = require('express').json;
const planner = require('./planner');
const strategy = require('./strategy');
const promptBuilder = require('./promptBuilder');
const runpod = require('./runpodClient');
const supabase = require('./supabaseClient');

const app = express();
app.use(bodyParser({ limit: '10mb' }));

const FIXED_NEGATIVE_PROMPT = [
  'warped architecture',
  'distorted room',
  'crooked walls',
  'fisheye',
  'bad perspective',
  'warped ceiling',
  'melted surfaces',
  'cartoon',
  'anime',
  'cgi',
  'illustration',
  'duplicate objects',
  'floating decor',
  'blurry',
  'low quality',
  'watermark',
  'logo',
  'text'
].join(', ');

function buildPayload(plannerOutput, strategyOutput, prompts) {
  return {
    prompt: prompts.prompt,
    negative_prompt: FIXED_NEGATIVE_PROMPT,
    strength: strategyOutput.denoise,
    cfg_scale: strategyOutput.cfg_scale,
    steps: strategyOutput.steps,
    controlnet: {
      enabled: true,
      conditioning_scale: strategyOutput.controlnet_strength,
      preprocessor: strategyOutput.preprocessor
    },
    mode: strategyOutput.mode,
    transformation_plan: {
      theme: plannerOutput.theme,
      objects_to_add: plannerOutput.objects_to_add || [],
      objects_to_replace: plannerOutput.objects_to_replace || [],
      lighting_style: plannerOutput.lighting_style || '',
      mood: plannerOutput.mood || ''
    }
  };
}

app.post('/api/v1/transform/plan', async (req, res) => {
  try {
    const input = req.body;
    // Basic validation
    if (!input || !input.venue_image) {
      return res.status(400).json({ error: 'venue_image required' });
    }

    const plannerOutput = await planner.callPlanner(input);
    const strategyOutput = strategy.computeStrategy(plannerOutput, input);
    const finalPrompt = promptBuilder.buildPrompt(plannerOutput, strategyOutput);
    const payload = buildPayload(plannerOutput, strategyOutput, finalPrompt);

    return res.json({ planner: plannerOutput, strategy: strategyOutput, prompt: finalPrompt, payload });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'internal_error' });
  }
});

// Two-pass generation endpoint: planner -> strategy -> prompt -> RunPod pass1 -> pass2 -> store
app.post('/api/v1/transform/generate', async (req, res) => {
  try {
    const input = req.body;
    if (!input || !input.venue_image) return res.status(400).json({ error: 'venue_image required' });

    const plannerOutput = await planner.callPlanner(input);
    const strategyOutput = strategy.computeStrategy(plannerOutput, input);
    const prompts = promptBuilder.buildPrompt(plannerOutput, strategyOutput);
    const payload = buildPayload(plannerOutput, strategyOutput, prompts);

    // Pass 1 - structural transformation
    const pass1Options = {
      prompt: prompts.prompt,
      negative_prompt: payload.negative_prompt,
      strength: payload.strength,
      denoise_strength: strategyOutput.denoise,
      controlnet_strength: strategyOutput.controlnet_strength,
      cfg_scale: strategyOutput.cfg_scale,
      steps: strategyOutput.steps,
      controlnet: payload.controlnet,
      init_image: input.venue_image
    };

    const pass1 = await runpod.submitAndWait(pass1Options, { timeoutMs: 5 * 60 * 1000, pollIntervalMs: 3000 });

    // derive pass2 settings
    const denoise_refine = Math.max(0.12, Math.round(strategyOutput.denoise * 100 * 0.35) / 100);
    const controlnet_refine = Math.min(0.6, strategyOutput.controlnet_strength);
    const pass2Steps = Math.max(12, Math.round(strategyOutput.steps * 0.9));

    // determine init image for pass2 from pass1 response
    const pass1_output_url = pass1.output_url || pass1.outputImageUrl || pass1.output_image_url || pass1.result_url || null;

    const pass2Options = {
      prompt: prompts.refinement_prompt,
      negative_prompt: payload.negative_prompt,
      denoise_strength: denoise_refine,
      controlnet_strength: controlnet_refine,
      cfg_scale: strategyOutput.cfg_scale,
      steps: pass2Steps,
      init_image: pass1_output_url || input.venue_image
    };

    const pass2 = await runpod.submitAndWait(pass2Options, { timeoutMs: 3 * 60 * 1000, pollIntervalMs: 3000 });

    // Upload images to Supabase (if configured)
    let original_image_url = null;
    let pass1_image_url = null;
    let final_image_url = null;
    try {
      const orig = await supabase.uploadImage(input.venue_image);
      original_image_url = orig.url;
    } catch (e) {
      console.warn('Failed to upload original image to Supabase:', e.message || e);
    }

    try {
      const p1url = pass1.output_url || pass1.outputImageUrl || pass1.output_image_url || pass1.result_url || null;
      if (p1url) {
        const u = await supabase.uploadImage(p1url);
        pass1_image_url = u.url;
      }
    } catch (e) {
      console.warn('Failed to upload pass1 image to Supabase:', e.message || e);
    }

    try {
      const p2url = pass2.output_url || pass2.outputImageUrl || pass2.output_image_url || pass2.result_url || null;
      if (p2url) {
        const u = await supabase.uploadImage(p2url);
        final_image_url = u.url;
      }
    } catch (e) {
      console.warn('Failed to upload pass2 image to Supabase:', e.message || e);
    }

    // store records
    const recordPayload = {
      original_image_url,
      pass1_image_url,
      generated_image_url: final_image_url,
      planner_metadata: plannerOutput,
      final_prompt: prompts.prompt,
      negative_prompt: payload.negative_prompt,
      denoise: strategyOutput.denoise,
      controlnet_strength: strategyOutput.controlnet_strength,
      cfg_scale: strategyOutput.cfg_scale,
      style_mode: strategyOutput.mode,
      transformation_intensity: strategyOutput.intensity,
      runpod_job_ids: { pass1: pass1.id || pass1.job_id || pass1.jobId || null, pass2: pass2.id || pass2.job_id || pass2.jobId || null },
      status: 'completed'
    };

    const record = await supabase.insertGenerationRecord(recordPayload);

    return res.json({ record, pass1, pass2, planner: plannerOutput, strategy: strategyOutput, prompts, payload });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'generation_error', message: err.message });
  }
});

const PORT = process.env.PORT || 4001;
app.listen(PORT, () => console.log(`Transform service listening on ${PORT}`));
