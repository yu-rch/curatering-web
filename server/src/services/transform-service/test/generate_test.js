const path = require('path');
// load dotenv from server/.env (four levels up from test folder)
require('dotenv').config({ path: path.resolve(__dirname, '..', '..', '..', '..', '.env') });

const planner = require('../src/planner');
const strategy = require('../src/strategy');
const promptBuilder = require('../src/promptBuilder');
const runpod = require('../src/runpodClient');
const supabase = require('../src/supabaseClient');

async function run() {
  console.log('Starting end-to-end generation test (this will call OpenAI, RunPod, and Supabase)');

  const input = {
    theme: 'Cinderella sports gala',
    transformation_intensity: 0.75,
    style_mode: 'theme_transformation',
    // Use a public image URL as init image for RunPod. Can be overridden with TEST_VENUE_IMAGE env var.
    venue_image: process.env.TEST_VENUE_IMAGE || 'https://upload.wikimedia.org/wikipedia/commons/3/3f/Fronalpstock_big.jpg',
    color_palette: ['royal blue', 'gold']
  };

  try {
    const plannerOutput = await planner.callPlanner(input);
    console.log('Planner output:', plannerOutput);

    const strategyOutput = strategy.computeStrategy(plannerOutput, input);
    console.log('Strategy:', strategyOutput);

    const prompts = promptBuilder.buildPrompt(plannerOutput, strategyOutput);
    console.log('Prompt:', prompts);

    console.log('Submitting Pass 1 to RunPod...');
    const pass1 = await runpod.submitAndWait({
      prompt: prompts.prompt,
      negative_prompt: "warped, distorted, crooked, fisheye, low res, blurry, watermark, logo, text",
      denoise_strength: strategyOutput.denoise,
      controlnet_strength: strategyOutput.controlnet_strength,
      cfg_scale: strategyOutput.cfg_scale,
      steps: strategyOutput.steps,
      init_image: input.venue_image
    }, { timeoutMs: 5 * 60 * 1000, pollIntervalMs: 3000 });

    console.log('Pass1 result:', pass1);

    const pass1_url = pass1.output_url || pass1.outputImageUrl || pass1.output_image_url || pass1.result_url || null;

    console.log('Submitting Pass 2 to RunPod...');
    const pass2 = await runpod.submitAndWait({
      prompt: prompts.refinement_prompt,
      negative_prompt: "warped, distorted, crooked, fisheye, low res, blurry, watermark, logo, text",
      denoise_strength: Math.max(0.12, Math.round(strategyOutput.denoise * 100 * 0.35) / 100),
      controlnet_strength: Math.min(0.6, strategyOutput.controlnet_strength),
      cfg_scale: strategyOutput.cfg_scale,
      steps: Math.max(12, Math.round(strategyOutput.steps * 0.9)),
      init_image: pass1_url || input.venue_image
    }, { timeoutMs: 3 * 60 * 1000, pollIntervalMs: 3000 });

    console.log('Pass2 result:', pass2);

    // Upload images to Supabase
    let original_image_url = null;
    let pass1_image_url = null;
    let final_image_url = null;

    try {
      const o = await supabase.uploadImage(input.venue_image);
      original_image_url = o.url;
      console.log('Uploaded original to Supabase:', original_image_url);
    } catch (e) {
      console.warn('Original upload failed:', e.message || e);
    }

    try {
      if (pass1_url) {
        const u = await supabase.uploadImage(pass1_url);
        pass1_image_url = u.url;
        console.log('Uploaded pass1 to Supabase:', pass1_image_url);
      }
    } catch (e) { console.warn('Pass1 upload failed:', e.message || e); }

    try {
      const p2url = pass2.output_url || pass2.outputImageUrl || pass2.output_image_url || pass2.result_url || null;
      if (p2url) {
        const u = await supabase.uploadImage(p2url);
        final_image_url = u.url;
        console.log('Uploaded pass2 to Supabase:', final_image_url);
      }
    } catch (e) { console.warn('Pass2 upload failed:', e.message || e); }

    const recordPayload = {
      original_image_url,
      pass1_image_url,
      generated_image_url: final_image_url,
      planner_metadata: plannerOutput,
      final_prompt: prompts.prompt,
      negative_prompt: '',
      denoise: strategyOutput.denoise,
      controlnet_strength: strategyOutput.controlnet_strength,
      cfg_scale: strategyOutput.cfg_scale,
      style_mode: strategyOutput.mode,
      transformation_intensity: strategyOutput.intensity,
      runpod_job_ids: { pass1: pass1.id || pass1.job_id || null, pass2: pass2.id || pass2.job_id || null },
      status: 'completed'
    };

    try {
      const rec = await supabase.insertGenerationRecord(recordPayload);
      console.log('Inserted generation record:', rec);
    } catch (e) { console.warn('Insert record failed:', e.message || e); }

    console.log('End-to-end test finished.');
  } catch (err) {
    console.error('Generation test failed:', err);
  }
}

run();
