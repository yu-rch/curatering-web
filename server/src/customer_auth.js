import jwt from "jsonwebtoken";

const JWT_SECRET = process.env.JWT_SECRET || "dev-change-me";

/**
 * Verify customer JWT from Authorization Bearer or legacy customer_token header.
 * @returns {string|null} customer account id
 */
export function customerIdFromRequest(req) {
  const bearer = req.headers.authorization?.replace(/^Bearer\s+/i, "").trim();
  const legacy = String(
    req.headers.customer_token ||
      req.headers["customer-token"] ||
      req.headers["x-customer-token"] ||
      "",
  ).trim();
  const raw = bearer || legacy;
  if (!raw) return null;
  try {
    const decoded = jwt.verify(raw, JWT_SECRET);
    if (decoded.role !== "customer") return null;
    const id = decoded.customerId ?? decoded.id ?? decoded.sub;
    return id != null && String(id).trim() !== "" ? String(id).trim() : null;
  } catch {
    return null;
  }
}

export function requireCustomerId(req, res) {
  const id = customerIdFromRequest(req);
  if (!id) {
    res.status(401).json({ error: "Authentication required" });
    return null;
  }
  return id;
}
