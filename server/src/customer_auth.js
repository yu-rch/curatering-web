import jwt from "jsonwebtoken";
import { getTableColumnNames, pool } from "./db.js";

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

/**
 * Resolve the customer-facing id used by child tables (`customer_id`) from a
 * token/account id. Production schemas may store this in
 * customer_accounts.customer_id while JWTs still carry customer_accounts.id.
 */
export async function resolveCustomerAccountCustomerId(accountOrCustomerId) {
  const raw = String(accountOrCustomerId ?? "").trim();
  if (!raw) return null;

  try {
    const cols = await getTableColumnNames("customer_accounts");
    if (cols.size === 0) return raw;

    const selectExpr = cols.has("customer_id")
      ? "customer_id::text"
      : cols.has("customer_code")
        ? "customer_code::text"
        : "id::text";
    const whereParts = ["id::text = $1"];
    if (cols.has("customer_id")) whereParts.push("customer_id::text = $1");
    if (cols.has("customer_code")) whereParts.push("customer_code::text = $1");

    const result = await pool.query(
      `SELECT ${selectExpr} AS customer_id
       FROM customer_accounts
       WHERE ${whereParts.join(" OR ")}
       LIMIT 1`,
      [raw],
    );
    const resolved = result.rows[0]?.customer_id;
    return resolved != null && String(resolved).trim() !== ""
      ? String(resolved).trim()
      : raw;
  } catch {
    return raw;
  }
}

export async function customerAccountCustomerIdFromRequest(req) {
  const tokenCustomerId = customerIdFromRequest(req);
  return resolveCustomerAccountCustomerId(tokenCustomerId);
}
