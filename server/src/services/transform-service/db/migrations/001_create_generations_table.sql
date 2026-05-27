-- Supabase/Postgres migration: create generations table
CREATE TABLE IF NOT EXISTS public.generations (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid,
  original_image_url text,
  pass1_image_url text,
  generated_image_url text,
  planner_metadata jsonb,
  final_prompt text,
  negative_prompt text,
  denoise numeric,
  controlnet_strength numeric,
  cfg_scale numeric,
  style_mode text,
  transformation_intensity numeric,
  runpod_job_ids jsonb,
  status text,
  created_at timestamptz DEFAULT now()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_generations_user ON public.generations (user_id);
CREATE INDEX IF NOT EXISTS idx_generations_created_at ON public.generations (created_at);
