/**
 * Canonical restaurant / catering order columns, migrations, and safe SELECT builders.
 * Resolves 42703 errors when production schemas use legacy column names.
 */

import {
  pool,
  getTableColumnNames,
  migrateCateringOrderStatuses,
  CATERING_STATUS_VALUES,
} from './db.js';

/** @deprecated use CATERING_STATUS_VALUES */
export const CATERING_ORDER_STATUSES = CATERING_STATUS_VALUES;

const LEGACY_CATERING_STATUS_MAP = {
  new_event: 'online_inquiries',
  online_inquiry: 'online_inquiries',
  for_downpayment: 'for_down_payment',
  for_processing: 'on_going',
  for_post_analysis: 'on_going',
};

export function normalizeCateringOrderStatus(raw) {
  const s = String(raw ?? 'online_inquiries').trim().toLowerCase();
  if (CATERING_STATUS_VALUES.includes(s)) return s;
  return LEGACY_CATERING_STATUS_MAP[s] ?? 'online_inquiries';
}

function pickCol(cols, candidates) {
  for (const c of candidates) {
    if (cols.has(c)) return c;
  }
  return null;
}

const ONLINE_ORDER_STATUSES = new Set([
  'PENDING_CASHIER',
  'IN_PREPARATION',
  'OUT_FOR_DELIVERY',
  'DELIVERED',
  'CANCELLED',
]);

export function normalizeRestaurantOrderStatus(raw, fallback = 'PENDING_CASHIER') {
  const s = String(raw ?? '').trim().toUpperCase();
  if (!s) return fallback;
  if (s === 'PENDING' || s === 'WAITING FOR ORDER CONFIRMATION') return 'PENDING_CASHIER';
  if (s === 'CONFIRMED' || s === 'PREPARING') return 'IN_PREPARATION';
  if (ONLINE_ORDER_STATUSES.has(s)) return s;
  return fallback;
}

/** Public ORD-0001 id (order_id preferred; order_no legacy). */
export function restaurantOrderIdExpr(cols) {
  if (cols.has('order_id') && cols.has('order_no')) {
    return 'COALESCE(order_id, order_no::text)';
  }
  const col = pickCol(cols, ['order_id', 'order_no']);
  return col ?? 'NULL::text';
}

export function restaurantOrderIdInsertColumn(cols) {
  return pickCol(cols, ['order_id', 'order_no']) ?? 'order_id';
}

/** WHERE fragment: match UUID id or public order id. */
export function restaurantOrderLookupWhereSql(cols, paramIndex) {
  const parts = [];
  if (cols.has('order_id')) parts.push(`order_id = $${paramIndex}`);
  if (cols.has('order_no')) parts.push(`order_no = $${paramIndex}`);
  if (parts.length === 0) return `id::text = $${paramIndex}`;
  return `(${parts.join(' OR ')} OR id::text = $${paramIndex})`;
}

/** Public TR-000001 id column (catering_id preferred; inquiry_id legacy). */
export function cateringIdExpr(cols) {
  if (cols.has('catering_id') && cols.has('inquiry_id')) {
    return 'COALESCE(catering_id, inquiry_id)';
  }
  const col = pickCol(cols, ['catering_id', 'inquiry_id']);
  return col ?? 'NULL::text';
}

export function cateringIdSelectAlias(cols, alias = 'cateringId') {
  return `${cateringIdExpr(cols)} AS "${alias}"`;
}

function sqlExpr(cols, candidates, fallbackSql) {
  const col = pickCol(cols, candidates);
  return col ? col : fallbackSql;
}

let restaurantSchemaPromise = null;
let cateringSchemaPromise = null;

/** Add canonical restaurant_orders columns and backfill from legacy names. */
export async function ensureRestaurantOrdersCanonicalColumns() {
  if (!restaurantSchemaPromise) {
    restaurantSchemaPromise = ensureRestaurantOrdersCanonicalColumnsOnce().catch((e) => {
      restaurantSchemaPromise = null;
      throw e;
    });
  }
  return restaurantSchemaPromise;
}

