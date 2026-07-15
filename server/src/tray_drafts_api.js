import { pool, ensureCustomerTrayDraftsSchema } from './db.js';
import {
  customerAccountCustomerIdFromRequest,
  resolveCustomerAccountCustomerId,
} from './customer_auth.js';
import { parseRestaurantOrderTrayItems } from './order_schema.js';

async function customerIdFromReq(req) {
  if (req.customer?.customerId) return String(req.customer.customerId);
  const raw = req.customer?.id ? String(req.customer.id) : null;
  return raw
    ? resolveCustomerAccountCustomerId(raw)
    : customerAccountCustomerIdFromRequest(req);
}

function parseItemsArray(raw) {
  return parseRestaurantOrderTrayItems(raw);
}

function asTrayObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

/** Canonical tray line shape shared by web + mobile in `tray_items`. */
export function normalizeTrayLineItem(raw) {
  const m = asTrayObject(raw);
  const dish = asTrayObject(m.dish ?? m.menu_item ?? m.menuItem);

  const dishId = String(
    m.dish_id ??
      m.dishId ??
      m.menu_dish_id ??
      m.menuDishId ??
      m.menu_id ??
      m.menuId ??
      m.item_id ??
      m.itemId ??
      dish.id ??
      m.id ??
      '',
  ).trim();
  if (!dishId) return null;

  const qty = Math.max(
    1,
    Number(m.quantity ?? m.qty ?? m.dip_qty ?? 1) || 1,
  );
  const sauceRaw =
    m.selected_sauce ??
    m.selectedSauce ??
    (m.dip && String(m.dip).trim() ? m.dip : null);
  const sauceStr = sauceRaw != null ? String(sauceRaw).trim() : '';
  const rawDipQty = Number(m.dip_qty ?? m.addOnQuantity ?? 1);
  const dipQty = sauceStr
    ? Math.max(1, Number.isFinite(rawDipQty) ? Math.floor(rawDipQty) : 1)
    : 1;
  const notes = String(
    m.notes ?? m.special_instructions ?? m.specialInstructions ?? '',
  ).trim();

  return {
    id: dishId,
    dip: sauceStr,
    qty,
    notes,
    dip_qty: dipQty,
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
  if (Array.isArray(b.tray_lines)) return b.tray_lines;
  if (Array.isArray(b.trayLines)) return b.trayLines;
  if (Array.isArray(b.tray_items)) return b.tray_items;
  if (Array.isArray(b.trayItems)) return b.trayItems;
  if (Array.isArray(b.items)) return b.items;
  if (Array.isArray(b.cart)) return b.cart;
  if (b.cart && typeof b.cart === 'object') return itemsFromRequestBody(b.cart);
  return null;
}

function trayItemKey(item) {
  return [
    String(item.id ?? item.dish_id ?? item.dishId ?? '').trim(),
    String(item.dip ?? item.selected_sauce ?? item.selectedSauce ?? '').trim(),
    String(item.notes ?? item.special_instructions ?? item.specialInstructions ?? '').trim(),
    String(item.dip_qty ?? item.addOnQuantity ?? 1),
  ].join('|');
}

function trayLineFromBody(body, keys) {
  const b = body || {};
  for (const key of keys) {
    const line = normalizeTrayLineItem(b[key]);
    if (line) return line;
  }
  const items = itemsFromRequestBody(b);
  return Array.isArray(items) ? normalizeTrayLineItem(items[0]) : null;
}

function trayMatchesFromBody(body) {
  const b = body || {};
  const rawMatches = Array.isArray(b.matches)
    ? b.matches
    : b.match != null
      ? [b.match]
      : itemsFromRequestBody(b);
  return normalizeTrayItems(Array.isArray(rawMatches) ? rawMatches : []);
}

export function mergeTrayItems(existingItems, incomingItems) {
  const merged = new Map();
  for (const item of normalizeTrayItems(existingItems)) {
    merged.set(trayItemKey(item), { ...item });
  }
  for (const item of normalizeTrayItems(incomingItems)) {
    const key = trayItemKey(item);
    const current = merged.get(key);
    if (current) {
      current.qty = Math.max(1, Number(current.qty) || 1) + Math.max(1, Number(item.qty) || 1);
      current.quantity = current.qty;
    } else {
      merged.set(key, { ...item });
    }
  }
  return [...merged.values()];
}

async function upsertTrayDraftItems(customerId, items, { replace = false } = {}) {
  let normalized = normalizeTrayItems(items);
  if (!replace) {
    const existing = await pool.query(
      `SELECT tray_items FROM customer_tray_drafts WHERE customer_id = $1`,
      [customerId],
    );
    const row = existing.rows[0];
    const existingItems = parseItemsArray(row?.tray_items);
    normalized = mergeTrayItems(existingItems, normalized);
  }
  const json = JSON.stringify(normalized);
  await pool.query(
    `INSERT INTO customer_tray_drafts (customer_id, tray_lines, tray_items, updated_at)
     VALUES ($1, $2::jsonb, $2::jsonb, now())
     ON CONFLICT (customer_id) DO UPDATE SET
       tray_lines = EXCLUDED.tray_lines,
       tray_items = EXCLUDED.tray_items,
       updated_at = now()`,
    [customerId, json],
  );
}

async function mutateTrayDraftItems(customerId, mutate) {
  await ensureCustomerTrayDraftsSchema();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const existing = await client.query(
      `SELECT tray_items
       FROM customer_tray_drafts
       WHERE customer_id = $1
       FOR UPDATE`,
      [customerId],
    );
    const currentItems = normalizeTrayItems(
      parseItemsArray(existing.rows[0]?.tray_items),
    );
    const nextItems = normalizeTrayItems(mutate(currentItems));
    const saved = await client.query(
      `INSERT INTO customer_tray_drafts (customer_id, tray_items, updated_at)
       VALUES ($1, $2::jsonb, now())
       ON CONFLICT (customer_id) DO UPDATE SET
         tray_items = EXCLUDED.tray_items,
         updated_at = now()
       RETURNING tray_items, updated_at`,
      [customerId, JSON.stringify(nextItems)],
    );
    await client.query('COMMIT');
    const row = saved.rows[0];
    return {
      items: parseItemsArray(row?.tray_items),
      updatedAt: row?.updated_at?.toISOString?.() ?? row?.updated_at ?? null,
    };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

/** Load tray line items from customer_tray_drafts keyed by customer_id. */
export async function getTrayDraftItemsByCustomerId(customerId) {
  if (!customerId) return [];
  await ensureCustomerTrayDraftsSchema();
  const id = await resolveCustomerAccountCustomerId(customerId);
  const result = await pool.query(
    `SELECT tray_lines, tray_items FROM customer_tray_drafts WHERE customer_id = $1`,
    [id],
  );
  if (result.rowCount === 0) return [];
  const row = result.rows[0];
  const lines = parseItemsArray(row.tray_lines);
  const items = parseItemsArray(row.tray_items);
  return items.length > 0 ? items : lines;
}

export async function getTrayDraft(req, res) {
  try {
    await ensureCustomerTrayDraftsSchema();
    console.debug && console.debug('getTrayDraft: resolving customer id from request');
    const customerId = await customerIdFromReq(req);
    if (!customerId) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    console.debug && console.debug('getTrayDraft: customerId resolved', customerId);
    const result = await pool.query(
      `SELECT tray_lines, tray_items, updated_at FROM customer_tray_drafts WHERE customer_id = $1`,
      [customerId],
    );
    console.debug && console.debug('getTrayDraft: db result rowCount', result.rowCount, 'row', result.rows[0]);
    if (result.rowCount === 0) {
      return res.json({
        success: true,
        items: [],
        tray_lines: [],
        tray_items: [],
        updatedAt: null,
      });
    }
    const row = result.rows[0];
    const trayLines = parseItemsArray(row.tray_lines);
    const trayItems = parseItemsArray(row.tray_items);
    const items = trayItems.length > 0 ? trayItems : trayLines;
    return res.json({
      success: true,
      items,
      tray_lines: items,
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
    const customerId = await customerIdFromReq(req);
    if (!customerId) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    const items = itemsFromRequestBody(req.body);
    if (!Array.isArray(items)) {
      return res.status(400).json({
        error: 'items or tray_items array is required',
      });
    }
    const replace = req.body?.replace === true || req.body?.mode === 'replace';
    await upsertTrayDraftItems(customerId, items, { replace });
    const saved = await pool.query(
      `SELECT tray_lines, tray_items, updated_at FROM customer_tray_drafts WHERE customer_id = $1`,
      [customerId],
    );
    const row = saved.rows[0];
    const trayLines = row ? parseItemsArray(row.tray_lines) : [];
    const trayItems = row ? parseItemsArray(row.tray_items) : [];
    const itemsSaved = trayItems.length > 0 ? trayItems : trayLines;
    res.json({
      success: true,
      items: itemsSaved,
      tray_lines: trayLines.length > 0 ? trayLines : itemsSaved,
      tray_items: itemsSaved,
      updatedAt: row?.updated_at?.toISOString?.() ?? row?.updated_at ?? null,
    });
  } catch (error) {
    console.error('saveTrayDraft:', error);
    res.status(500).json({ error: 'Failed to save tray draft' });
  }
}

export async function updateTrayDraftLine(req, res) {
  try {
    const customerId = await customerIdFromReq(req);
    if (!customerId) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    const nextLine = trayLineFromBody(req.body, ['item', 'line', 'next']);
    if (!nextLine) {
      return res.status(400).json({ error: 'item line is required' });
    }
    const matchLine =
      trayLineFromBody(req.body, ['match', 'previous', 'old']) ?? nextLine;
    const matchKey = trayItemKey(matchLine);
    const nextKey = trayItemKey(nextLine);

    const saved = await mutateTrayDraftItems(customerId, (items) => {
      const next = [...items];
      const matchIndex = next.findIndex((item) => trayItemKey(item) === matchKey);
      if (matchIndex >= 0) {
        const mergeIndex = next.findIndex(
          (item, index) => index !== matchIndex && trayItemKey(item) === nextKey,
        );
        if (mergeIndex >= 0) {
          next[mergeIndex].qty =
            Math.max(1, Number(next[mergeIndex].qty) || 1) +
            Math.max(1, Number(nextLine.qty) || 1);
          next[mergeIndex].quantity = next[mergeIndex].qty;
          next.splice(matchIndex, 1);
        } else {
          next[matchIndex] = nextLine;
        }
        return next;
      }

      const existingNextIndex = next.findIndex(
        (item) => trayItemKey(item) === nextKey,
      );
      if (existingNextIndex >= 0) {
        next[existingNextIndex] = nextLine;
        return next;
      }
      return [...next, nextLine];
    });

    res.json({
      success: true,
      items: saved.items,
      tray_items: saved.items,
      updatedAt: saved.updatedAt,
    });
  } catch (error) {
    console.error('updateTrayDraftLine:', error);
    res.status(500).json({ error: 'Failed to update tray line' });
  }
}

export async function removeTrayDraftLine(req, res) {
  try {
    const customerId = await customerIdFromReq(req);
    if (!customerId) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    const matches = trayMatchesFromBody(req.body);
    if (matches.length === 0) {
      return res.status(400).json({ error: 'match line is required' });
    }
    const keysToRemove = new Set(matches.map((item) => trayItemKey(item)));
    const saved = await mutateTrayDraftItems(
      customerId,
      (items) => items.filter((item) => !keysToRemove.has(trayItemKey(item))),
    );

    res.json({
      success: true,
      items: saved.items,
      tray_items: saved.items,
      updatedAt: saved.updatedAt,
    });
  } catch (error) {
    console.error('removeTrayDraftLine:', error);
    res.status(500).json({ error: 'Failed to remove tray line' });
  }
}

export async function clearTrayDraftForCustomer(customerId) {
  if (!customerId) return;
  await ensureCustomerTrayDraftsSchema();
  const id = await resolveCustomerAccountCustomerId(customerId);
  await pool.query(`DELETE FROM customer_tray_drafts WHERE customer_id = $1`, [
    id,
  ]);
}

export async function clearTrayDraft(req, res) {
  try {
    await ensureCustomerTrayDraftsSchema();
    const customerId = await customerIdFromReq(req);
    if (!customerId) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    await pool.query(
      `DELETE FROM customer_tray_drafts WHERE customer_id = $1`,
      [customerId],
    );
    res.json({ success: true, updatedAt: new Date().toISOString() });
  } catch (error) {
    console.error('clearTrayDraft:', error);
    res.status(500).json({ error: 'Failed to clear tray draft' });
  }
}
