const express = require('express');
const { callRunpod, getResult, pollForResult } = require('./runpod-client');

const app = express();
app.use(express.json());

// Health check endpoints
app.get('/health/live', (req, res) => {
  res.json({ ok: true });
});

app.get('/health/ready', (req, res) => {
  res.json({ 
    ok: true,
    runpod_connected: true,
    service: 'api-gateway'
  });
});

// AI generation endpoint - returns job ID immediately
app.post('/ai/generate', async (req, res) => {
  try {
    const job = await callRunpod(req.body);
    res.json(job); // return job id to frontend
  } catch (error) {
    console.error('Error starting RunPod job:', error);
    res.status(500).json({ 
      error: 'Failed to start generation',
      details: error.message 
    });
  }
});

// Job status endpoint - for polling
app.get('/ai/status/:jobId', async (req, res) => {
  try {
    const result = await getResult(req.params.jobId);
    res.json(result);
  } catch (error) {
    console.error('Error getting job status:', error);
    res.status(500).json({ 
      error: 'Failed to get job status',
      details: error.message 
    });
  }
});

// Complete generation with polling endpoint
app.post('/ai/generate-complete', async (req, res) => {
  try {
    const job = await callRunpod(req.body);
    const jobId = job.id;
    
    // Poll for completion
    const result = await pollForResult(jobId, 300000, 2000); // 5min timeout, 2sec polling
    
    res.json({
      success: true,
      jobId: jobId,
      output: result
    });
  } catch (error) {
    console.error('Error in complete generation:', error);
    res.status(500).json({ 
      error: 'Generation failed',
      details: error.message 
    });
  }
});

// Legacy theme generation endpoint (for Flutter compatibility)
app.post('/generate-theme', async (req, res) => {
  try {
    const job = await callRunpod({
      event_type: req.body.event_type || req.body.eventType,
      theme: req.body.theme,
      mood: req.body.mood,
      colors: req.body.colors,
      extra: req.body.extra || "",
      image: req.body.image
    });
    
    res.json(job); // return job id to frontend
  } catch (error) {
    console.error('Error starting theme generation:', error);
    res.status(500).json({ 
      error: 'Failed to start theme generation',
      details: error.message 
    });
  }
});

const PORT = process.env.PORT || 8000;
app.listen(PORT, () => {
  console.log(`Railway API Gateway running on port ${PORT}`);
});

module.exports = app;