async function ensureRestaurantOrdersCanonicalColumnsOnce() {
  const cols = await getTableColumnNames('restaurant_orders');
  if (cols.size === 0) return cols;

  if (cols.has('order_no') && !cols.has('order_id')) {
    try {
      await pool.query(
        `ALTER TABLE restaurant_orders RENAME COLUMN order_no TO order_id`,
      );
      cols.delete('order_no');
      cols.add('order_id');
      console.log('[order_schema] Renamed order_no → order_id on restaurant_orders');
    } catch (err) {
      console.warn('[order_schema] restaurant_orders order_no rename:', err.message);
    }
  }

  const adds = [
    ['order_id', 'TEXT'],
    ['id', 'uuid DEFAULT gen_random_uuid()'],
    ['customer_id', 'TEXT'],
    ['mobile_id', "BIGINT"],
    ['order_source', "TEXT NOT NULL DEFAULT 'WEB_APP'"],
    ['total_cost', 'DECIMAL(12,2)'],
    ['tray_items', 'JSONB NOT NULL DEFAULT \'[]\'::jsonb'],
    ['loyalty_points_restaurant_obtained', 'INTEGER NOT NULL DEFAULT 0'],
    ['loyalty_reward_restaurant_obtained', 'TEXT'],
    ['delivery_address', 'TEXT'],
    ['delivery_lat', 'DOUBLE PRECISION'],
    ['delivery_lng', 'DOUBLE PRECISION'],
    ['delivery_notes', 'TEXT'],
    ['delivery_tracking_url', 'TEXT'],
    ['full_name', 'TEXT'],
    ['user_email', 'TEXT'],
    ['payment_mode', "TEXT NOT NULL DEFAULT 'GCASH ONLY'"],
    ['delivery_time', "TEXT DEFAULT 'NOW'"],
    ['payment_reference_initial', 'TEXT'],
    ['payment_reference_balance', 'TEXT'],
    ['payment_proof_initial', 'TEXT'],
    ['payment_proof_balance', 'TEXT'],
    ['payment_uploaded_initial', 'BOOLEAN NOT NULL DEFAULT FALSE'],
    ['payment_uploaded_balance', 'BOOLEAN NOT NULL DEFAULT FALSE'],
    ['payment_confirmed_initial', 'BOOLEAN NOT NULL DEFAULT FALSE'],
    ['payment_confirmed_balance', 'BOOLEAN NOT NULL DEFAULT FALSE'],
    ['order_status', "TEXT NOT NULL DEFAULT 'pending_cashier'"],
    ['contact_number', "TEXT NOT NULL DEFAULT ''"],
    ['cashier_amount_received_initial', 'DECIMAL(12,2)'],
    ['cashier_amount_received_balance', 'DECIMAL(12,2)'],
    ['feedback_stars', 'INTEGER'],
    ['feedback_remarks', 'TEXT'],
    ['amount_paid', 'DECIMAL(10,2)'],
    ['change_given', 'DECIMAL(10,2)'],
    ['payment_method', 'TEXT'],
    ['payment_proof', 'TEXT'],
    ['pos_customer_label', 'TEXT'],
    ['balance_proof_pending_review', 'BOOLEAN NOT NULL DEFAULT FALSE'],
    ['pos_claimed', 'BOOLEAN NOT NULL DEFAULT FALSE'],
    ['pos_claimed_at', 'TIMESTAMPTZ'],
    ['feedback_submitted_at', 'TIMESTAMPTZ'],
    ['note', "TEXT NOT NULL DEFAULT ''"],
    ['payment_uploaded', 'BOOLEAN NOT NULL DEFAULT FALSE'],
    ['submitted_order_dt_stamp', 'TIMESTAMPTZ'],
    ['last_updated_order_status_dt_stamp', 'TIMESTAMPTZ'],
    ['created_at', 'TIMESTAMPTZ NOT NULL DEFAULT now()'],
    ['updated_at', 'TIMESTAMPTZ NOT NULL DEFAULT now()'],
  ];

  for (const [name, typ] of adds) {
    if (!cols.has(name)) {
      try {
        await pool.query(`ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS ${name} ${typ}`);
        cols.add(name);
      } catch (err) {
        console.warn(`[order_schema] restaurant_orders.${name}:`, err.message);
      }
    }
  }

  const syncPairs = [
    ['tray_items', 'items', "COALESCE(NULLIF(tray_items, '[]'::jsonb), items, '[]'::jsonb)"],
    ['total_cost', 'total_amount', 'total_amount'],
    ['order_id', 'order_no', 'order_no::text'],
    ['contact_number', 'phone', 'phone'],
    ['user_email', 'guest_contact_email', 'guest_contact_email'],
    ['payment_mode', 'payment_method', 'payment_method'],
    ['loyalty_points_restaurant_obtained', 'points_earned', 'COALESCE(points_earned, 0)'],
    ['cashier_amount_received_initial', 'cashier_amount_received', 'cashier_amount_received'],
    ['cashier_amount_received_balance', 'cashier_secondary_amount_received', 'cashier_secondary_amount_received'],
    ['payment_reference_initial', 'payment_references_initial', 'payment_references_initial'],
    ['payment_proof_balance', 'supplemental_payment_proof', 'supplemental_payment_proof'],
  ];

  for (const [target, source, expr] of syncPairs) {
    if (cols.has(target) && cols.has(source)) {
      try {
        await pool.query(
          `UPDATE restaurant_orders SET ${target} = ${expr}
           WHERE ${target} IS NULL AND ${source} IS NOT NULL`,
        );
      } catch (_) {
        /* ignore type mismatch */
      }
    }
  }

  if (cols.has('order_id') && cols.has('order_no')) {
    try {
      await pool.query(
        `UPDATE restaurant_orders SET order_id = order_no::text
         WHERE order_id IS NULL AND order_no IS NOT NULL`,
      );
    } catch (_) {}
  }

  if (cols.has('order_status')) {
    try {
      await pool.query(
        `UPDATE restaurant_orders
         SET order_status = CASE
           WHEN upper(COALESCE(order_status::text, '')) IN ('PENDING', 'WAITING FOR ORDER CONFIRMATION') THEN 'pending_cashier'
           WHEN upper(COALESCE(order_status::text, '')) IN ('CONFIRMED', 'PREPARING') THEN 'in_preparation'
           WHEN upper(COALESCE(order_status::text, '')) IN ('PENDING_CASHIER', 'IN_PREPARATION', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED')
             THEN lower(order_status::text)
           ELSE 'pending_cashier'
         END`,
      );
    } catch (err) {
      console.warn('[order_schema] restaurant_orders.order_status normalize:', err.message);
    }
  }

  if (cols.has('order_source')) {
    try {
      await pool.query(
        `UPDATE restaurant_orders
         SET order_source = CASE
           WHEN upper(COALESCE(order_source::text, '')) IN ('POS', 'POS_MOBILE', 'POS_WEB') THEN upper(order_source::text)
           WHEN upper(COALESCE(order_source::text, '')) IN ('MOBILE', 'MOBILE_APP') THEN 'MOBILE_APP'
           WHEN upper(COALESCE(order_source::text, '')) IN ('WEB', 'ONLINE', 'WEB_APP') THEN 'WEB_APP'
           ELSE 'WEB_APP'
         END`,
      );
    } catch (err) {
      console.warn('[order_schema] restaurant_orders.order_source normalize:', err.message);
    }
  }

  try {
    await pool.query(`DROP INDEX IF EXISTS restaurant_orders_order_no_uq`);
  } catch (_) {}

  // Never btree-index the full tray_items jsonb — payloads include (or used to
  // include) dish image_base64 and exceed Postgres' 8191-byte index row limit.
  try {
    await pool.query(`DROP INDEX IF EXISTS idx_restaurant_order_items_dish`);
  } catch (_) {}

  const dropColumns = [
    'items',
    'total_amount',
    'phone',
    'order_no',
    'points_earned',
    'guest_contact_email',
    'loyalty_points_catering_obtained',
    'cashier_secondary_amount_received',
    'payment_status',
    'fulfillment_stage',
    'supplemental_payment_proof',
    'delivery_name',
    'delivery_contact',
    'total',
    'cashier_change',
    'cashier_changer',
    'order_lines_snapshot',
    'payment_references_initial',
  ];
  for (const name of dropColumns) {
    if (cols.has(name)) {
      try {
        await pool.query(`ALTER TABLE restaurant_orders DROP COLUMN IF EXISTS ${name}`);
        cols.delete(name);
        console.log(`[order_schema] Dropped restaurant_orders.${name}`);
      } catch (err) {
        console.warn(`[order_schema] drop restaurant_orders.${name}:`, err.message);
      }
    }
  }

  return cols;
}

