import { pool, ensureCustomerTrayDraftsSchema } from './db.js';

function customerIdFromReq(req) {
  return req.customer?.id ? String(req.customer.id) : null;
}

/** Load tray line items from customer_tray_drafts keyed by customer_id. */
export async function getTrayDraftItemsByCustomerId(customerId) {
  if (!customerId) return [];
  await ensureCustomerTrayDraftsSchema();
  const id = String(customerId);
  const result = await pool.query(
    `SELECT items FROM customer_tray_drafts WHERE customer_id = $1`,
    [id],
  );
  if (result.rowCount === 0) return [];
  const items = result.rows[0].items;
  if (Array.isArray(items)) return items;
  if (typeof items === 'string' && items.trim()) {
    try {
      const parsed = JSON.parse(items);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  return [];
}

export async function getTrayDraft(req, res) {
  try {
    await ensureCustomerTrayDraftsSchema();
    const customerId = customerIdFromReq(req);
    if (!customerId) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    const result = await pool.query(
      `SELECT items, updated_at FROM customer_tray_drafts WHERE customer_id = $1`,
      [customerId],
    );
    if (result.rowCount === 0) {
      return res.json({ success: true, items: [], updatedAt: null });
    }
    const row = result.rows[0];
    return res.json({
      success: true,
      items: row.items ?? [],
      updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at,
    });
  } catch (error) {
    console.error('getTrayDraft:', error);
    res.status(500).json({ error: 'Failed to load tray draft' });
  }
}

export async function saveTrayDraft(req, res) {
  try {
    await ensureCustomerTrayDraftsSchema();
    const customerId = customerIdFromReq(req);
    if (!customerId) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    const { items } = req.body || {};
    if (!Array.isArray(items)) {
      return res.status(400).json({ error: 'items array is required' });
    }
    await pool.query(
      `INSERT INTO customer_tray_drafts (customer_id, items, updated_at)
       VALUES ($1, $2::jsonb, now())
       ON CONFLICT (customer_id) DO UPDATE SET
         items = EXCLUDED.items,
         updated_at = now()`,
      [customerId, JSON.stringify(items)],
    );
    res.json({ success: true });
  } catch (error) {
    console.error('saveTrayDraft:', error);
    res.status(500).json({ error: 'Failed to save tray draft' });
  }
}

export async function clearTrayDraftForCustomer(customerId) {
  if (!customerId) return;
  await ensureCustomerTrayDraftsSchema();
  await pool.query(`DELETE FROM customer_tray_drafts WHERE customer_id = $1`, [
    String(customerId),
  ]);
}

export async function clearTrayDraft(req, res) {
  try {
    await ensureCustomerTrayDraftsSchema();
    const customerId = customerIdFromReq(req);
    if (!customerId) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    await pool.query(
      `DELETE FROM customer_tray_drafts WHERE customer_id = $1`,
      [customerId],
    );
    res.json({ success: true });
  } catch (error) {
    console.error('clearTrayDraft:', error);
    res.status(500).json({ error: 'Failed to clear tray draft' });
  }
}
