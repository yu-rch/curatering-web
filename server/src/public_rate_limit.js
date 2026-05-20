/**
* Simple in-memory rate limiter for unauthenticated public API routes.
 */ 
export function createPublicRateLimiter({
  windowMs = 60_000,
  max = Number(process.env.PUBLIC_API_RATE_LIMIT_PER_MIN || 20),
} = {}) {
  const hits = new Map();

  return function publicRateLimit(req, res, next) {
    if (String(process.env.DISABLE_PUBLIC_RATE_LIMIT || "") === "1") {
      return next();
    }
    const forwarded = req.headers["x-forwarded-for"];
    const ip =
      (typeof forwarded === "string" ? forwarded.split(",")[0].trim() : "") ||
      req.socket?.remoteAddress ||
      "unknown";
    const now = Date.now();
    let bucket = hits.get(ip);
    if (!bucket || now > bucket.resetAt) {
      bucket = { count: 0, resetAt: now + windowMs };
      hits.set(ip, bucket);
    }
    bucket.count += 1;
    if (bucket.count > max) {
      return res.status(429).json({
        message: "Too many requests — try again shortly",
        code: "rate_limited",
      });
    }
    return next();
  };
}