/** Catering / event_orders columns + status migration (drops for_post_analysis). */
export async function ensureCateringEventOrdersCanonicalColumns() {
  if (!cateringSchemaPromise) {
    cateringSchemaPromise = ensureCateringEventOrdersCanonicalColumnsOnce().catch((e) => {
      cateringSchemaPromise = null;
      throw e;
    });
  }
  return cateringSchemaPromise;
}

const EVENT_CATERING_COLUMN_DEFS = [
  ['source', 'TEXT'],
  ['status', 'TEXT'],
  ['event_title', 'TEXT'],
  ['event_type', 'TEXT'],
  ['formality_level', 'TEXT'],
  ['customer_name', 'TEXT'],
  ['contact_person', 'TEXT'],
  ['contact_number', 'TEXT'],
  ['email_address', 'TEXT'],
  ['schedule_slots', "JSONB NOT NULL DEFAULT '[]'::jsonb"],
  ['address', 'TEXT'],
  ['guest_count', 'INT DEFAULT 0'],
  ['menu', "JSONB NOT NULL DEFAULT '[]'::jsonb"],
  ['theme_design', "JSONB NOT NULL DEFAULT '{}'::jsonb"],
  ['created_by', 'TEXT'],
  ['updated_by', 'TEXT'],
  ['order_type', 'TEXT'],
  ['down_payment_amount', 'DECIMAL(10,2) DEFAULT 0.00'],
  ['down_payment_status', "TEXT DEFAULT 'pending'"],
  ['full_payment_amount', 'DECIMAL(10,2) DEFAULT 0.00'],
  ['full_payment_status', "TEXT DEFAULT 'pending'"],
  ['total_cost', 'DECIMAL(10,2) DEFAULT 0.00'],
  ['final_status', "TEXT DEFAULT 'successful'"],
  ['customer_id', 'TEXT'],
  ['payment_method', 'TEXT'],
  ['labor_cost', 'DECIMAL(10,2) DEFAULT 0.00'],
  ['travel_cost', 'DECIMAL(10,2) DEFAULT 0.00'],
  ['inquiry_additional_costs', 'DECIMAL(10,2) DEFAULT 0.00'],
  ['stage_additional_costs', 'DECIMAL(10,2) DEFAULT 0.00'],
  ['full_payment_due_at', 'TIMESTAMPTZ'],
  ['stage_entered_at', 'TIMESTAMPTZ'],
  ['down_payment_reference', 'TEXT'],
  ['full_payment_reference', 'TEXT'],
  ['loyalty_points_catering_obtained', 'INTEGER DEFAULT 0'],
  ['loyalty_reward_catering_obtained', 'TEXT'],
  ['feedback_stars', 'INTEGER'],
  ['feedback_remarks', 'TEXT'],
  ['feedback_submitted_at', 'TIMESTAMPTZ'],
  ['address_lat', 'DOUBLE PRECISION'],
  ['address_lng', 'DOUBLE PRECISION'],
  ['seating_plan', "JSONB NOT NULL DEFAULT '{}'::jsonb"],
  ['event_id', 'TEXT'],
  ['pax_buffer', 'INT DEFAULT 0'],
  ['estimated_cost', 'DECIMAL(10,2) DEFAULT 0.00'],
  ['estimated_total', 'DECIMAL(10,2) DEFAULT 0.00'],
  ['allergens', "TEXT NOT NULL DEFAULT ''"],
  ['note', "TEXT NOT NULL DEFAULT ''"],
  ['catering_id', 'TEXT'],
  ['created_at', 'TIMESTAMPTZ NOT NULL DEFAULT now()'],
  ['updated_at', 'TIMESTAMPTZ NOT NULL DEFAULT now()'],
];

async function ensureCateringEventOrdersCanonicalColumnsOnce() {
  for (const table of ['event_orders', 'catering_orders']) {
    const cols = await getTableColumnNames(table);
    if (cols.size === 0) continue;

    if (cols.has('inquiry_id') && !cols.has('catering_id')) {
      try {
        await pool.query(
          `ALTER TABLE ${table} RENAME COLUMN inquiry_id TO catering_id`,
        );
        cols.delete('inquiry_id');
        cols.add('catering_id');
      } catch (err) {
        console.warn(`[order_schema] ${table} inquiry_id rename:`, err.message);
      }
    }
    await pool.query(`DROP INDEX IF EXISTS ${table}_inquiry_id_key`);

    for (const [name, typ] of EVENT_CATERING_COLUMN_DEFS) {
      if (!cols.has(name)) {
        try {
          await pool.query(`ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS ${name} ${typ}`);
          cols.add(name);
        } catch (err) {
          console.warn(`[order_schema] ${table}.${name}:`, err.message);
        }
      }
    }

    if (cols.has('stage_enetered_at') && !cols.has('stage_entered_at')) {
      try {
        await pool.query(
          `ALTER TABLE ${table} RENAME COLUMN stage_enetered_at TO stage_entered_at`,
        );
        cols.delete('stage_enetered_at');
        cols.add('stage_entered_at');
      } catch (_) {}
    }

    if (cols.has('loyalty_reward_catering_obatines') && !cols.has('loyalty_reward_catering_obtained')) {
      try {
        await pool.query(
          `ALTER TABLE ${table} RENAME COLUMN loyalty_reward_catering_obatines TO loyalty_reward_catering_obtained`,
        );
      } catch (_) {}
    }

    if (cols.has('address_late') && !cols.has('address_lat')) {
      try {
        await pool.query(`ALTER TABLE ${table} RENAME COLUMN address_late TO address_lat`);
      } catch (_) {}
    }

    try {
      await migrateCateringOrderStatuses(table);
    } catch (err) {
      console.warn(`[order_schema] ${table} status migrate:`, err.message);
    }

    const statusList = CATERING_STATUS_VALUES.map((s) => `'${s}'`).join(', ');
    try {
      await pool.query(`ALTER TABLE ${table} DROP CONSTRAINT IF EXISTS ${table}_status_check`);
      await pool.query(
        `ALTER TABLE ${table} ADD CONSTRAINT ${table}_status_check CHECK (status IN (${statusList}))`,
      );
    } catch (err) {
      console.warn(`[order_schema] ${table} status constraint:`, err.message);
    }
  }
}

