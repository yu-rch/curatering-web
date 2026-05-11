# Railway API Call Examples

## POST /ai/generate

Start a new AI theme generation job and get job ID immediately.

### Request
```bash
curl -X POST https://curatering-web-production-4978.up.railway.app/ai/generate \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "wedding",
    "theme": "romantic", 
    "mood": "elegant",
    "colors": "pink and gold",
    "extra": "flowers and candles",
    "image": "base64_encoded_image_here"
  }'
```

### Response
```json
{
  "id": "qempa773moft0n-job-123456",
  "status": "IN_QUEUE",
  "delayTime": 0
}
```

## GET /ai/status/:jobId

Check the status of a running job.

### Request
```bash
curl https://curatering-web-production-4978.up.railway.app/ai/status/qempa773moft0n-job-123456
```

### Response (In Progress)
```json
{
  "status": "IN_PROGRESS",
  "output": null,
  "delayTime": 1200
}
```

### Response (Completed)
```json
{
  "status": "COMPLETED", 
  "output": "base64_encoded_generated_image",
  "delayTime": 4500
}
```

## POST /ai/generate-complete

Start generation and wait for completion (synchronous).

### Request
```bash
curl -X POST https://curatering-web-production-4978.up.railway.app/ai/generate-complete \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "wedding",
    "theme": "romantic",
    "mood": "elegant", 
    "colors": "pink and gold",
    "extra": "flowers and candles",
    "image": "base64_encoded_image_here"
  }'
```

### Response
```json
{
  "success": true,
  "jobId": "qempa773moft0n-job-123456",
  "output": "base64_encoded_generated_image"
}
```

## Legacy Flutter Endpoint

### POST /generate-theme
```bash
curl -X POST https://curatering-web-production-4978.up.railway.app/generate-theme \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "wedding",
    "theme": "romantic",
    "mood": "elegant",
    "colors": "pink and gold", 
    "extra": "flowers and candles",
    "image": "base64_encoded_image_here"
  }'
```

## Usage Flow

1. **Start Job**: POST to `/ai/generate` → Get job ID
2. **Poll Status**: GET `/ai/status/:jobId` every 2 seconds
3. **Get Result**: When status is "COMPLETED", use the output

## Environment Variables

Set these on Railway:
- `RUNPOD_API_KEY`: Your RunPod API key
- `RUNPOD_ENDPOINT_ID`: `qempa773moft0n`
