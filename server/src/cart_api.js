import express from 'express';
import { pool } from './db.js';

class CartAPI {
  static async getCart(req, res) {
    try {
      const { customer_token } = req.headers;
      
      if (!customer_token) {
        return res.status(401).json({ error: 'Authentication required' });
      }

      const result = await pool.query(`
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
      `);

      const cart = {
        items: result.rows,
        device_id: result.rows[0]?.device_id,
        last_sync: result.rows[0]?.updated_at
      };

      res.json({ success: true, cart });
    } catch (error) {
      console.error('Error getting cart:', error);
      res.status(500).json({ error: 'Failed to get cart' });
    }
  }

  static async syncCart(req, res) {
    try {
      const { customer_token } = req.headers;
      const { cart, device_id, timestamp } = req.body;
      
      if (!customer_token) {
        return res.status(401).json({ error: 'Authentication required' });
      }

      // Start transaction
      await pool.query('BEGIN');

      // Get or create cart session
      let sessionResult = await pool.query(`
        SELECT id FROM cart_sessions 
        WHERE customer_token = $1 AND device_id = $2
        ORDER BY updated_at DESC 
        LIMIT 1
      `, [customer_token, device_id]);

      let sessionId;
      if (sessionResult.rows.length === 0) {
        // Create new session
        const newSession = await pool.query(`
          INSERT INTO cart_sessions (customer_token, device_id)
          VALUES ($1, $2)
          RETURNING id
        `, [customer_token, device_id]);
        
        sessionId = newSession.rows[0].id;
      } else {
        sessionId = sessionResult.rows[0].id;
      }

      // Clear existing items for this session
      await pool.query(`
        DELETE FROM cart_items 
        WHERE session_id = $1
      `, [sessionId]);

      // Insert new cart items
      if (cart && cart.length > 0) {
        const values = cart.map(item => [
          sessionId,
          item.dish_id,
          item.dish_name,
          item.dish_price,
          item.dish_category,
          item.dish_type,
          item.quantity,
          item.selected_sauce
        ]);

        const placeholders = cart.map(() => '($1, $2, $3, $4, $5, $6, $7, $8)').join(', ');

        await pool.query(`
          INSERT INTO cart_items (session_id, dish_id, dish_name, dish_price, dish_category, dish_type, quantity, selected_sauce, updated_at)
          VALUES ${placeholders.join(', ')}
        `, values.flat());
      }

      // Update session timestamp
      await pool.query(`
        UPDATE cart_sessions 
        SET updated_at = NOW()
        WHERE id = $1
      `, [sessionId]);

      await pool.query('COMMIT');

      res.json({ success: true, session_id: sessionId });
    } catch (error) {
      await pool.query('ROLLBACK');
      console.error('Error syncing cart:', error);
      res.status(500).json({ error: 'Failed to sync cart' });
    }
  }

  static async clearCart(req, res) {
    try {
      const { customer_token } = req.headers;
      
      if (!customer_token) {
        return res.status(401).json({ error: 'Authentication required' });
      }

      // Get session and clear items
      const sessionResult = await pool.query(`
        SELECT id FROM cart_sessions 
        WHERE customer_token = $1
        ORDER BY updated_at DESC 
        LIMIT 1
      `, [customer_token]);

      if (sessionResult.rows.length > 0) {
        const sessionId = sessionResult.rows[0].id;

        await pool.query('BEGIN');

        // Clear items
        await pool.query(`
          DELETE FROM cart_items 
          WHERE session_id = $1
        `, [sessionId]);

        // Update session timestamp
        await pool.query(`
          UPDATE cart_sessions 
          SET updated_at = NOW()
          WHERE id = $1
        `, [sessionId]);

        await pool.query('COMMIT');
      }

      res.json({ success: true });
    } catch (error) {
      await pool.query('ROLLBACK');
      console.error('Error clearing cart:', error);
      res.status(500).json({ error: 'Failed to clear cart' });
    }
  }
}

export default CartAPI;
