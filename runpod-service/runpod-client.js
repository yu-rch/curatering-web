const RUNPOD_API_KEY = process.env.RUNPOD_API_KEY;
const ENDPOINT_ID = "qempa773moft0n";

async function callRunpod(input) {
  const response = await fetch(
    `https://api.runpod.ai/v2/${ENDPOINT_ID}/run`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RUNPOD_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        input: input
      })
    }
  );

  const data = await response.json();
  return data;
}

async function getRunpodStatus(jobId) {
  const response = await fetch(
    `https://api.runpod.ai/v2/${ENDPOINT_ID}/status/${jobId}`,
    {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${RUNPOD_API_KEY}`,
        "Content-Type": "application/json"
      }
    }
  );

  const data = await response.json();
  return data;
}

async function getResult(jobId) {
  const res = await fetch(
    `https://api.runpod.ai/v2/${ENDPOINT_ID}/status/${jobId}`,
    {
      headers: {
        Authorization: `Bearer ${RUNPOD_API_KEY}` 
      }
    }
  );

  return await res.json();
}

async function getRunpodOutput(jobId) {
  const response = await fetch(
    `https://api.runpod.ai/v2/${ENDPOINT_ID}/output/${jobId}`,
    {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${RUNPOD_API_KEY}`,
        "Content-Type": "application/json"
      }
    }
  );

  const data = await response.json();
  return data;
}

// Example usage for theme generation with improved async response handling
async function generateTheme(input) {
  try {
    // Start the job
    const jobResponse = await callRunpod({
      event_type: input.eventType,
      theme: input.theme,
      mood: input.mood,
      colors: input.colors,
      extra: input.extra || "",
      image: input.image // base64 encoded image
    });

    console.log("Job started:", jobResponse);

    // Poll for completion using getResult
    const jobId = jobResponse.id;
    let status = "IN_QUEUE";
    let lastResult = null;
    
    while (status === "IN_QUEUE" || status === "IN_PROGRESS") {
      await new Promise(resolve => setTimeout(resolve, 2000)); // Wait 2 seconds
      
      const result = await getResult(jobId);
      status = result.status;
      lastResult = result;
      
      console.log(`Job status: ${status}`);
      
      // Check for intermediate results if available
      if (result.output) {
        console.log("Intermediate result:", result.output);
      }
    }

    // Get final output
    if (status === "COMPLETED") {
      const output = lastResult?.output || await getRunpodOutput(jobId);
      console.log("Generation completed:", output);
      return output;
    } else {
      throw new Error(`Job failed with status: ${status}. Error: ${lastResult?.error || 'Unknown error'}`);
    }
  } catch (error) {
    console.error("Error generating theme:", error);
    throw error;
  }
}

// Enhanced polling function with timeout and retry logic
async function pollForResult(jobId, maxWaitTime = 300000, pollInterval = 2000) {
  const startTime = Date.now();
  
  while (Date.now() - startTime < maxWaitTime) {
    try {
      const result = await getResult(jobId);
      
      if (result.status === "COMPLETED") {
        return result.output;
      }
      
      if (result.status === "FAILED") {
        throw new Error(`Job failed: ${result.error || 'Unknown error'}`);
      }
      
      // Log progress
      console.log(`Job ${jobId} status: ${result.status}`);
      
      // Wait before next poll
      await new Promise(resolve => setTimeout(resolve, pollInterval));
      
    } catch (error) {
      console.error("Polling error:", error);
      await new Promise(resolve => setTimeout(resolve, pollInterval));
    }
  }
  
  throw new Error("Job timed out after " + maxWaitTime + "ms");
}

// Export functions
module.exports = {
  callRunpod,
  getRunpodStatus,
  getResult,
  getRunpodOutput,
  generateTheme,
  pollForResult
};

// Example usage
if (require.main === module) {
  generateTheme({
    eventType: "wedding",
    theme: "romantic",
    mood: "elegant",
    colors: "pink and gold",
    extra: "flowers and candles",
    image: "base64_encoded_image_here"
  }).then(result => {
    console.log("Final result:", result);
  }).catch(error => {
    console.error("Error:", error);
  });
}
