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
    ['tray_items', 'JSONB NOT NULL DEFAULT \'[]\'::jsonb'],
    ['total_cost', 'DECIMAL(10,2)'],
    ['order_id', 'TEXT'],
    ['user_email', 'TEXT'],
    ['payment_mode', 'TEXT'],
    ['contact_number', 'TEXT'],
    ['payment_proof_balance', 'TEXT'],
    ['payment_uploaded_initial', 'BOOLEAN NOT NULL DEFAULT FALSE'],
    ['payment_uploaded_balance', 'BOOLEAN NOT NULL DEFAULT FALSE'],
    ['payment_confirmed_initial', 'BOOLEAN NOT NULL DEFAULT FALSE'],
    ['payment_confirmed_balance', 'BOOLEAN NOT NULL DEFAULT FALSE'],
    ['loyalty_points_restaurant_obtained', 'INTEGER DEFAULT 0'],
    ['loyalty_points_catering_obtained', 'INTEGER DEFAULT 0'],
    ['cashier_amount_received_initial', 'DECIMAL(10,2)'],
    ['cashier_amount_received_balance', 'DECIMAL(10,2)'],
    ['feedback_stars', 'INTEGER'],
    ['feedback_remarks', 'TEXT'],
    ['amount_paid', 'DECIMAL(10,2)'],
    ['change_given', 'DECIMAL(10,2)'],
    ['delivery_address', 'TEXT'],
    ['delivery_lat', 'DECIMAL(10,8)'],
    ['delivery_lng', 'DECIMAL(10,8)'],
    ['delivery_notes', 'TEXT'],
    ['delivery_tracking_url', 'TEXT'],
    ['delivery_time', 'TIMESTAMPTZ'],
    ['order_source', "TEXT NOT NULL DEFAULT 'ONLINE'"],
    ['guest_contact_email', 'TEXT'],
    ['payment_proof_initial', 'TEXT'],
    ['payment_reference_initial', 'TEXT'],
    ['payment_reference_balance', 'TEXT'],
    ['order_status', "TEXT NOT NULL DEFAULT 'pending_cashier'"],
    ['payment_status', "TEXT NOT NULL DEFAULT 'pending'"],
    ['created_at', 'TIMESTAMPTZ NOT NULL DEFAULT now()'],
    ['updated_at', 'TIMESTAMPTZ NOT NULL DEFAULT now()'],
    ['customer_id', 'TEXT'],
    ['items', "JSONB NOT NULL DEFAULT '[]'::jsonb"],
    ['total_amount', 'DECIMAL(10,2) NOT NULL DEFAULT 0.00'],
    ['order_no', 'TEXT'],
    ['phone', 'TEXT'],
    ['full_name', 'TEXT'],
    ['points_earned', 'INTEGER DEFAULT 0'],
    ['payment_method', 'TEXT'],
    ['payment_proof', 'TEXT'],
    ['cashier_amount_received', 'DECIMAL(10,2)'],
    ['cashier_secondary_amount_received', 'DECIMAL(10,2)'],
    ['id', 'uuid DEFAULT gen_random_uuid()'],
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
    ['tray_items', 'items', "COALESCE(tray_items, '[]'::jsonb)"],
    ['items', 'tray_items', "COALESCE(items, '[]'::jsonb)"],
    ['total_cost', 'total_amount', 'total_amount'],
    ['total_amount', 'total_cost', 'total_cost'],
    ['order_id', 'order_no', 'order_no::text'],
    ['order_no', 'order_id', 'order_id::text'],
    ['contact_number', 'phone', 'phone'],
    ['phone', 'contact_number', 'contact_number'],
    ['user_email', 'guest_contact_email', 'guest_contact_email'],
    ['guest_contact_email', 'user_email', 'user_email'],
    ['payment_mode', 'payment_method', 'payment_method'],
    ['payment_method', 'payment_mode', 'payment_mode'],
    [
      'loyalty_points_restaurant_obtained',
      'points_earned',
      'COALESCE(points_earned, 0)',
    ],
    [
      'points_earned',
      'loyalty_points_restaurant_obtained',
      'loyalty_points_restaurant_obtained',
    ],
    [
      'cashier_amount_received_initial',
      'cashier_amount_received',
      'cashier_amount_received',
    ],
    [
      'cashier_amount_received',
      'cashier_amount_received_initial',
      'cashier_amount_received_initial',
    ],
    [
      'cashier_amount_received_balance',
      'cashier_secondary_amount_received',
      'cashier_secondary_amount_received',
    ],
    [
      'cashier_secondary_amount_received',
      'cashier_amount_received_balance',
      'cashier_amount_received_balance',
    ],
    ['payment_proof_initial', 'payment_proof', 'payment_proof'],
    ['payment_proof', 'payment_proof_initial', 'payment_proof_initial'],
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
      await pool.query(
        `UPDATE restaurant_orders SET order_no = order_id
         WHERE order_no IS NULL AND order_id IS NOT NULL`,
      );
    } catch (_) {}
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
  ['address_lat', 'DOUBLE PRECISION'],
  ['address_lng', 'DOUBLE PRECISION'],
  ['seating_plan', "JSONB NOT NULL DEFAULT '{}'::jsonb"],
  ['event_id', 'TEXT'],
  ['pax_buffer', 'INT DEFAULT 0'],
  ['estimated_cost', 'DECIMAL(10,2) DEFAULT 0.00'],
  ['allergens', "TEXT NOT NULL DEFAULT ''"],
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
    `${sqlExpr(cols, ['guest_contact_email'], 'NULL::text')} AS guest_contact_email`,
    `${sqlExpr(cols, ['user_email', 'guest_contact_email'], 'NULL::text')} AS user_email`,
    `${sqlExpr(cols, ['full_name'], 'NULL::text')} AS full_name`,
    `${sqlExpr(cols, ['phone', 'contact_number'], 'NULL::text')} AS phone`,
    `${sqlExpr(cols, ['contact_number', 'phone'], 'NULL::text')} AS contact_number`,
    `COALESCE(${sqlExpr(cols, ['tray_items'], 'NULL::jsonb')}, ${sqlExpr(cols, ['items'], "'[]'::jsonb")}) AS items`,
    `COALESCE(${sqlExpr(cols, ['items'], 'NULL::jsonb')}, ${sqlExpr(cols, ['tray_items'], "'[]'::jsonb")}) AS tray_items`,
    `COALESCE(${sqlExpr(cols, ['total_amount', 'total_cost'], '0')}, ${sqlExpr(cols, ['total_cost', 'total_amount'], '0')})::numeric AS total_amount`,
    `COALESCE(${sqlExpr(cols, ['total_cost', 'total_amount'], '0')}, ${sqlExpr(cols, ['total_amount', 'total_cost'], '0')})::numeric AS total_cost`,
    `${sqlExpr(cols, ['delivery_address'], 'NULL::text')} AS delivery_address`,
    `${sqlExpr(cols, ['delivery_lat'], 'NULL')} AS delivery_lat`,
    `${sqlExpr(cols, ['delivery_lng'], 'NULL')} AS delivery_lng`,
    `${sqlExpr(cols, ['delivery_time'], 'NULL::timestamptz')} AS delivery_time`,
    `${sqlExpr(cols, ['delivery_notes'], 'NULL::text')} AS delivery_notes`,
    `${sqlExpr(cols, ['delivery_tracking_url'], 'NULL::text')} AS delivery_tracking_url`,
    `${sqlExpr(cols, ['order_status', 'status'], "'pending_cashier'")} AS order_status`,
    `${sqlExpr(cols, ['payment_status'], "'pending'")} AS payment_status`,
    `${sqlExpr(cols, ['payment_reference', 'payment_reference_initial'], 'NULL::text')} AS payment_reference`,
    `${sqlExpr(cols, ['payment_reference_initial'], 'NULL::text')} AS payment_reference_initial`,
    `${sqlExpr(cols, ['payment_reference_balance'], 'NULL::text')} AS payment_reference_balance`,
    `${sqlExpr(cols, ['payment_proof', 'payment_proof_initial'], 'NULL::text')} AS payment_proof`,
    `${sqlExpr(cols, ['payment_proof_initial'], 'NULL::text')} AS payment_proof_initial`,
    `${sqlExpr(cols, ['payment_proof_balance'], 'NULL::text')} AS payment_proof_balance`,
    `${sqlExpr(cols, ['payment_uploaded_initial'], 'FALSE')} AS payment_uploaded_initial`,
    `${sqlExpr(cols, ['payment_uploaded_balance'], 'FALSE')} AS payment_uploaded_balance`,
    `${sqlExpr(cols, ['payment_confirmed_initial'], 'FALSE')} AS payment_confirmed_initial`,
    `${sqlExpr(cols, ['payment_confirmed_balance'], 'FALSE')} AS payment_confirmed_balance`,
    `${sqlExpr(cols, ['amount_paid'], 'NULL')} AS amount_paid`,
    `${sqlExpr(cols, ['change_given'], 'NULL')} AS change_given`,
    `${sqlExpr(cols, ['points_earned', 'loyalty_points_restaurant_obtained'], '0')} AS points_earned`,
    `${sqlExpr(cols, ['loyalty_points_restaurant_obtained', 'points_earned'], '0')} AS loyalty_points_restaurant_obtained`,
    `${sqlExpr(cols, ['loyalty_points_catering_obtained'], '0')} AS loyalty_points_catering_obtained`,
    `${sqlExpr(cols, ['order_source'], "'ONLINE'")} AS order_source`,
    `${sqlExpr(cols, ['payment_method', 'payment_mode'], 'NULL::text')} AS payment_method`,
    `${sqlExpr(cols, ['payment_mode', 'payment_method'], 'NULL::text')} AS payment_mode`,
    `${sqlExpr(cols, ['cashier_amount_received', 'cashier_amount_received_initial'], 'NULL')} AS cashier_amount_received`,
    `${sqlExpr(cols, ['cashier_amount_received_initial', 'cashier_amount_received'], 'NULL')} AS cashier_amount_received_initial`,
    `${sqlExpr(cols, ['cashier_secondary_amount_received', 'cashier_amount_received_balance'], 'NULL')} AS cashier_secondary_amount_received`,
    `${sqlExpr(cols, ['cashier_amount_received_balance', 'cashier_secondary_amount_received'], 'NULL')} AS cashier_amount_received_balance`,
    `${sqlExpr(cols, ['fulfillment_stage'], 'NULL::text')} AS fulfillment_stage`,
    `${sqlExpr(cols, ['pos_customer_label'], 'NULL::text')} AS pos_customer_label`,
    `${sqlExpr(cols, ['balance_proof_pending_review'], 'FALSE')} AS balance_proof_pending_review`,
    `${sqlExpr(cols, ['supplemental_payment_proof'], 'NULL::text')} AS supplemental_payment_proof`,
    `${sqlExpr(cols, ['pos_claimed_at'], 'NULL::timestamptz')} AS pos_claimed_at`,
    `${sqlExpr(cols, ['feedback_stars'], 'NULL::int')} AS feedback_stars`,
    `${sqlExpr(cols, ['feedback_remarks'], 'NULL::text')} AS feedback_remarks`,
    `${sqlExpr(cols, ['feedback_submitted_at'], 'NULL::timestamptz')} AS feedback_submitted_at`,
    `${sqlExpr(cols, ['created_at'], 'now()')} AS created_at`,
    `${sqlExpr(cols, ['updated_at'], 'now()')} AS updated_at`,
  ];
  return parts.join(',\n  ');
}

