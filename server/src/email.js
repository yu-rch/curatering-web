const RESEND_API_URL = "https://api.resend.com/emails";
const SEND_TIMEOUT_MS = Number(process.env.RESEND_TIMEOUT_MS || 20000);

export function isEmailConfigured() {
  return !!(
    process.env.RESEND_API_KEY?.trim() && process.env.RESEND_FROM?.trim()
  );
}

/**
 * Send via Resend REST API (HTTPS). Avoids SMTP — Railway often blocks or times out on smtp.resend.com:465.
 * @param {{ to: string | string[]; subject: string; text?: string; html?: string }} opts
 */
export async function sendEmail({ to, subject, text, html }) {
  const apiKey = process.env.RESEND_API_KEY?.trim();
  const from = process.env.RESEND_FROM?.trim();
  if (!apiKey) throw new Error("RESEND_API_KEY is not set");
  if (!from) throw new Error("RESEND_FROM is not set");

  const recipients = Array.isArray(to) ? to : [to];
  const body = { from, to: recipients, subject };
  if (html) body.html = html;
  if (text) body.text = text;
  if (!html && !text) body.text = "";

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), SEND_TIMEOUT_MS);

  let response;
  try {
    response = await fetch(RESEND_API_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
  } catch (err) {
    if (err?.name === "AbortError") {
      throw new Error(
        `Resend API timed out after ${SEND_TIMEOUT_MS}ms (check outbound HTTPS from Railway)`,
      );
    }
    const msg = err?.message || String(err);
    if (/timeout|ETIMEDOUT|ECONNREFUSED|ENOTFOUND/i.test(msg)) {
      throw new Error(
        `Cannot reach api.resend.com: ${msg}. Use Resend HTTP API, not SMTP.`,
      );
    }
    throw err;
  } finally {
    clearTimeout(timer);
  }

  const raw = await response.text();
  let parsed;
  try {
    parsed = raw ? JSON.parse(raw) : {};
  } catch {
    parsed = { raw };
  }

  if (!response.ok) {
    const detail =
      parsed?.message ||
      parsed?.error?.message ||
      (typeof parsed === "string" ? parsed : JSON.stringify(parsed));
    const msg = `Resend API ${response.status}: ${detail}`;
    console.error("[email]", msg, { from, to: recipients, subject });
    const err = new Error(msg);
    err.status = response.status;
    err.resend = parsed;
    throw err;
  }

  const id = parsed?.id;
  console.log("[email] sent via HTTPS", {
    id,
    to: recipients,
    subject,
    from,
  });
  return parsed;
}

export function logEmailStartupStatus() {
  if (!isEmailConfigured()) {
    console.warn(
      "[email] Not configured — set RESEND_API_KEY and RESEND_FROM on Railway.",
    );
    return;
  }
  console.log(
    "[email] Resend HTTPS API ready (api.resend.com, not SMTP). FROM:",
    process.env.RESEND_FROM.trim(),
  );
}
