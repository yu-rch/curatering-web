// RunPod HTTP client (robust submission + polling). If RUNPOD_API_KEY and
// RUNPOD_ENDPOINT are provided it will submit jobs and poll status until
// completion. Falls back to a stub when env is not configured.

// rely on global fetch (Node 18+). If running older Node, install a fetch polyfill.

function sleep(ms) {
  return new Promise((res) => setTimeout(res, ms));
}

async function submitJob(options) {
  // Support either full endpoint via RUNPOD_ENDPOINT or an endpoint id via RUNPOD_IMAGE_ENDPOINT_ID
  let endpoint = process.env.RUNPOD_ENDPOINT; // e.g. https://api.runpod.ai/v2/<id>/run or https://api.runpod.ai/v2/job
  const apiKey = process.env.RUNPOD_API_KEY;
  const imageEndpointId = process.env.RUNPOD_IMAGE_ENDPOINT_ID || process.env.RUNPOD_ENDPOINT_ID;
  if (!endpoint && imageEndpointId) {
    endpoint = `https://api.runpod.ai/v2/${imageEndpointId}/run`;
  }

  if (!endpoint || !apiKey) {
    return { id: 'stub-job-123', status: 'submitted', options };
  }

  // Support two RunPod invocation styles:
  // 1) Full-run endpoint per model: https://api.runpod.ai/v2/<model-id>/run
  //    Body: { input: { prompt: '...', ... } }
  // 2) Generic endpoint: POST model + input

  let resp;
  if (endpoint.includes('/run')) {
    const runPayload = {
      input: {
        prompt: options.prompt,
        negative_prompt: options.negative_prompt,
        strength: options.strength || options.denoise_strength,
        denoising_strength: options.denoise_strength,
        controlnet_strength: options.controlnet_strength,
        controlnet: options.controlnet,
        cfg_scale: options.cfg_scale,
        steps: options.steps,
        init_image: options.init_image
      }
    };

    resp = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(runPayload)
    });
  } else {
    const payload = {
      model: process.env.RUNPOD_MODEL || 'sd15-img2img',
      input: {
        prompt: options.prompt,
        negative_prompt: options.negative_prompt,
        strength: options.strength || options.denoise_strength,
        denoising_strength: options.denoise_strength,
        controlnet_strength: options.controlnet_strength,
        controlnet: options.controlnet,
        cfg_scale: options.cfg_scale,
        steps: options.steps,
        init_image: options.init_image
      }
    };

    resp = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });
  }

  if (!resp.ok) {
    const txt = await resp.text();
    throw new Error(`RunPod submit error: ${resp.status} ${txt}`);
  }

  const body = await resp.json();
  // Expect body to include { id, status, status_url?, output_url? }
  return body;
}

async function fetchJobStatus(jobId, statusUrl) {
  // Reconstruct endpoint similarly to submitJob so status polling works when only endpoint id is provided
  let endpoint = process.env.RUNPOD_ENDPOINT;
  const apiKey = process.env.RUNPOD_API_KEY;
  const imageEndpointId = process.env.RUNPOD_IMAGE_ENDPOINT_ID || process.env.RUNPOD_ENDPOINT_ID;
  if (!endpoint && imageEndpointId) endpoint = `https://api.runpod.ai/v2/${imageEndpointId}/run`;

  if (!endpoint || !apiKey) {
    return { id: jobId, status: 'completed', output_url: null };
  }

  const url = statusUrl || `${endpoint.replace(/\/$/, '')}/${jobId}`;
  const resp = await fetch(url, {
    headers: { Authorization: `Bearer ${apiKey}` }
  });

  if (!resp.ok) {
    const txt = await resp.text();
    throw new Error(`RunPod status error: ${resp.status} ${txt}`);
  }

  const body = await resp.json();
  return body;
}

async function submitAndWait(options, opts = {}) {
  const timeoutMs = opts.timeoutMs || 5 * 60 * 1000; // default 5 minutes
  const pollIntervalMs = opts.pollIntervalMs || 3000;

  const submitResp = await submitJob(options);
  const jobId = submitResp.id || submitResp.job_id || submitResp.jobId || 'unknown';
  const statusUrl = submitResp.status_url || submitResp.statusUrl || submitResp.status_endpoint || null;

  const startedAt = Date.now();
  let attempt = 0;
  let lastStatus = submitResp;

  while (Date.now() - startedAt < timeoutMs) {
    attempt++;
    try {
      const status = await fetchJobStatus(jobId, statusUrl);
      lastStatus = status;

      const st = (status.status || status.state || '').toString().toLowerCase();
      if (['completed', 'succeeded', 'finished', 'done'].includes(st)) {
            // Some RunPod endpoints return a top-level "COMPLETED" but include
            // an error inside `output` (eg. { output: { status: 'error', message: 'Base image required' } }).
            // Detect that and throw so callers can handle it explicitly.
            const out = status.output || {};
            const outStatus = (out.status || out.state || '').toString().toLowerCase();
            const outMsg = (out.message || out.error || '').toString();
            if (outStatus === 'error' || outStatus === 'failed' || /error|failed/i.test(outMsg)) {
              console.error('RunPod reported error in output:', JSON.stringify(out));
              throw new Error(`RunPod job ${jobId} failed: ${outMsg || outStatus || 'unknown error'}`);
            }

            return status;
      }

      if (['failed', 'error', 'cancelled', 'canceled'].includes(st)) {
        throw new Error(`RunPod job ${jobId} failed with status: ${st}`);
      }
    } catch (err) {
      // Network or parse error — log and continue until timeout
      console.error('RunPod poll error:', err.message || err);
    }

    // backoff with jitter
    const jitter = Math.floor(Math.random() * 500);
    const wait = Math.min(30000, pollIntervalMs * Math.min(1 + attempt * 0.2, 5)) + jitter;
    await sleep(wait);
  }

  throw new Error(`RunPod job ${jobId} did not finish within timeout; last status: ${JSON.stringify(lastStatus)}`);
}

module.exports = { submitJob, fetchJobStatus, submitAndWait };
