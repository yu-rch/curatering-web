import { pool } from "./db.js";
import { requireCustomerId } from "./customer_auth.js";

class CartAPI {
  static async getCart(req, res) {
    try {
      const customerId = requireCustomerId(req, res);
      if (!customerId) return;

      const result = await pool.query(
        `
        SELECT 
          cs.device_id,
          ci.dish_id,
          ci.dish_name,
          ci.dish_price,
          ci.dish_category,
          ci.dish_type,
          ci.quantity,
          ci.selected_sauce,
          ci.created_at,
          ci.updated_at
        FROM cart_sessions cs
        JOIN cart_items ci ON cs.id = ci.session_id
        WHERE cs.customer_token = $1
        ORDER BY ci.created_at DESC
      `,
        [customerId],
      );

      const cart = {
        items: result.rows,
        device_id: result.rows[0]?.device_id,
        last_sync: result.rows[0]?.updated_at,
      };

      res.json({ success: true, cart });
    } catch (error) {
      console.error("Error getting cart:", error);
      res.status(500).json({ error: "Failed to get cart" });
    }
  }

  static async syncCart(req, res) {
    try {
      const customerId = requireCustomerId(req, res);
      if (!customerId) return;

      const { cart, timestamp } = req.body || {};
      const device_id = req.body?.device_id ?? req.body?.deviceId;
      if (!device_id || typeof device_id !== "string") {
        return res.status(400).json({ error: "device_id is required" });
      }

      await pool.query("BEGIN");

      let sessionResult = await pool.query(
        `
        SELECT id FROM cart_sessions 
        WHERE customer_token = $1 AND device_id = $2
        ORDER BY updated_at DESC 
        LIMIT 1
      `,
        [customerId, device_id],
      );

      let sessionId;
      if (sessionResult.rows.length === 0) {
        const newSession = await pool.query(
          `
          INSERT INTO cart_sessions (customer_token, device_id)
          VALUES ($1, $2)
          RETURNING id
        `,
          [customerId, device_id],
        );

        sessionId = newSession.rows[0].id;
      } else {
        sessionId = sessionResult.rows[0].id;
      }

      await pool.query(
        `
        DELETE FROM cart_items 
        WHERE session_id = $1
      `,
        [sessionId],
      );

      if (Array.isArray(cart) && cart.length > 0) {
        const cols = 8;
        const placeholders = cart
          .map((_, rowIdx) => {
            const o = rowIdx * cols;
            return `($${o + 1}, $${o + 2}, $${o + 3}, $${o + 4}, $${o + 5}, $${o + 6}, $${o + 7}, $${o + 8})`;
          })
          .join(", ");

        const values = [];
        for (const item of cart) {
          values.push(
            sessionId,
            item.dish_id ?? item.dishId,
            item.dish_name ?? item.dishName,
            String(item.dish_price ?? item.dishPrice ?? "0"),
            item.dish_category ?? item.dishCategory ?? "",
            item.dish_type ?? item.dishType ?? "",
            Number(item.quantity) || 1,
            item.selected_sauce ?? item.selectedSauce ?? null,
          );
        }

        await pool.query(
          `
          INSERT INTO cart_items (session_id, dish_id, dish_name, dish_price, dish_category, dish_type, quantity, selected_sauce, updated_at)
          VALUES ${placeholders}
        `,
          values,
        );
      }

      await pool.query(
        `
        UPDATE cart_sessions 
        SET updated_at = NOW()
        WHERE id = $1
      `,
        [sessionId],
      );

      await pool.query("COMMIT");

      res.json({
        success: true,
        session_id: sessionId,
        timestamp: timestamp ?? null,
      });
    } catch (error) {
      await pool.query("ROLLBACK").catch(() => {});
      console.error("Error syncing cart:", error);
      res.status(500).json({ error: "Failed to sync cart" });
    }
  }

  static async clearCart(req, res) {
    try {
      const customerId = requireCustomerId(req, res);
      if (!customerId) return;

      const sessionResult = await pool.query(
        `
        SELECT id FROM cart_sessions 
        WHERE customer_token = $1
        ORDER BY updated_at DESC
      `,
        [customerId],
      );

      if (sessionResult.rows.length > 0) {
        const sessionIds = sessionResult.rows.map((r) => r.id);

        await pool.query(
          `
          DELETE FROM cart_items 
          WHERE session_id = ANY($1::uuid[])
        `,
          [sessionIds],
        );

        await pool.query(
          `
          UPDATE cart_sessions 
          SET updated_at = NOW()
          WHERE id = ANY($1::uuid[])
        `,
          [sessionIds],
        );
      }

      res.json({ success: true });
    } catch (error) {
      console.error("Error clearing cart:", error);
      res.status(500).json({ error: "Failed to clear cart" });
    }
  }
}

export default CartAPI;