/** Build SELECT list for restaurant_orders using only existing columns. */
export function buildRestaurantOrderSelectSql(cols) {
  const publicId = restaurantOrderIdExpr(cols);
  const parts = [
    `${sqlExpr(cols, ['id'], 'NULL::uuid')} AS id`,
    `${publicId} AS order_id`,
    `${publicId} AS order_no`,
    `${sqlExpr(cols, ['customer_id'], 'NULL::text')} AS customer_id`,
    `${sqlExpr(cols, ['user_email'], 'NULL::text')} AS user_email`,
    `${sqlExpr(cols, ['user_email'], 'NULL::text')} AS guest_contact_email`,
    `${sqlExpr(cols, ['full_name'], 'NULL::text')} AS full_name`,
    `${sqlExpr(cols, ['contact_number'], 'NULL::text')} AS contact_number`,
    `${sqlExpr(cols, ['contact_number'], 'NULL::text')} AS phone`,
    `${sqlExpr(cols, ['tray_items'], "'[]'::jsonb")} AS tray_items`,
    `${sqlExpr(cols, ['tray_items'], "'[]'::jsonb")} AS items`,
    `${sqlExpr(cols, ['total_cost'], '0')}::numeric AS total_cost`,
    `${sqlExpr(cols, ['total_cost'], '0')}::numeric AS total_amount`,
    `${sqlExpr(cols, ['delivery_address'], 'NULL::text')} AS delivery_address`,
    `${sqlExpr(cols, ['delivery_lat'], 'NULL')} AS delivery_lat`,
    `${sqlExpr(cols, ['delivery_lng'], 'NULL')} AS delivery_lng`,
    `${sqlExpr(cols, ['delivery_time'], 'NULL::timestamptz')} AS delivery_time`,
    `${sqlExpr(cols, ['delivery_notes'], 'NULL::text')} AS delivery_notes`,
    `${sqlExpr(cols, ['delivery_tracking_url'], 'NULL::text')} AS delivery_tracking_url`,
    `${sqlExpr(cols, ['order_status', 'status'], "'PENDING_CASHIER'")} AS order_status`,
    `CASE
       WHEN ${sqlExpr(cols, ['payment_confirmed_initial'], 'FALSE')} = TRUE THEN 'paid'
       WHEN ${sqlExpr(cols, ['payment_uploaded_initial'], 'FALSE')} = TRUE THEN 'pending'
       ELSE 'pending'
     END AS payment_status`,
    `${sqlExpr(cols, ['payment_reference_initial'], 'NULL::text')} AS payment_reference_initial`,
    `${sqlExpr(cols, ['payment_reference_initial'], 'NULL::text')} AS payment_references_initial`,
    `${sqlExpr(cols, ['payment_reference_balance'], 'NULL::text')} AS payment_reference_balance`,
    `${sqlExpr(cols, ['payment_reference_initial'], 'NULL::text')} AS payment_reference`,
    `${sqlExpr(cols, ['payment_proof_initial'], 'NULL::text')} AS payment_proof_initial`,
    `${sqlExpr(cols, ['payment_proof'], 'NULL::text')} AS payment_proof`,
    `${sqlExpr(cols, ['payment_proof_balance'], 'NULL::text')} AS payment_proof_balance`,
    `${sqlExpr(cols, ['payment_uploaded_initial'], 'FALSE')} AS payment_uploaded_initial`,
    `${sqlExpr(cols, ['payment_uploaded_balance'], 'FALSE')} AS payment_uploaded_balance`,
    `${sqlExpr(cols, ['payment_confirmed_initial'], 'FALSE')} AS payment_confirmed_initial`,
    `${sqlExpr(cols, ['payment_confirmed_balance'], 'FALSE')} AS payment_confirmed_balance`,
    `${sqlExpr(cols, ['amount_paid'], 'NULL')} AS amount_paid`,
    `${sqlExpr(cols, ['change_given'], 'NULL')} AS change_given`,
    `${sqlExpr(cols, ['loyalty_points_restaurant_obtained'], '0')} AS points_earned`,
    `${sqlExpr(cols, ['loyalty_points_restaurant_obtained'], '0')} AS loyalty_points_restaurant_obtained`,
    `${sqlExpr(cols, ['order_source'], "'ONLINE'")} AS order_source`,
    `${sqlExpr(cols, ['payment_method', 'payment_mode'], 'NULL::text')} AS payment_method`,
    `${sqlExpr(cols, ['payment_mode', 'payment_method'], 'NULL::text')} AS payment_mode`,
    `${sqlExpr(cols, ['cashier_amount_received_initial'], 'NULL')} AS cashier_amount_received`,
    `${sqlExpr(cols, ['cashier_amount_received_initial'], 'NULL')} AS cashier_amount_received_initial`,
    `${sqlExpr(cols, ['cashier_amount_received_balance'], 'NULL')} AS cashier_secondary_amount_received`,
    `${sqlExpr(cols, ['cashier_amount_received_balance'], 'NULL')} AS cashier_amount_received_balance`,
    `${sqlExpr(cols, ['order_status'], "'PENDING_CASHIER'")} AS fulfillment_stage`,
    `${sqlExpr(cols, ['pos_customer_label'], 'NULL::text')} AS pos_customer_label`,
    `${sqlExpr(cols, ['balance_proof_pending_review'], 'FALSE')} AS balance_proof_pending_review`,
    `${sqlExpr(cols, ['payment_proof_balance'], 'NULL::text')} AS supplemental_payment_proof`,
    `${sqlExpr(cols, ['pos_claimed'], 'FALSE')} AS pos_claimed`,
    `${sqlExpr(cols, ['note'], "''")} AS note`,
    `${sqlExpr(cols, ['pos_claimed_at'], 'NULL::timestamptz')} AS pos_claimed_at`,
    `${sqlExpr(cols, ['feedback_stars'], 'NULL::int')} AS feedback_stars`,
    `${sqlExpr(cols, ['feedback_remarks'], 'NULL::text')} AS feedback_remarks`,
    `${sqlExpr(cols, ['feedback_submitted_at'], 'NULL::timestamptz')} AS feedback_submitted_at`,
    `${sqlExpr(cols, ['last_customer_followup_at'], 'NULL::timestamptz')} AS last_customer_followup_at`,
    `${sqlExpr(cols, ['created_at'], 'now()')} AS created_at`,
    `${sqlExpr(cols, ['updated_at'], 'now()')} AS updated_at`,
  ];
  return parts.join(',\n  ');
}