export function normalizeRestaurantOrderRow(order, parsedItems) {
  const o = { ...order };
  const items =
    parsedItems ??
    (typeof o.items === 'string' ? tryParseJson(o.items) : o.items) ??
    (typeof o.tray_items === 'string' ? tryParseJson(o.tray_items) : o.tray_items) ??
    [];
  o.items = Array.isArray(items) ? items : [];
  o.tray_items = o.items;

  if (o.order_status != null && o.status == null) o.status = o.order_status;
  if (o.status != null && o.order_status == null) o.order_status = o.status;

  if (o.total_amount == null && o.total_cost != null) o.total_amount = o.total_cost;
  if (o.total_cost == null && o.total_amount != null) o.total_cost = o.total_amount;

  if (o.order_no == null && o.order_id != null) o.order_no = String(o.order_id);
  if (o.order_id == null && o.order_no != null) o.order_id = String(o.order_no);

  if (o.phone == null && o.contact_number != null) o.phone = o.contact_number;
  if (o.contact_number == null && o.phone != null) o.contact_number = o.phone;

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
      ${cateringSelectField(eventCols, 'guestCount', ['guest_count'], '0')} AS "guestCount",
      ${cateringSelectField(eventCols, 'scheduleSlots', ['schedule_slots'], "'[]'::jsonb")} AS "scheduleSlots",
      ${cateringSelectField(eventCols, 'menu', ['menu'], "'[]'::jsonb")} AS menu,
      ${cateringSelectField(eventCols, 'totalCost', ['total_cost'], '0')} AS "totalCost",
      ${eventTheme} AS "themeDesign",
      ${eventSeating} AS "seatingPlan",
      ${cateringSelectField(eventCols, 'createdAt', ['created_at'], 'now()')} AS "createdAt",
      'event' AS order_type
    FROM event_orders
    WHERE lower(email_address) = lower($1)`;

  const cateringPart = `
    SELECT
      id::text AS id,
      ${cateringIdSelectAlias(cateringCols)},
      NULL::text AS "eventTitle",
      'catering'::text AS "eventType",
      status,
      ${cateringSelectField(cateringCols, 'guestCount', ['guest_count'], '0')} AS "guestCount",
      ${cateringSelectField(cateringCols, 'scheduleSlots', ['schedule_slots'], "'[]'::jsonb")} AS "scheduleSlots",
      ${cateringSelectField(cateringCols, 'menu', ['menu'], "'[]'::jsonb")} AS menu,
      ${cateringSelectField(cateringCols, 'totalCost', ['total_cost'], '0')} AS "totalCost",
      '{}'::jsonb AS "themeDesign",
      '{}'::jsonb AS "seatingPlan",
      ${cateringSelectField(cateringCols, 'createdAt', ['created_at'], 'now()')} AS "createdAt",
      'catering' AS order_type
    FROM catering_orders
    WHERE lower(email_address) = lower($1)`;

  return `${eventPart}\nUNION ALL\n${cateringPart}\nORDER BY "createdAt" DESC`;
}

export function normalizeCustomerCateringOrderRow(row) {
  const o = { ...row };
  o.status = normalizeCateringOrderStatus(o.status);
  if (o.createdAt instanceof Date) o.createdAt = o.createdAt.toISOString();
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
      ${cateringSelectField(eventCols, 'finalStatus', ['final_status'], "'successful'")},
      ${cateringSelectField(eventCols, 'created_at', ['created_at'], 'now()')},
      COALESCE(${sqlExpr(eventCols, ['updated_at'], 'created_at')}, ${sqlExpr(eventCols, ['created_at'], 'now()')}) AS "updatedAt"
    FROM event_orders`;
}

const STAFF_EVENTS_STATUS_WHERE = `
  WHERE
    status = $1
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
