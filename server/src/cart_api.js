import {
  pool,
  ensureCustomerTrayDraftsSchema,
  getTableColumnNames,
} from "./db.js";
import { customerAccountCustomerIdFromRequest } from "./customer_auth.js";
import { mergeTrayItems, normalizeTrayItems } from "./tray_drafts_api.js";

function itemsArrayFromPayload(payload) {
  if (Array.isArray(payload)) return payload;
  if (!payload || typeof payload !== "object") return null;
  for (const key of [
    "tray_lines",
    "trayLines",
    "tray_items",
    "trayItems",
    "items",
    "cart",
  ]) {
    const nested = itemsArrayFromPayload(payload[key]);
    if (nested) return nested;
  }
  return null;
}

function cartItemsFromBody(body) {
  return itemsArrayFromPayload(body) ?? [];
}

function parseTrayItems(raw) {
  if (Array.isArray(raw)) return raw;
  if (typeof raw === "string" && raw.trim()) {
    try {
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  return [];
}

function normalizedTrayItems(raw) {
  return normalizeTrayItems(parseTrayItems(raw));
}

async function customerEmail(customerId) {
  const cols = await getTableColumnNames("customer_accounts");
  const whereParts = ["id::text = $1"];
  if (cols.has("customer_id")) whereParts.push("customer_id::text = $1");
  if (cols.has("customer_code")) whereParts.push("customer_code::text = $1");
  const result = await pool.query(
    `SELECT email
     FROM customer_accounts
     WHERE ${whereParts.join(" OR ")}
     LIMIT 1`,
    [String(customerId)],
  );
  return result.rows[0]?.email ?? null;
}

class CartAPI {
  static async getCart(req, res) {
    try {
      const customerId = await customerAccountCustomerIdFromRequest(req);
      if (!customerId) {
        return res.status(401).json({ error: "Authentication required" });
      }

      await ensureCustomerTrayDraftsSchema();
      const result = await pool.query(
        `SELECT tray_lines, tray_items, user_email, updated_at
         FROM customer_tray_drafts
         WHERE customer_id = $1
         LIMIT 1`,
        [customerId],
      );

      const row = result.rows[0];
      const trayLines = normalizedTrayItems(row?.tray_lines);
      const trayItems = normalizedTrayItems(row?.tray_items);
      const items = trayItems.length > 0 ? trayItems : trayLines;
      const cart = {
        items,
        tray_lines: items,
        tray_items: items,
        user_email: row?.user_email ?? null,
        last_sync: row?.updated_at ?? null,
      };

      res.json({ success: true, cart });
    } catch (error) {
      console.error("Error getting cart:", error);
      res.status(500).json({ error: "Failed to get cart" });
    }
  }

  static async syncCart(req, res) {
    let client;
    try {
      const customerId = await customerAccountCustomerIdFromRequest(req);
      if (!customerId) {
        return res.status(401).json({ error: "Authentication required" });
      }

      const { timestamp } = req.body || {};
      const incoming = normalizeTrayItems(cartItemsFromBody(req.body));
      const replace = req.body?.replace === true || req.body?.mode === "replace";
      const email = await customerEmail(customerId);

      client = await pool.connect();
      await client.query("BEGIN");
      await ensureCustomerTrayDraftsSchema();
      const existing = await client.query(
        `SELECT tray_items, tray_lines
         FROM customer_tray_drafts
         WHERE customer_id = $1
         LIMIT 1`,
        [customerId],
      );
      const row = existing.rows[0];
      const existingItems =
        normalizedTrayItems(row?.tray_items).length > 0
          ? normalizedTrayItems(row?.tray_items)
          : normalizedTrayItems(row?.tray_lines);
      const cart = replace ? incoming : mergeTrayItems(existingItems, incoming);
      await client.query(
        `INSERT INTO customer_tray_drafts (customer_id, user_email, tray_lines, tray_items, updated_at)
         VALUES ($1, $2, $3::jsonb, $3::jsonb, now())
         ON CONFLICT (customer_id) DO UPDATE SET
           user_email = EXCLUDED.user_email,
           tray_lines = EXCLUDED.tray_lines,
           tray_items = EXCLUDED.tray_items,
           updated_at = now()`,
        [customerId, email, JSON.stringify(cart)],
      );

      await client.query("COMMIT");

      res.json({
        success: true,
        customer_id: customerId,
        user_email: email,
        items: cart,
        tray_lines: cart,
        tray_items: cart,
        timestamp: timestamp ?? null,
      });
    } catch (error) {
      if (client) {
        await client.query("ROLLBACK").catch(() => {});
      }
      console.error("Error syncing cart:", error);
      res.status(500).json({ error: "Failed to sync cart" });
    } finally {
      client?.release();
    }
  }

  static async clearCart(req, res) {
    try {
      const customerId = await customerAccountCustomerIdFromRequest(req);
      if (!customerId) {
        return res.status(401).json({ error: "Authentication required" });
      }

      await ensureCustomerTrayDraftsSchema();
      await pool.query(
        `UPDATE customer_tray_drafts
         SET tray_lines = '[]'::jsonb,
             tray_items = '[]'::jsonb,
             updated_at = now()
         WHERE customer_id = $1`,
        [customerId],
      );

      res.json({ success: true });
    } catch (error) {
      console.error("Error clearing cart:", error);
      res.status(500).json({ error: "Failed to clear cart" });
    }
  }
}

export default CartAPI;
