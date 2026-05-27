// Supabase client for storing images and generation metadata.
// Requires SUPABASE_URL and SUPABASE_KEY environment variables.

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY;
const BUCKET = process.env.SUPABASE_BUCKET || 'ai-images';
const TABLE = process.env.SUPABASE_TABLE || 'ai-generations';

let supabase = null;
if (SUPABASE_URL && SUPABASE_KEY) {
  supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
}

function isDataUrl(s) {
  return typeof s === 'string' && s.startsWith('data:');
}

function parseDataUrl(dataUrl) {
  const match = dataUrl.match(/^data:(.+);base64,(.*)$/);
  if (!match) return null;
  const contentType = match[1];
  const data = Buffer.from(match[2], 'base64');
  return { contentType, data };
}

async function bufferFromUrl(url) {
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`Failed to fetch image URL: ${resp.status}`);
  const arrayBuf = await resp.arrayBuffer();
  return Buffer.from(arrayBuf);
}

async function uploadImage(dataOrUrl) {
  // dataOrUrl: data URL (data:image/png;base64,...) or remote http(s) url
  if (!supabase) {
    return { url: 'https://supabase.example/generated-image.jpg', path: null };
  }

  let buffer;
  let contentType = 'image/png';

  if (isDataUrl(dataOrUrl)) {
    const parsed = parseDataUrl(dataOrUrl);
    if (!parsed) throw new Error('Invalid data URL');
    buffer = parsed.data;
    contentType = parsed.contentType || contentType;
  } else if (typeof dataOrUrl === 'string' && (dataOrUrl.startsWith('http://') || dataOrUrl.startsWith('https://'))) {
    buffer = await bufferFromUrl(dataOrUrl);
    // best-effort: try to infer content type from url extension
    if (dataOrUrl.endsWith('.jpg') || dataOrUrl.endsWith('.jpeg')) contentType = 'image/jpeg';
    else if (dataOrUrl.endsWith('.webp')) contentType = 'image/webp';
  } else if (Buffer.isBuffer(dataOrUrl)) {
    buffer = dataOrUrl;
  } else {
    throw new Error('Unsupported image input for uploadImage');
  }

  const filename = `${Date.now()}-${Math.random().toString(36).slice(2, 9)}.png`;
  const path = `${filename}`;

  const res = await supabase.storage.from(BUCKET).upload(path, buffer, {
    contentType,
    upsert: false
  });

  if (res.error) {
    // if file conflict, try upsert
    if (res.error.status === 409) {
      const res2 = await supabase.storage.from(BUCKET).upload(path, buffer, { contentType, upsert: true });
      if (res2.error) throw res2.error;
    } else {
      throw res.error;
    }
  }

  const { data: publicData } = supabase.storage.from(BUCKET).getPublicUrl(path);
  const publicUrl = publicData && publicData.publicUrl ? publicData.publicUrl : null;

  return { url: publicUrl, path };
}

async function insertGenerationRecord(record) {
  if (!supabase) {
    return { id: 'stub-gen-123', record };
  }

  // recommended columns: original_image_url, generated_image_url, pass1_image_url, planner_metadata, final_prompt, negative_prompt, denoise, controlnet_strength, cfg_scale, style_mode, transformation_intensity, runpod_job_ids, status
  const payload = {
    ...record,
    created_at: new Date().toISOString()
  };

  const { data, error } = await supabase.from(TABLE).insert([payload]).select();
  if (error) throw error;
  return data && data[0] ? data[0] : { id: null, payload };
}

module.exports = { uploadImage, insertGenerationRecord };