/** Line items: prefer mobile/web tray_items over tray_lines and legacy [items]. */
export function parseRestaurantOrderTrayItems(orderOrRaw) {
  if (orderOrRaw == null) return [];
  if (Array.isArray(orderOrRaw)) return orderOrRaw;
  if (typeof orderOrRaw === 'string') {
    const t = orderOrRaw.trim();
    if (!t) return [];
    try {
      const parsed = JSON.parse(t);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  if (typeof orderOrRaw === 'object') {
    const raw =
      orderOrRaw.tray_items ??
      orderOrRaw.trayItems ??
      orderOrRaw.tray_lines ??
      orderOrRaw.trayLines ??
      orderOrRaw.items;
    return parseRestaurantOrderTrayItems(raw);
  }
  return [];
}

/** INSERT column list for dish JSON (canonical: tray_items only). */
export function restaurantOrderItemsInsertSql(cols) {
  const json = '$ITEM$::jsonb';
  if (cols.has('tray_items')) {
    return { columns: 'tray_items', placeholders: json };
  }
  return { columns: 'tray_items', placeholders: json };
}

/**
 * Remove embedded dish photos from tray lines before persisting orders.
 * Clients may include imageBase64 for cart UI; storing them bloats JSON and
 * breaks any accidental btree index on tray_items (8191-byte limit).
 */
export function stripTrayItemImages(items) {
  if (!Array.isArray(items)) return [];
  return items.map((raw) => {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return raw;
    const item = { ...raw };
    delete item.image_base64;
    delete item.imageBase64;
    if (item.dish && typeof item.dish === 'object' && !Array.isArray(item.dish)) {
      item.dish = { ...item.dish };
      delete item.dish.image_base64;
      delete item.dish.imageBase64;
    }
    return item;
  });
}

/** SET clauses for web checkout payment (reference → *_reference_initial, proof → payment_proof_initial). */
export function buildRestaurantOrderPaymentUpdateSets(cols) {
  const sets = [
    'updated_at = now()',
  ];
  if (cols.has('payment_reference_initial')) {
    sets.push('payment_reference_initial = COALESCE($1, payment_reference_initial)');
  }
  if (cols.has('payment_proof_initial')) {
    sets.push('payment_proof_initial = COALESCE($2, payment_proof_initial)');
  }
  if (cols.has('payment_uploaded_initial')) {
    sets.push('payment_uploaded_initial = TRUE');
  }
  if (cols.has('order_status')) {
    sets.push("order_status = 'pending_cashier'");
  }
  return sets.join(', ');
}

/**
 * @param {'web'|'mobile'|'staff'} [channel]
 */
export function normalizeRestaurantOrderRow(order, parsedItems, { channel = 'web' } = {}) {
  const o = { ...order };
  const items = parsedItems ?? parseRestaurantOrderTrayItems(o);
  o.tray_items = Array.isArray(items) ? items : [];
  o.items = o.tray_items;

  const refInitial =
    o.payment_reference_initial ??
    o.payment_reference ??
    null;
  o.payment_reference_initial = refInitial;
  o.payment_reference = refInitial;

  const proofInitial = o.payment_proof_initial ?? null;
  o.payment_proof_initial = proofInitial;
  o.payment_proof = o.payment_proof ?? proofInitial ?? null;

  if (o.order_status != null) {
    o.order_status = normalizeRestaurantOrderStatus(o.order_status);
  }
  if (o.order_status != null && o.status == null) o.status = o.order_status;
  if (o.status != null && o.order_status == null) o.order_status = o.status;

  if (o.total_amount == null && o.total_cost != null) o.total_amount = o.total_cost;
  if (o.total_cost == null && o.total_amount != null) o.total_cost = o.total_amount;

  if (o.order_no == null && o.order_id != null) o.order_no = String(o.order_id);
  if (o.order_id == null && o.order_no != null) o.order_id = String(o.order_no);

  if (o.phone == null && o.contact_number != null) o.phone = o.contact_number;
  if (o.contact_number == null && o.phone != null) o.contact_number = o.phone;
  if (o.user_email != null && o.guest_contact_email == null) {
    o.guest_contact_email = o.user_email;
  }

  if (o.points_earned == null && o.loyalty_points_restaurant_obtained != null) {
    o.points_earned = o.loyalty_points_restaurant_obtained;
  }
  if (o.loyalty_points_restaurant_obtained == null && o.points_earned != null) {
    o.loyalty_points_restaurant_obtained = o.points_earned;
  }

  if (o.id != null) o.id = String(o.id);
  if (o.order_no != null) o.order_no = String(o.order_no);

  for (const k of Object.keys(o)) {
    const v = o[k];
    if (v instanceof Date) o[k] = v.toISOString();
    else if (typeof v === 'bigint') o[k] = Number(v);
  }
  return o;
}

function tryParseJson(s) {
  try {
    return JSON.parse(s);
  } catch {
    return [];
  }
}

/** Normalize stored menu JSON (flat rows, inquiry blocks with dishNames, legacy keys). */
export function parseEventOrderMenuItems(raw) {
  let arr = raw;
  if (raw == null) return [];
  if (typeof raw === 'string') {
    const trimmed = raw.trim();
    if (!trimmed) return [];
    try {
      arr = JSON.parse(trimmed);
    } catch {
      return [];
    }
  }
  if (!Array.isArray(arr)) return [];

  const out = [];
  for (const item of arr) {
    if (item == null) continue;
    if (typeof item !== 'object' || Array.isArray(item)) continue;

    const setMenuName =
      item.setMenuName != null
        ? String(item.setMenuName).trim()
        : item.set_menu_name != null
          ? String(item.set_menu_name).trim()
          : '';

    const dishNameRaw = item.dishName ?? item.dish_name;
    if (dishNameRaw != null && String(dishNameRaw).trim()) {
      out.push({
        dishName: String(dishNameRaw).trim(),
        paxOption: String(item.paxOption ?? item.pax_option ?? '').trim(),
        price: item.price != null ? String(item.price) : '0',
        ...(setMenuName ? { setMenuName } : {}),
      });
      continue;
    }

    const names = item.dishNames ?? item.dish_names;
    if (Array.isArray(names)) {
      for (const n of names) {
        const name = String(n ?? '').trim();
        if (!name) continue;
        out.push({
          dishName: name,
          paxOption: '',
          price: '0',
          ...(setMenuName ? { setMenuName } : {}),
        });
      }
    }
  }
  return out;
}

/** Staff/manager event order row: parsed menu, allergens string, optional dish catalog enrichment. */
export async function normalizeStaffEventOrderRow(row, { enrichMenu = false } = {}) {
  if (!row || typeof row !== 'object') return row;

  const o = { ...row };
  o.menu = parseEventOrderMenuItems(o.menu);
  o.allergens = String(o.allergens ?? '').trim();

  if (typeof o.themeDesign === 'string' && o.themeDesign.trim()) {
    try {
      o.themeDesign = JSON.parse(o.themeDesign);
    } catch {
      o.themeDesign = {};
    }
  }

  if (enrichMenu && o.menu.length > 0) {
    const names = [
      ...new Set(
        o.menu.map((m) => String(m.dishName ?? '').trim()).filter(Boolean),
      ),
    ];
    if (names.length > 0) {
      try {
        const mdCols = await getTableColumnNames('menu_dishes');
        if (mdCols.has('name')) {
          const allergenCol = mdCols.has('allergens') ? 'allergens' : "''";
          const ingredientCol = mdCols.has('ingredients')
            ? 'ingredients'
            : "'[]'::jsonb";
          const priceCol = mdCols.has('price') ? 'price::text' : "''";
          const r = await pool.query(
            `SELECT name, ${allergenCol} AS allergens, ${ingredientCol} AS ingredients, ${priceCol} AS price
             FROM menu_dishes
             WHERE lower(trim(name::text)) = ANY($1::text[])`,
            [names.map((n) => n.toLowerCase())],
          );
          const byName = new Map(
            r.rows.map((d) => [
              String(d.name ?? '')
                .trim()
                .toLowerCase(),
              d,
            ]),
          );
          o.menu = o.menu.map((item) => {
            const key = String(item.dishName ?? '')
              .trim()
              .toLowerCase();
            const dish = byName.get(key);
            if (!dish) return item;
            return {
              ...item,
              dishAllergens: String(dish.allergens ?? '').trim(),
              ingredients: dish.ingredients,
              catalogPrice: dish.price != null ? String(dish.price) : item.price,
            };
          });
        }
      } catch (err) {
        console.warn('normalizeStaffEventOrderRow menu enrich:', err.message);
      }
    }
  }

  return o;
}

function cateringSelectField(cols, alias, candidates, defaultSql) {
  const col = pickCol(cols, candidates);
  if (col) return `${col} AS "${alias}"`;
  return `${defaultSql} AS "${alias}"`;
}

/** UNION query for customer catering + event orders (email match). */
export function buildCustomerCateringOrdersSql(eventCols, cateringCols) {
  const eventSeating = eventCols.has('seating_plan')
    ? 'COALESCE(seating_plan, \'{}\'::jsonb)'
    : '\'{}\'::jsonb';
  const eventTheme = eventCols.has('theme_design')
    ? 'theme_design'
    : '\'{}\'::jsonb';
  const eventPart = `
    SELECT
      id::text AS id,
      ${cateringIdSelectAlias(eventCols)},
      ${cateringSelectField(eventCols, 'eventTitle', ['event_title'], 'NULL::text')},
      ${cateringSelectField(eventCols, 'eventType', ['event_type'], 'NULL::text')},
      status,
      ${cateringSelectField(eventCols, 'guestCount', ['guest_count'], '0')},
      ${cateringSelectField(eventCols, 'scheduleSlots', ['schedule_slots'], "'[]'::jsonb")},
      ${cateringSelectField(eventCols, 'menu', ['menu'], "'[]'::jsonb")},
      ${cateringSelectField(eventCols, 'totalCost', ['total_cost'], '0')},
      ${cateringSelectField(eventCols, 'estimatedTotal', ['estimated_total', 'estimated_cost'], '0')},
      ${cateringSelectField(eventCols, 'allergens', ['allergens'], "''")},
      ${cateringSelectField(eventCols, 'note', ['note'], "''")},
      ${cateringSelectField(eventCols, 'feedback_stars', ['feedback_stars'], 'NULL::int')},
      ${cateringSelectField(eventCols, 'feedback_remarks', ['feedback_remarks'], 'NULL::text')},
      ${cateringSelectField(eventCols, 'feedback_submitted_at', ['feedback_submitted_at'], 'NULL::timestamptz')},
      ${eventTheme} AS "themeDesign",
      ${eventSeating} AS "seatingPlan",
      ${cateringSelectField(eventCols, 'createdAt', ['created_at'], 'now()')},
      'event' AS order_type
    FROM event_orders
    WHERE lower(email_address) = lower($1)`;

  const cateringTheme = cateringCols.has('theme_design')
    ? 'theme_design'
    : '\'{}\'::jsonb';
  const cateringPart = `
    SELECT
      id::text AS id,
      ${cateringIdSelectAlias(cateringCols)},
      NULL::text AS "eventTitle",
      'catering'::text AS "eventType",
      status,
      ${cateringSelectField(cateringCols, 'guestCount', ['guest_count'], '0')},
      ${cateringSelectField(cateringCols, 'scheduleSlots', ['schedule_slots'], "'[]'::jsonb")},
      ${cateringSelectField(cateringCols, 'menu', ['menu'], "'[]'::jsonb")},
      ${cateringSelectField(cateringCols, 'totalCost', ['total_cost'], '0')},
      ${cateringSelectField(cateringCols, 'estimatedTotal', ['estimated_total', 'estimated_cost'], '0')},
      ${cateringSelectField(cateringCols, 'allergens', ['allergens'], "''")},
      ${cateringSelectField(cateringCols, 'note', ['note'], "''")},
      ${cateringSelectField(cateringCols, 'feedback_stars', ['feedback_stars'], 'NULL::int')},
      ${cateringSelectField(cateringCols, 'feedback_remarks', ['feedback_remarks'], 'NULL::text')},
      ${cateringSelectField(cateringCols, 'feedback_submitted_at', ['feedback_submitted_at'], 'NULL::timestamptz')},
      ${cateringTheme} AS "themeDesign",
      '{}'::jsonb AS "seatingPlan",
      ${cateringSelectField(cateringCols, 'createdAt', ['created_at'], 'now()')},
      'catering' AS order_type
    FROM catering_orders
    WHERE lower(email_address) = lower($1)`;

  return `${eventPart}\nUNION ALL\n${cateringPart}\nORDER BY "createdAt" DESC`;
}

export function normalizeCustomerCateringOrderRow(row) {
  const o = { ...row };
  o.status = normalizeCateringOrderStatus(o.status);
  if (o.createdAt instanceof Date) o.createdAt = o.createdAt.toISOString();
  if (o.feedback_submitted_at instanceof Date) {
    o.feedback_submitted_at = o.feedback_submitted_at.toISOString();
  }
  o.feedback_submitted = o.feedback_stars != null;

  if (typeof o.themeDesign === 'string' && o.themeDesign.trim()) {
    try {
      o.themeDesign = JSON.parse(o.themeDesign);
    } catch {
      o.themeDesign = {};
    }
  }
  if (o.themeDesign != null && typeof o.themeDesign !== 'object') {
    o.themeDesign = {};
  }

  const theme = o.themeDesign && typeof o.themeDesign === 'object' ? o.themeDesign : {};
  if (!theme.costBreakdown && theme.cost_breakdown != null) {
    theme.costBreakdown = theme.cost_breakdown;
  }
  if (!theme.customerNote && (theme.note || o.note)) {
    theme.customerNote = String(theme.note || o.note || '').trim();
  }
  o.themeDesign = theme;
  const breakdown =
    theme.costBreakdown && typeof theme.costBreakdown === 'object' && !Array.isArray(theme.costBreakdown)
      ? theme.costBreakdown
      : {};
  if (o.laborCost == null && breakdown.laborCost != null) {
    o.laborCost = breakdown.laborCost;
  }
  if (o.travelCost == null && breakdown.travelCost != null) {
    o.travelCost = breakdown.travelCost;
  }
  if (
    (o.totalCost == null || Number(o.totalCost) === 0) &&
    o.estimatedTotal != null &&
    Number(o.estimatedTotal) > 0
  ) {
    o.totalCost = o.estimatedTotal;
  }

  return o;
}

/** theme_design column for staff list queries (optional column + compact mode). */
export function staffThemeDesignColumnSql(eventCols, compact) {
  if (!eventCols.has('theme_design')) {
    return `'{}'::jsonb AS "themeDesign"`;
  }
  if (compact) {
    return `jsonb_set(
      COALESCE(theme_design::jsonb, '{}'::jsonb),
      '{picksBase64}',
      '[]'::jsonb,
      true
    ) AS "themeDesign"`;
  }
  return `theme_design AS "themeDesign"`;
}

function staffCateringOrderSelectList(cateringCols) {
  return `
    SELECT
      id,
      ${cateringIdSelectAlias(cateringCols)},
      ${cateringSelectField(cateringCols, 'customerId', ['customer_id'], 'NULL::text')},
      ${cateringSelectField(cateringCols, 'source', ['source'], "''")},
      ${cateringSelectField(cateringCols, 'status', ['status'], "'online_inquiries'")},
      NULL::text AS "eventTitle",
      NULL::text AS "eventType",
      NULL::text AS "formalityLevel",
      ${cateringSelectField(cateringCols, 'customerName', ['customer_name'], "''")},
      ${cateringSelectField(cateringCols, 'contactPerson', ['contact_person'], "''")},
      ${cateringSelectField(cateringCols, 'contactNumber', ['contact_number'], "''")},
      ${cateringSelectField(cateringCols, 'emailAddress', ['email_address'], "''")},
      ${cateringSelectField(cateringCols, 'scheduleSlots', ['schedule_slots'], "'[]'::jsonb")},
      ${cateringSelectField(cateringCols, 'address', ['address'], "''")},
      ${cateringSelectField(cateringCols, 'orderType', ['order_type'], "'catering'")},
      ${cateringSelectField(cateringCols, 'guestCount', ['guest_count'], '0')},
      ${cateringSelectField(cateringCols, 'allergens', ['allergens'], "''")},
      ${cateringSelectField(cateringCols, 'menu', ['menu'], "'[]'::jsonb")},
      '{}'::jsonb AS "themeDesign",
      '{}'::jsonb AS "seatingPlan",
      ${cateringSelectField(cateringCols, 'postAnalysis', ['post_analysis'], "'{}'::jsonb")},
      ${cateringSelectField(cateringCols, 'totalCost', ['total_cost'], '0')},
      ${cateringSelectField(cateringCols, 'downPaymentAmount', ['down_payment_amount'], '0')},
      ${cateringSelectField(cateringCols, 'downPaymentStatus', ['down_payment_status'], "'pending'")},
      ${cateringSelectField(cateringCols, 'fullPaymentAmount', ['full_payment_amount'], '0')},
      ${cateringSelectField(cateringCols, 'fullPaymentStatus', ['full_payment_status'], "'pending'")},
      ${cateringSelectField(cateringCols, 'finalStatus', ['final_status'], "'successful'")},
      ${cateringSelectField(cateringCols, 'created_at', ['created_at'], 'now()')},
      COALESCE(${sqlExpr(cateringCols, ['updated_at'], 'created_at')}, ${sqlExpr(cateringCols, ['created_at'], 'now()')}) AS "updatedAt"
    FROM catering_orders`;
}

function staffEventOrderSelectList(eventCols, themeColSql) {
  const seating = eventCols.has('seating_plan')
    ? 'COALESCE(seating_plan, \'{}\'::jsonb)'
    : '\'{}\'::jsonb';
  return `
    SELECT
      id,
      ${cateringIdSelectAlias(eventCols)},
      ${cateringSelectField(eventCols, 'customerId', ['customer_id'], 'NULL::text')},
      ${cateringSelectField(eventCols, 'source', ['source'], "''")},
      ${cateringSelectField(eventCols, 'status', ['status'], "'online_inquiries'")},
      ${cateringSelectField(eventCols, 'eventTitle', ['event_title'], 'NULL::text')},
      ${cateringSelectField(eventCols, 'eventType', ['event_type'], 'NULL::text')},
      ${cateringSelectField(eventCols, 'formalityLevel', ['formality_level'], 'NULL::text')},
      ${cateringSelectField(eventCols, 'customerName', ['customer_name'], "''")},
      ${cateringSelectField(eventCols, 'contactPerson', ['contact_person'], "''")},
      ${cateringSelectField(eventCols, 'contactNumber', ['contact_number'], "''")},
      ${cateringSelectField(eventCols, 'emailAddress', ['email_address'], "''")},
      ${cateringSelectField(eventCols, 'scheduleSlots', ['schedule_slots'], "'[]'::jsonb")},
      ${cateringSelectField(eventCols, 'address', ['address'], "''")},
      ${cateringSelectField(eventCols, 'orderType', ['order_type'], "'catering_event'")},
      ${cateringSelectField(eventCols, 'guestCount', ['guest_count'], '0')},
      ${cateringSelectField(eventCols, 'allergens', ['allergens'], "''")},
      ${cateringSelectField(eventCols, 'menu', ['menu'], "'[]'::jsonb")},
      ${themeColSql},
      ${seating} AS "seatingPlan",
      ${cateringSelectField(eventCols, 'postAnalysis', ['post_analysis'], "'{}'::jsonb")},
      ${cateringSelectField(eventCols, 'totalCost', ['total_cost'], '0')},
      ${cateringSelectField(eventCols, 'downPaymentAmount', ['down_payment_amount'], '0')},
      ${cateringSelectField(eventCols, 'downPaymentStatus', ['down_payment_status'], "'pending'")},
      ${cateringSelectField(eventCols, 'fullPaymentAmount', ['full_payment_amount'], '0')},
      ${cateringSelectField(eventCols, 'fullPaymentStatus', ['full_payment_status'], "'pending'")},
      ${cateringSelectField(eventCols, 'finalStatus', ['final_status'], "'successful'")},
      ${cateringSelectField(eventCols, 'created_at', ['created_at'], 'now()')},
      COALESCE(${sqlExpr(eventCols, ['updated_at'], 'created_at')}, ${sqlExpr(eventCols, ['created_at'], 'now()')}) AS "updatedAt"
    FROM event_orders`;
}

const STAFF_EVENTS_STATUS_WHERE = `
  WHERE
    status = $1
    OR ($1 = 'for_down_payment' AND status = 'for_downpayment')
    OR ($1 = 'on_going' AND status IN ('ongoing', 'for_processing'))
    OR ($1 = 'for_full_payment' AND status = 'for_post_analysis')
    OR ($1 = 'for_post_analysis' AND status = 'for_full_payment')
    OR ($1 = 'new_event' AND source = 'new_event' AND status = 'for_processing')`;

/** Manager/supervisor list: catering_orders UNION event_orders by status. */
export function buildStaffEventsOrdersListSql(
  cateringCols,
  eventCols,
  { compact = false } = {},
) {
  const themeColSql = staffThemeDesignColumnSql(eventCols, compact);
  const cateringPart =
    staffCateringOrderSelectList(cateringCols) + STAFF_EVENTS_STATUS_WHERE;
  const eventPart =
    staffEventOrderSelectList(eventCols, themeColSql) + STAFF_EVENTS_STATUS_WHERE;
  return `${cateringPart}\nUNION ALL\n${eventPart}\nORDER BY created_at DESC\nLIMIT 500`;
}

function staffCateringOrderSelectById(cateringCols) {
  return `${staffCateringOrderSelectList(cateringCols).trim()}\nWHERE id = $1`;
}

function staffEventOrderSelectById(eventCols) {
  const themeColSql = staffThemeDesignColumnSql(eventCols, false);
  const seating = eventCols.has('seating_plan')
    ? 'COALESCE(seating_plan, \'{}\'::jsonb)'
    : '\'{}\'::jsonb';
  return `
    SELECT
      id,
      ${cateringIdSelectAlias(eventCols)},
      ${cateringSelectField(eventCols, 'customerId', ['customer_id'], 'NULL::text')},
      ${cateringSelectField(eventCols, 'source', ['source'], "''")},
      ${cateringSelectField(eventCols, 'status', ['status'], "'online_inquiries'")},
      ${cateringSelectField(eventCols, 'eventTitle', ['event_title'], 'NULL::text')},
      ${cateringSelectField(eventCols, 'eventType', ['event_type'], 'NULL::text')},
      ${cateringSelectField(eventCols, 'formalityLevel', ['formality_level'], 'NULL::text')},
      ${cateringSelectField(eventCols, 'customerName', ['customer_name'], "''")},
      ${cateringSelectField(eventCols, 'contactPerson', ['contact_person'], "''")},
      ${cateringSelectField(eventCols, 'contactNumber', ['contact_number'], "''")},
      ${cateringSelectField(eventCols, 'emailAddress', ['email_address'], "''")},
      ${cateringSelectField(eventCols, 'scheduleSlots', ['schedule_slots'], "'[]'::jsonb")},
      ${cateringSelectField(eventCols, 'address', ['address'], "''")},
      ${cateringSelectField(eventCols, 'orderType', ['order_type'], "'catering_event'")},
      ${cateringSelectField(eventCols, 'guestCount', ['guest_count'], '0')},
      ${cateringSelectField(eventCols, 'allergens', ['allergens'], "''")},
      ${cateringSelectField(eventCols, 'menu', ['menu'], "'[]'::jsonb")},
      ${themeColSql},
      ${seating} AS "seatingPlan",
      ${cateringSelectField(eventCols, 'postAnalysis', ['post_analysis'], "'{}'::jsonb")},
      ${cateringSelectField(eventCols, 'totalCost', ['total_cost'], '0')},
      ${cateringSelectField(eventCols, 'downPaymentAmount', ['down_payment_amount'], '0')},
      ${cateringSelectField(eventCols, 'downPaymentStatus', ['down_payment_status'], "'pending'")},
      ${cateringSelectField(eventCols, 'fullPaymentAmount', ['full_payment_amount'], '0')},
      ${cateringSelectField(eventCols, 'fullPaymentStatus', ['full_payment_status'], "'pending'")},
      ${cateringSelectField(eventCols, 'finalStatus', ['final_status'], "'successful'")},
      ${cateringSelectField(eventCols, 'created_at', ['created_at'], 'now()')},
      COALESCE(${sqlExpr(eventCols, ['updated_at'], 'created_at')}, ${sqlExpr(eventCols, ['created_at'], 'now()')}) AS "updatedAt"
    FROM event_orders
    WHERE id = $1`;
}

/** Single row from catering_orders or event_orders by UUID. */
export function buildStaffEventOrderByIdQueries(cateringCols, eventCols) {
  return {
    cateringSql: staffCateringOrderSelectById(cateringCols),
    eventSql: staffEventOrderSelectById(eventCols),
  };
}
