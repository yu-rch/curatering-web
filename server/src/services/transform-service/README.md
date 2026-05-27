# AI Venue Transformation - Transform Service (scaffold)

This folder contains a small scaffold for the Transformation service used to:
- generate a structured planner output from user input
- compute generation strategy settings
- build a compact SDXL prompt

It is intentionally self-contained and uses deterministic planner logic for local testing.

To run locally:

1. cd server/src/services/transform-service
2. npm install
3. npm start

Endpoints:
- POST /api/v1/transform/plan  — accepts JSON body with `venue_image` and optional `theme`, `transformation_intensity`, `style_mode`, `color_palette`, `mood`.

Replace the planner implementation with a real OpenAI call and configure RunPod + Supabase for production.

Supabase setup notes:
- Create a bucket named `ai-images` (or set `SUPABASE_BUCKET` env var).
- If you have an existing table, set `SUPABASE_TABLE` to your table name (default: `ai-generations`).
- Run the migration in `db/migrations/001_create_generations_table.sql` to create the `generations` table if needed.
- Set `SUPABASE_URL` and `SUPABASE_KEY` in your environment.

The service exposes `uploadImage` and `insertGenerationRecord` via `src/supabaseClient.js`.
