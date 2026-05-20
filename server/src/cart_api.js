import { pool, ensureCustomerTrayDraftsSchema } from "./db.js";
import { requireCustomerId } from "./customer_auth.js";

function cartItemsFromBody(body) {
  const raw = body?.cart ?? body?.items ?? body?.tray_items ?? [];
  return Array.isArray(raw) ? raw : [];
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

async function customerEmail(customerId) {
  const result = await pool.query(
    `SELECT email FROM customer_accounts WHERE id::text = $1 LIMIT 1`,
    [String(customerId)],
  );
  return result.rows[0]?.email ?? null;
}

class CartAPI {
  static async getCart(req, res) {
    try {
      const customerId = requireCustomerId(req, res);
      if (!customerId) return;

      await ensureCustomerTrayDraftsSchema();
      const result = await pool.query(
        `SELECT tray_items, user_email, updated_at
         FROM customer_tray_drafts
         WHERE customer_id = $1
         LIMIT 1`,
        [customerId],
      );

      const row = result.rows[0];
      const cart = {
        items: parseTrayItems(row?.tray_items),
        tray_items: parseTrayItems(row?.tray_items),
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
      const customerId = requireCustomerId(req, res);
      if (!customerId) return;

      const { timestamp } = req.body || {};
      const cart = cartItemsFromBody(req.body);
      const email = await customerEmail(customerId);

      client = await pool.connect();
      await client.query("BEGIN");
      await ensureCustomerTrayDraftsSchema();
      await client.query(
        `INSERT INTO customer_tray_drafts (customer_id, user_email, tray_items, updated_at)
         VALUES ($1, $2, $3::jsonb, now())
         ON CONFLICT (customer_id) DO UPDATE SET
           user_email = EXCLUDED.user_email,
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
      const customerId = requireCustomerId(req, res);
      if (!customerId) return;

      await ensureCustomerTrayDraftsSchema();
      await pool.query(
        `UPDATE customer_tray_drafts
         SET tray_items = '[]'::jsonb,
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
