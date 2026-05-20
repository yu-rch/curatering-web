import { pool, ensureCustomerTrayDraftsSchema } from './db.js';
import { parseRestaurantOrderTrayItems } from './order_schema.js';

function customerIdFromReq(req) {
  return req.customer?.id ? String(req.customer.id) : null;
}

function parseItemsArray(raw) {
  return parseRestaurantOrderTrayItems(raw);
}

function asTrayObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

/**
 * Canonical tray line shape for web + mobile (stored in `tray_items` only).
 * Includes nested `dish` (web) and flat/snake fields (mobile).
 */
export function normalizeTrayLineItem(raw) {
  const m = asTrayObject(raw);
  const dish = asTrayObject(m.dish ?? m.menu_item ?? m.menuItem);

  const dishId = String(
    m.dish_id ?? m.dishId ?? m.menu_dish_id ?? dish.id ?? m.id ?? '',
  ).trim();
  if (!dishId) return null;

  const dishName = String(
    m.dish_name ?? m.dishName ?? m.item_name ?? m.name ?? dish.name ?? 'Item',
  ).trim();
  const priceRaw = m.dish_price ?? m.dishPrice ?? m.price ?? dish.price ?? 0;
  const priceNum = Number(priceRaw) || 0;
  const priceStr = String(priceRaw);

  const qty = Math.max(
    1,
    Number(m.quantity ?? m.qty ?? m.dip_qty ?? 1) || 1,
  );
  const sauceRaw =
    m.selected_sauce ??
    m.selectedSauce ??
    (m.dip && String(m.dip).trim() ? m.dip : null);
  const sauceStr = sauceRaw != null ? String(sauceRaw).trim() : '';

  const category = String(
    m.dish_category ?? m.dishCategory ?? dish.category ?? 'restaurant',
  );
  const dishType = String(m.dish_type ?? m.dishType ?? dish.type ?? '');
  const mealType = String(
    m.meal_type ?? m.mealType ?? dish.meal_type ?? dish.mealType ?? '',
  );

  return {
    dishId,
    dish_id: dishId,
    dishName,
    dish_name: dishName,
    name: dishName,
    item_name: dishName,
    dishPrice: priceStr,
    dish_price: priceStr,
    price: priceNum,
    quantity: qty,
    qty,
    selectedSauce: sauceStr || null,
    selected_sauce: sauceStr || null,
    dip: sauceStr,
    dip_qty: sauceStr ? qty : 0,
    dish_category: category,
    dishCategory: category,
    dish_type: dishType,
    dishType,
    meal_type: mealType,
    mealType,
    dish: {
      id: dishId,
      name: dishName,
      price: priceStr,
      category,
      type: dishType,
      mealType,
      meal_type: mealType,
    },
  };
}

export function normalizeTrayItems(items) {
  if (!Array.isArray(items)) return [];
  const out = [];
  for (const raw of items) {
    const line = normalizeTrayLineItem(raw);
    if (line) out.push(line);
  }
  return out;
}

function itemsFromRequestBody(body) {
  const b = body || {};
  if (Array.isArray(b.tray_items)) return b.tray_items;
  if (Array.isArray(b.trayItems)) return b.trayItems;
  if (Array.isArray(b.items)) return b.items;
  return null;
}

async function upsertTrayDraftItems(customerId, items) {
  const normalized = normalizeTrayItems(items);
  const json = JSON.stringify(normalized);
  await pool.query(
    `INSERT INTO customer_tray_drafts (customer_id, tray_items, updated_at)
     VALUES ($1, $2::jsonb, now())
     ON CONFLICT (customer_id) DO UPDATE SET
       tray_items = EXCLUDED.tray_items,
       updated_at = now()`,
    [customerId, json],
  );
}

/** Load tray line items from customer_tray_drafts keyed by customer_id. */
export async function getTrayDraftItemsByCustomerId(customerId) {
  if (!customerId) return [];
  await ensureCustomerTrayDraftsSchema();
  const id = String(customerId);
  const result = await pool.query(
    `SELECT tray_items FROM customer_tray_drafts WHERE customer_id = $1`,
    [id],
  );
  if (result.rowCount === 0) return [];
  return parseItemsArray(result.rows[0].tray_items);
}

export async function getTrayDraft(req, res) {
  try {
    await ensureCustomerTrayDraftsSchema();
    const customerId = customerIdFromReq(req);
    if (!customerId) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    const result = await pool.query(
      `SELECT tray_items, updated_at FROM customer_tray_drafts WHERE customer_id = $1`,
      [customerId],
    );
    if (result.rowCount === 0) {
      return res.json({ success: true, items: [], tray_items: [], updatedAt: null });
    }
    const row = result.rows[0];
    const items = parseItemsArray(row.tray_items);
    return res.json({
      success: true,
      items,
      tray_items: items,
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
    const items = itemsFromRequestBody(req.body);
    if (!Array.isArray(items)) {
      return res.status(400).json({
        error: 'items or tray_items array is required',
      });
    }
    await upsertTrayDraftItems(customerId, items);
    const saved = await pool.query(
      `SELECT tray_items, updated_at FROM customer_tray_drafts WHERE customer_id = $1`,
      [customerId],
    );
    const row = saved.rows[0];
    const trayItems = row ? parseItemsArray(row.tray_items) : [];
    res.json({
      success: true,
      items: trayItems,
      tray_items: trayItems,
      updatedAt: row?.updated_at?.toISOString?.() ?? row?.updated_at ?? null,
    });
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
