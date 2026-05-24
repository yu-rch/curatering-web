import { Pool } from "pg";

function buildPgPoolConfig() {
  const cs = process.env.DATABASE_URL?.trim();
  if (!cs) {
    const statementTimeout =
      process.env.PG_STATEMENT_TIMEOUT?.trim() || "120s";
    return {
      host: process.env.PGHOST || process.env.DB_HOST,
      port: process.env.PGPORT
        ? Number(process.env.PGPORT)
        : process.env.DB_PORT
          ? Number(process.env.DB_PORT)
          : undefined,
      user: process.env.PGUSER || process.env.DB_USER,
      password: process.env.PGPASSWORD || process.env.DB_PASSWORD,
      database: process.env.PGDATABASE || process.env.DB_NAME,
      max: Number(process.env.PG_POOL_MAX || 25),
      idleTimeoutMillis: Number(process.env.PG_IDLE_TIMEOUT_MS || 30000),
      connectionTimeoutMillis: Number(process.env.PG_CONNECTION_TIMEOUT_MS || 20000),
      options: `-c statement_timeout=${statementTimeout}`,
    };
  }

  const lower = cs.toLowerCase();
  const isSupabase =
    lower.includes("supabase.co") || lower.includes("pooler.supabase.com");
  const usesPgBouncer =
    lower.includes("pgbouncer=true") || lower.includes(":6543/");

  // Default 120s — Supabase default statement_timeout is often ~8s; heavy list queries need more.
  const statementTimeout =
    process.env.PG_STATEMENT_TIMEOUT?.trim() || "120s";

  // Supabase pooler: keep a modest pool size (free tier has limited DB connections).
  const defaultPoolMax = isSupabase ? 8 : 25;

  return {
    connectionString: cs,
    max: Number(process.env.PG_POOL_MAX || defaultPoolMax),
    idleTimeoutMillis: Number(process.env.PG_IDLE_TIMEOUT_MS || 10000),
    connectionTimeoutMillis: Number(process.env.PG_CONNECTION_TIMEOUT_MS || 20000),
    keepAlive: true,
    options: `-c statement_timeout=${statementTimeout}`,
    // Supabase / managed Postgres: TLS required; pooler may drop idle sockets — keepAlive + timeouts help.
    ...(isSupabase || process.env.PG_SSL === "1"
      ? { ssl: { rejectUnauthorized: false } }
      : {}),
    // Transaction pooler (port 6543) does not support prepared statements in node-pg.
    ...(usesPgBouncer ? { allowExitOnIdle: true } : {}),
  };
}

const config = buildPgPoolConfig();
const csHint = process.env.DATABASE_URL?.toLowerCase() || "";
const isSupabaseHost =
  csHint.includes("supabase.co") || csHint.includes("pooler.supabase.com");
console.log("PostgreSQL pool configuration:", {
  max: config.max,
  supabase: isSupabaseHost,
  ssl: Boolean(config.ssl),
  connectionString: config.connectionString ? "***" : "individual params",
});
if (isSupabaseHost && !config.connectionString) {
  console.warn(
    "[db] Supabase detected in docs but DATABASE_URL is empty — set it on Railway.",
  );
}
const pool = new Pool(config);

pool.on("error", (err) => {
  console.error("PostgreSQL pool idle client error:", err?.message || err);
});

function isTransientPgNetworkError(err) {
  const c = err?.code;
  const msg = String(err?.message || "");
  return (
    c === "EAI_AGAIN" ||
    c === "ENOTFOUND" ||
    c === "ETIMEDOUT" ||
    c === "ECONNRESET" ||
    c === "EPIPE" ||
    c === "ECONNREFUSED" ||
    (typeof c === "string" && c.startsWith("08")) ||
    /getaddrinfo/i.test(msg) ||
    /connection terminated/i.test(msg) ||
    /connection closed/i.test(msg)
  );
}

/**
 * Retry pool queries when DNS / TCP flakes (common with Docker + Supabase pooler).
 */
export async function poolQueryWithRetry(text, values, opts = {}) {
  const max = Number(
    opts.maxAttempts ?? process.env.PG_QUERY_RETRY_ATTEMPTS ?? 5,
  );
  const baseDelay = Number(
    opts.delayMs ?? process.env.PG_QUERY_RETRY_DELAY_MS ?? 500,
  );
  let last;
  for (let attempt = 1; attempt <= max; attempt += 1) {
    try {
      return await pool.query(text, values);
    } catch (e) {
      last = e;
      if (!isTransientPgNetworkError(e) || attempt >= max) {
        throw e;
      }
      const wait = baseDelay * attempt;
      console.warn(
        `pool.query retry ${attempt}/${max} after transient error (${e?.code || e?.message}): waiting ${wait}ms`,
      );
      await new Promise((r) => setTimeout(r, wait));
    }
  }
  throw last;
}

// Function to generate CTR-4 random ID
function generateUserId() {
  const randomNum = Math.floor(1000 + Math.random() * 9000); // 4 random digits
  return `CTR-${randomNum}`;
}

// Function to generate sequential ID (e.g., CUS-0001, INQ-000001)
async function generateSequentialId(prefix, padding = 4) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    // Get and increment the counter
    const result = await client.query(
      `INSERT INTO id_counters (prefix, last_number) 
       VALUES ($1, 1)
       ON CONFLICT (prefix) 
       DO UPDATE SET 
         last_number = id_counters.last_number + 1,
         updated_at = now()
       RETURNING last_number`,
      [prefix]
    );
    
    await client.query('COMMIT');
    
    const nextNumber = result.rows[0].last_number;
    const paddedNumber = nextNumber.toString().padStart(padding, '0');
    return `${prefix}-${paddedNumber}`;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/** Backfill columns on legacy customer_accounts tables (CREATE TABLE IF NOT EXISTS is not enough). */
export async function ensureCustomerAccountsColumns() {
  try {
    await pool.query(
      `ALTER TABLE customer_accounts ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now()`,
    );
    await pool.query(
      `ALTER TABLE customer_accounts ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`,
    );
  } catch (err) {
    console.warn('customer_accounts timestamp columns:', err.message);
  }
}

/** Minimal tables for login/signup — runs in seconds so the API can accept auth before full initDb. */
export async function ensureAuthSchemaQuick() {
  const cs = process.env.DATABASE_URL?.trim();
  if (
    !cs &&
    !(process.env.PGHOST || process.env.DB_HOST) &&
    !(process.env.PGUSER || process.env.DB_USER)
  ) {
    throw new Error(
      'DATABASE_URL is not set. On Railway, link your Postgres plugin to this service.',
    );
  }

  await pool.query(`CREATE EXTENSION IF NOT EXISTS pgcrypto;`);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      full_name TEXT NOT NULL,
      role TEXT NOT NULL,
      archived BOOLEAN NOT NULL DEFAULT FALSE,
      is_verified BOOLEAN DEFAULT FALSE,
      page_permissions JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS id_counters (
      prefix TEXT PRIMARY KEY,
      last_number INTEGER NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  await pool.query(`
    INSERT INTO id_counters (prefix, last_number) VALUES ('CUS', 0)
    ON CONFLICT (prefix) DO NOTHING;
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS customer_accounts (
      id TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      full_name TEXT NOT NULL,
      contact_number TEXT,
      is_verified BOOLEAN NOT NULL DEFAULT FALSE,
      otp_code VARCHAR(6),
      otp_expiry TIMESTAMPTZ,
      reset_code VARCHAR(6),
      reset_code_expires TIMESTAMPTZ,
      archived BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  try {
    await ensureCustomerAccountsUuidCompat();
  } catch (err) {
    console.warn('Auth schema customer_accounts UUID compat:', err.message);
  }

  try {
    const caCols = await getTableColumnNames('customer_accounts');
    if (!caCols.has('contact_number')) {
      if (caCols.has('phone')) {
        await pool.query(
          `ALTER TABLE customer_accounts RENAME COLUMN phone TO contact_number`,
        );
      } else {
        await pool.query(
          `ALTER TABLE customer_accounts ADD COLUMN contact_number TEXT`,
        );
      }
    }
  } catch (err) {
    console.warn('Auth schema customer_accounts contact_number:', err.message);
  }

  try {
    await pool.query(
      `ALTER TABLE customer_accounts ADD COLUMN IF NOT EXISTS delivery_address TEXT`,
    );
    await pool.query(
      `ALTER TABLE customer_accounts ADD COLUMN IF NOT EXISTS delivery_lat DECIMAL(10,8)`,
    );
    await pool.query(
      `ALTER TABLE customer_accounts ADD COLUMN IF NOT EXISTS delivery_lng DECIMAL(10,8)`,
    );
  } catch (err) {
    console.warn('Auth schema customer_accounts delivery columns:', err.message);
  }

  await ensureCustomerAccountsColumns();

  try {
    await pool.query(
      `ALTER TABLE customer_accounts ADD COLUMN IF NOT EXISTS archived BOOLEAN NOT NULL DEFAULT FALSE`,
    );
  } catch (err) {
    console.warn('Auth schema customer_accounts archived:', err.message);
  }

  try {
    await pool.query(
      `CREATE INDEX IF NOT EXISTS idx_customer_accounts_email_lower
       ON customer_accounts (lower(trim(email::text)))`,
    );
    await pool.query(
      `CREATE INDEX IF NOT EXISTS idx_users_email_lower
       ON users (lower(trim(email::text)))`,
    );
  } catch (err) {
    console.warn("Auth schema index create:", err.message);
  }
}

export async function initDb() {
  await pool.query(`CREATE EXTENSION IF NOT EXISTS pgcrypto;`);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      full_name TEXT NOT NULL,
      role TEXT NOT NULL CHECK (role IN ('admin','manager','supervisor','super_admin','cashier')),
      birthday DATE,
      contact_number TEXT,
      employment_type TEXT CHECK (employment_type IN ('regular','part_time')),
      is_verified BOOLEAN DEFAULT FALSE,
      otp_code VARCHAR(6),
      otp_expiry TIMESTAMP,
      archived BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  // Backward-compatible migration for older databases.
  await pool.query(`
    ALTER TABLE users
    ADD COLUMN IF NOT EXISTS birthday DATE,
    ADD COLUMN IF NOT EXISTS contact_number TEXT,
    ADD COLUMN IF NOT EXISTS employment_type TEXT,
    ADD COLUMN IF NOT EXISTS archived BOOLEAN NOT NULL DEFAULT FALSE;
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS help_requests (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      feature TEXT NOT NULL,
      problem TEXT NOT NULL,
      request TEXT NOT NULL,
      status TEXT NOT NULL CHECK (status IN ('unresolved','resolved')) DEFAULT 'unresolved',
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      resolved_at TIMESTAMPTZ,
      resolved_by TEXT REFERENCES users(id) ON DELETE SET NULL
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS notifications (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      message TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      is_read BOOLEAN NOT NULL DEFAULT FALSE
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS action_logs (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      feature TEXT NOT NULL DEFAULT '',
      action TEXT NOT NULL,
      other JSONB,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  await pool.query(`
    ALTER TABLE users
    ADD COLUMN IF NOT EXISTS page_permissions JSONB NOT NULL DEFAULT '{}'::jsonb;
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS event_orders (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      source TEXT NOT NULL CHECK (source IN ('new_event','online_inquiry')),
      status TEXT NOT NULL CHECK (status IN ('online_inquiries','for_down_payment','on_going','for_full_payment','completed','cancelled')),

      event_title TEXT NOT NULL,
      order_type TEXT NOT NULL CHECK (order_type IN ('catering','catering_event')),
      event_type TEXT NOT NULL,
      formality_level TEXT NOT NULL,

      customer_name TEXT NOT NULL,
      contact_person TEXT NOT NULL,
      contact_number TEXT NOT NULL,
      email_address TEXT NOT NULL,

      schedule_slots JSONB NOT NULL DEFAULT '[]'::jsonb,

      address TEXT NOT NULL,
      guest_count INT NOT NULL CHECK (guest_count >= 0),

      menu JSONB NOT NULL DEFAULT '[]'::jsonb,
      theme_design JSONB NOT NULL DEFAULT '{}'::jsonb,

      created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
      updated_by TEXT REFERENCES users(id) ON DELETE SET NULL,

      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  await pool.query(`
    ALTER TABLE event_orders
    ADD COLUMN IF NOT EXISTS post_analysis JSONB NOT NULL DEFAULT '{}'::jsonb;
  `);

  await pool.query(`
    ALTER TABLE event_orders
    ADD COLUMN IF NOT EXISTS order_type TEXT NOT NULL DEFAULT 'catering';
  `);

  await pool.query(`
    ALTER TABLE event_orders
    ADD COLUMN IF NOT EXISTS down_payment_amount DECIMAL(10,2) DEFAULT 0.00;
  `);

  await pool.query(`
    ALTER TABLE event_orders
    ADD COLUMN IF NOT EXISTS down_payment_status TEXT DEFAULT 'pending' CHECK (down_payment_status IN ('pending','paid','cancelled'));
  `);

  await pool.query(`
    ALTER TABLE event_orders
    ADD COLUMN IF NOT EXISTS down_payment_reference TEXT;
  `);

  await pool.query(`
    ALTER TABLE event_orders
    ADD COLUMN IF NOT EXISTS full_payment_amount DECIMAL(10,2) DEFAULT 0.00;
  `);

  await pool.query(`
    ALTER TABLE event_orders
    ADD COLUMN IF NOT EXISTS full_payment_status TEXT DEFAULT 'pending' CHECK (full_payment_status IN ('pending','paid','cancelled'));
  `);

  await pool.query(`
    ALTER TABLE event_orders
    ADD COLUMN IF NOT EXISTS full_payment_reference TEXT;
  `);

  // Allow NULL values for event-specific fields for catering-only orders
  await pool.query(`
    ALTER TABLE event_orders
    ALTER COLUMN event_title DROP NOT NULL;
  `);

  await pool.query(`
    ALTER TABLE event_orders
    ALTER COLUMN event_type DROP NOT NULL;
  `);

  await pool.query(`
    ALTER TABLE event_orders
    ALTER COLUMN formality_level DROP NOT NULL;
  `);

  await pool.query(`
    ALTER TABLE event_orders
    ADD COLUMN IF NOT EXISTS total_cost DECIMAL(10,2) DEFAULT 0.00;
  `);

  // Create loyalty rewards tables
  await pool.query(`
    CREATE TABLE IF NOT EXISTS rewards (
      id SERIAL PRIMARY KEY,
      title VARCHAR(255) NOT NULL,
      description TEXT NOT NULL,
      points_cost INTEGER NOT NULL DEFAULT 0,
      category VARCHAR(100) NOT NULL,
      icon_name VARCHAR(100) NOT NULL,
      color VARCHAR(50) NOT NULL,
      is_limited BOOLEAN DEFAULT FALSE,
      active BOOLEAN DEFAULT TRUE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS user_rewards (
      id SERIAL PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id),
      reward_id INTEGER NOT NULL REFERENCES rewards(id),
      redeemed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      points_used INTEGER NOT NULL,
      UNIQUE(user_id, reward_id)
    );
  `);

  await pool.query(`
    ALTER TABLE event_orders
    ADD COLUMN IF NOT EXISTS customer_id TEXT REFERENCES users(id);
  `);

  await pool.query(`
    ALTER TABLE catering_orders
    ADD COLUMN IF NOT EXISTS customer_id TEXT REFERENCES users(id);
  `);

  await pool.query(`
    ALTER TABLE event_orders
    ADD COLUMN IF NOT EXISTS checklist JSONB NOT NULL DEFAULT '[]'::jsonb;
  `);

  // Create separate catering_orders table for catering-only orders
  await pool.query(`
    CREATE TABLE IF NOT EXISTS catering_orders (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      source TEXT NOT NULL CHECK (source IN ('new_event','online_inquiry')),
      status TEXT NOT NULL CHECK (status IN ('online_inquiries','for_down_payment','on_going','for_full_payment','completed','cancelled')),

      order_type TEXT NOT NULL CHECK (order_type IN ('catering')),
      
      customer_name TEXT NOT NULL,
      contact_person TEXT NOT NULL,
      contact_number TEXT NOT NULL,
      email_address TEXT NOT NULL,
      
      schedule_slots JSONB NOT NULL DEFAULT '[]'::jsonb,
      
      address TEXT NOT NULL,
      guest_count INT NOT NULL CHECK (guest_count >= 0),
      
      menu JSONB NOT NULL DEFAULT '[]'::jsonb,
      
      created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
      updated_by TEXT REFERENCES users(id) ON DELETE SET NULL,
      
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  await ensureOrderCateringIdColumns();

  // Add catering-specific columns
  await pool.query(`
    ALTER TABLE catering_orders
    ADD COLUMN IF NOT EXISTS post_analysis JSONB NOT NULL DEFAULT '{}'::jsonb;
  `);

  await pool.query(`
    ALTER TABLE catering_orders
    ADD COLUMN IF NOT EXISTS down_payment_amount DECIMAL(10,2) DEFAULT 0.00;
  `);

  await pool.query(`
    ALTER TABLE catering_orders
    ADD COLUMN IF NOT EXISTS down_payment_status TEXT DEFAULT 'pending' CHECK (down_payment_status IN ('pending','paid','cancelled'));
  `);

  await pool.query(`
    ALTER TABLE catering_orders
    ADD COLUMN IF NOT EXISTS down_payment_reference TEXT;
  `);

  await pool.query(`
    ALTER TABLE catering_orders
    ADD COLUMN IF NOT EXISTS full_payment_amount DECIMAL(10,2) DEFAULT 0.00;
  `);

  await pool.query(`
    ALTER TABLE catering_orders
    ADD COLUMN IF NOT EXISTS full_payment_status TEXT DEFAULT 'pending' CHECK (full_payment_status IN ('pending','paid','cancelled'));
  `);

  await pool.query(`
    ALTER TABLE catering_orders
    ADD COLUMN IF NOT EXISTS full_payment_reference TEXT;
  `);

  await pool.query(`
    ALTER TABLE catering_orders
    ADD COLUMN IF NOT EXISTS total_cost DECIMAL(10,2) DEFAULT 0.00;
  `);

  await pool.query(`
    ALTER TABLE catering_orders
    ADD COLUMN IF NOT EXISTS checklist JSONB NOT NULL DEFAULT '[]'::jsonb;
  `);

  // Catering / event status: migrate legacy rows, then apply CHECK constraint
  for (const table of ['catering_orders', 'event_orders']) {
    try {
      await migrateCateringOrderStatuses(table);
      await pool.query(`ALTER TABLE ${table} DROP CONSTRAINT IF EXISTS ${table}_status_check`);
      const statusList = CATERING_STATUS_VALUES.map((s) => `'${s}'`).join(', ');
      await pool.query(
        `ALTER TABLE ${table} ADD CONSTRAINT ${table}_status_check CHECK (status IN (${statusList}))`,
      );
    } catch (err) {
      console.warn(`Warning: Could not update ${table}_status_check:`, err.message);
    }
  }

  // Public contact form: user_id optional (no fake 'guest' FK)
  try {
    await pool.query(`
      ALTER TABLE help_requests
      ALTER COLUMN user_id DROP NOT NULL;
    `);
  } catch (err) {
    console.warn('Warning: Could not relax help_requests.user_id:', err.message);
  }

  await pool.query(`
    ALTER TABLE event_orders
    ADD COLUMN IF NOT EXISTS actual_event_images JSONB NOT NULL DEFAULT '[]'::jsonb;
  `);

  await pool.query(`
    ALTER TABLE event_orders
    ADD COLUMN IF NOT EXISTS final_status TEXT DEFAULT 'successful' CHECK (final_status IN ('successful','cancelled'));
  `);

  await pool.query(`
    ALTER TABLE catering_orders
    ADD COLUMN IF NOT EXISTS final_status TEXT DEFAULT 'successful' CHECK (final_status IN ('successful','cancelled'));
  `);

  await ensureOrderCateringIdColumns();

  await pool.query(`
    ALTER TABLE catering_orders
    ADD COLUMN IF NOT EXISTS address_lat DOUBLE PRECISION;
  `);

  await pool.query(`
    ALTER TABLE catering_orders
    ADD COLUMN IF NOT EXISTS address_lng DOUBLE PRECISION;
  `);

  await pool.query(`
    ALTER TABLE event_orders
    ADD COLUMN IF NOT EXISTS address_lat DOUBLE PRECISION;
  `);

  await pool.query(`
    ALTER TABLE event_orders
    ADD COLUMN IF NOT EXISTS address_lng DOUBLE PRECISION;
  `);

  await pool.query(`
    ALTER TABLE catering_orders
    ADD COLUMN IF NOT EXISTS allergens TEXT NOT NULL DEFAULT '';
  `);

  await pool.query(`
    ALTER TABLE event_orders
    ADD COLUMN IF NOT EXISTS allergens TEXT NOT NULL DEFAULT '';
  `);

  await pool.query(`
    ALTER TABLE customer_accounts
    ADD COLUMN IF NOT EXISTS registration_platform TEXT NOT NULL DEFAULT 'web';
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS site_page_views (
      id SERIAL PRIMARY KEY,
      platform TEXT NOT NULL DEFAULT 'web',
      path TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  try {
    await pool.query(
      `CREATE INDEX IF NOT EXISTS idx_site_page_views_created ON site_page_views (created_at DESC)`,
    );
  } catch (err) {
    console.log('Index create (site_page_views):', err.message);
  }

  await ensureMenuCatalogTable('menu_dishes_allergens');
  await ensureMenuCatalogTable('menu_dishes_meal_types');

  await pool.query(`
    ALTER TABLE menu_dishes
    ADD COLUMN IF NOT EXISTS meal_type TEXT NOT NULL DEFAULT '';
  `);

  // Backfill meal_type from legacy type column for restaurant-style categories.
  await pool.query(`
    UPDATE menu_dishes
    SET meal_type = type
    WHERE trim(coalesce(meal_type, '')) = ''
      AND trim(coalesce(type, '')) <> ''
      AND lower(trim(category)) IN (
        'restaurant', 'main_course', 'noodles', 'appetizer',
        'rice', 'dessert', 'drinks', 'drink'
      )
  `);

  // List queries filter by status and sort by created_at (manager/supervisor order APIs).
  try {
    await pool.query(
      `CREATE INDEX IF NOT EXISTS idx_event_orders_status_created_at ON event_orders (status, created_at DESC)`,
    );
    await pool.query(
      `CREATE INDEX IF NOT EXISTS idx_catering_orders_status_created_at ON catering_orders (status, created_at DESC)`,
    );
  } catch (err) {
    console.log("Index create (event/catering orders status):", err.message);
  }

  // Create menu_dishes table
  await pool.query(`
    CREATE TABLE IF NOT EXISTS menu_dishes (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL,
      price TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT 'catering',
      pax_options JSONB NOT NULL DEFAULT '[]'::jsonb,
      sauces JSONB NOT NULL DEFAULT '[]'::jsonb,
      ingredients JSONB NOT NULL DEFAULT '[]'::jsonb,
      image_base64 TEXT,
      archived BOOLEAN NOT NULL DEFAULT FALSE,
      available BOOLEAN NOT NULL DEFAULT TRUE,
      archived_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      type TEXT NOT NULL DEFAULT ''
    );
  `);

  // Add type column if it doesn't exist (for existing databases)
  await pool.query(`
    ALTER TABLE menu_dishes
    ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT '';
  `);

  await pool.query(`
    ALTER TABLE menu_dishes
    ADD COLUMN IF NOT EXISTS available BOOLEAN NOT NULL DEFAULT TRUE;
  `);

  // Add set_menus column (JSONB array) to track which sets each dish belongs to
  await pool.query(`
    ALTER TABLE menu_dishes
    ADD COLUMN IF NOT EXISTS set_menus JSONB NOT NULL DEFAULT '[]'::jsonb;
  `);

  await pool.query(`
    ALTER TABLE menu_dishes
    ADD COLUMN IF NOT EXISTS public_description TEXT NOT NULL DEFAULT '';
  `);

  await pool.query(`
    ALTER TABLE menu_dishes
    ADD COLUMN IF NOT EXISTS allergens TEXT NOT NULL DEFAULT '';
  `);

  // Create indexes for menu_dishes to improve query performance
  try {
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_menu_dishes_archived ON menu_dishes (archived)`);
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_menu_dishes_category_name ON menu_dishes (category, name)`);
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_menu_dishes_available ON menu_dishes (available)`);
  } catch (err) {
    console.log("Index create (menu_dishes):", err.message);
  }

  // Drop old menu_items table if it exists (replaced by menu_dishes)
  await pool.query(`DROP TABLE IF EXISTS menu_items;`);

  // Create set_menus table for catering set menus
  await pool.query(`
    CREATE TABLE IF NOT EXISTS set_menus (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL,
      dish_ids TEXT[] NOT NULL DEFAULT '{}',
      archived BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMP NOT NULL DEFAULT now(),
      updated_at TIMESTAMP NOT NULL DEFAULT now()
    );
  `);

  // Create ID counters table for sequential ID generation
  await pool.query(`
    CREATE TABLE IF NOT EXISTS id_counters (
      prefix TEXT PRIMARY KEY,
      last_number INTEGER NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  // Create inventory table for non-perishable catering business
  await pool.query(`
    CREATE TABLE IF NOT EXISTS inventory (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      item_code TEXT UNIQUE,
      item_name TEXT NOT NULL,
      description TEXT,
      category TEXT NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 0,
      unit TEXT NOT NULL DEFAULT 'pieces',
      min_stock_level INTEGER DEFAULT 0,
      max_stock_level INTEGER,
      unit_cost DECIMAL(10,2),
      supplier TEXT,
      location TEXT,
      storage_requirements TEXT, -- e.g., 'Dry storage', 'Climate controlled', 'Secure storage'
      maintenance_schedule TEXT, -- For equipment that needs regular maintenance
      warranty_expiry TIMESTAMPTZ, -- For equipment with warranty periods
      condition TEXT DEFAULT 'good' CHECK (condition IN ('excellent', 'good', 'fair', 'poor')),
      last_maintenance_date TIMESTAMPTZ, -- For equipment maintenance tracking
      next_maintenance_date TIMESTAMPTZ, -- For equipment maintenance scheduling
      status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'discontinued', 'maintenance')),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      created_by TEXT REFERENCES users(id),
      updated_by TEXT REFERENCES users(id)
    );
  `);

  await pool.query(`
    ALTER TABLE inventory
    ADD COLUMN IF NOT EXISTS archived BOOLEAN NOT NULL DEFAULT FALSE;
  `);
  await pool.query(`
    ALTER TABLE inventory
    ADD COLUMN IF NOT EXISTS item_code TEXT;
  `);
  await pool.query(`
    ALTER TABLE inventory
    ADD COLUMN IF NOT EXISTS image_base64 TEXT;
  `);
  await pool.query(`
    WITH max_existing AS (
      SELECT COALESCE(MAX(substring(item_code from '^ITM-([0-9]+)$')::integer), 0) AS mx
      FROM inventory
      WHERE item_code ~ '^ITM-[0-9]+$'
    ),
    numbered AS (
      SELECT i.id, max_existing.mx + row_number() OVER (ORDER BY i.created_at, i.id) AS n
      FROM inventory i
      CROSS JOIN max_existing
      WHERE i.item_code IS NULL OR trim(i.item_code) = ''
    )
    UPDATE inventory i
    SET item_code = 'ITM-' || lpad(numbered.n::text, 4, '0')
    FROM numbered
    WHERE i.id = numbered.id;
  `);
  await pool.query(`
    CREATE UNIQUE INDEX IF NOT EXISTS idx_inventory_item_code
    ON inventory(item_code)
    WHERE item_code IS NOT NULL;
  `);
  await pool.query(`
    INSERT INTO id_counters (prefix, last_number, updated_at)
    SELECT 'ITM',
           COALESCE(MAX(substring(item_code from '^ITM-([0-9]+)$')::integer), 0),
           now()
    FROM inventory
    WHERE item_code ~ '^ITM-[0-9]+$'
    ON CONFLICT (prefix) DO UPDATE SET
      last_number = GREATEST(id_counters.last_number, EXCLUDED.last_number),
      updated_at = now();
  `);

  // Initialize ID counters
  await pool.query(`
    INSERT INTO id_counters (prefix, last_number) VALUES ('CUS', 0)
    ON CONFLICT (prefix) DO NOTHING;
  `);
  await pool.query(`
    INSERT INTO id_counters (prefix, last_number) VALUES ('INQ', 0)
    ON CONFLICT (prefix) DO NOTHING;
  `);

  await pool.query(`
    INSERT INTO id_counters (prefix, last_number) VALUES ('MINQ', 0)
    ON CONFLICT (prefix) DO NOTHING;
  `);
  await pool.query(`
    INSERT INTO id_counters (prefix, last_number) VALUES ('ORD', 0)
    ON CONFLICT (prefix) DO NOTHING;
  `);

  // Create customer_accounts table with TEXT ID for CUS-0000 format
  await pool.query(`
    CREATE TABLE IF NOT EXISTS customer_accounts (
      id TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      full_name TEXT NOT NULL,
      contact_number TEXT,
      is_verified BOOLEAN NOT NULL DEFAULT FALSE,
      otp_code VARCHAR(6),
      otp_expiry TIMESTAMPTZ,
      reset_code VARCHAR(6),
      reset_code_expires TIMESTAMPTZ,
      archived BOOLEAN NOT NULL DEFAULT FALSE,
      restaurant_loyalty_points INTEGER NOT NULL DEFAULT 0,
      catering_loyalty_points INTEGER NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  try {
    const caCols = await getTableColumnNames('customer_accounts');
    if (!caCols.has('contact_number')) {
      if (caCols.has('phone')) {
        await pool.query(
          `ALTER TABLE customer_accounts RENAME COLUMN phone TO contact_number`,
        );
        console.log('Migration: renamed customer_accounts.phone → contact_number');
      } else {
        await pool.query(
          `ALTER TABLE customer_accounts ADD COLUMN contact_number TEXT`,
        );
        console.log('Migration: added customer_accounts.contact_number');
      }
    }
  } catch (err) {
    console.log('Migration customer_accounts contact_number:', err.message);
  }

  // Migration: Add loyalty points columns to customer_accounts if they don't exist
  try {
    await pool.query(`ALTER TABLE customer_accounts ADD COLUMN IF NOT EXISTS restaurant_loyalty_points INTEGER NOT NULL DEFAULT 0`);
    await pool.query(`ALTER TABLE customer_accounts ADD COLUMN IF NOT EXISTS catering_loyalty_points INTEGER NOT NULL DEFAULT 0`);
    console.log('Migration: Added loyalty points columns to customer_accounts');
  } catch (err) {
    console.log('Migration check for customer_accounts loyalty points columns:', err.message);
  }

  try {
    await pool.query(
      `ALTER TABLE customer_accounts ADD COLUMN IF NOT EXISTS archived BOOLEAN NOT NULL DEFAULT FALSE`,
    );
    console.log('Migration: Added archived column to customer_accounts');
  } catch (err) {
    console.log('Migration check for customer_accounts archived:', err.message);
  }

  try {
    await pool.query(
      `ALTER TABLE customer_accounts ADD COLUMN IF NOT EXISTS delivery_address TEXT`,
    );
    await pool.query(
      `ALTER TABLE customer_accounts ADD COLUMN IF NOT EXISTS delivery_lat DECIMAL(10,8)`,
    );
    await pool.query(
      `ALTER TABLE customer_accounts ADD COLUMN IF NOT EXISTS delivery_lng DECIMAL(10,8)`,
    );
  } catch (err) {
    console.log('Migration check for customer_accounts delivery columns:', err.message);
  }

  await ensureCustomerAccountsColumns();

  // Create canonical restaurant_orders table for online + walk-in orders.
  await pool.query(`
    CREATE TABLE IF NOT EXISTS restaurant_orders (
      order_id TEXT PRIMARY KEY,
      id uuid DEFAULT gen_random_uuid(),
      customer_id TEXT,
      mobile_id BIGINT,
      order_source TEXT NOT NULL DEFAULT 'WEB_APP',
      total_cost DECIMAL(12,2),
      tray_items JSONB NOT NULL DEFAULT '[]'::jsonb,
      loyalty_points_restaurant_obtained INTEGER NOT NULL DEFAULT 0,
      loyalty_reward_restaurant_obtained TEXT,
      delivery_address TEXT,
      delivery_lat DOUBLE PRECISION,
      delivery_lng DOUBLE PRECISION,
      delivery_notes TEXT,
      delivery_tracking_url TEXT,
      full_name TEXT,
      user_email TEXT,
      payment_mode TEXT NOT NULL DEFAULT 'GCASH ONLY',
      delivery_time TEXT DEFAULT 'NOW',
      payment_reference_initial TEXT,
      payment_reference_balance TEXT,
      payment_proof_initial TEXT,
      payment_proof_balance TEXT,
      payment_uploaded_initial BOOLEAN NOT NULL DEFAULT FALSE,
      payment_uploaded_balance BOOLEAN NOT NULL DEFAULT FALSE,
      payment_confirmed_initial BOOLEAN NOT NULL DEFAULT FALSE,
      payment_confirmed_balance BOOLEAN NOT NULL DEFAULT FALSE,
      order_status TEXT NOT NULL DEFAULT 'PENDING_CASHIER',
      contact_number TEXT NOT NULL DEFAULT '',
      cashier_amount_received_initial DECIMAL(12,2),
      cashier_amount_received_balance DECIMAL(12,2),
      feedback_stars INTEGER,
      feedback_remarks TEXT,
      amount_paid DECIMAL(10,2),
      change_given DECIMAL(10,2),
      payment_method TEXT,
      payment_proof TEXT,
      pos_customer_label TEXT,
      balance_proof_pending_review BOOLEAN NOT NULL DEFAULT FALSE,
      pos_claimed BOOLEAN NOT NULL DEFAULT FALSE,
      pos_claimed_at TIMESTAMPTZ,
      feedback_submitted_at TIMESTAMPTZ,
      note TEXT NOT NULL DEFAULT '',
      payment_uploaded BOOLEAN NOT NULL DEFAULT FALSE,
      submitted_order_dt_stamp TIMESTAMPTZ,
      last_updated_order_status_dt_stamp TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  // Migration: ensure id column exists (legacy deployments created without it)
  try {
    await pool.query(
      `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid()`,
    );
    await pool.query(
      `UPDATE restaurant_orders SET id = gen_random_uuid() WHERE id IS NULL`,
    );
    await pool.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS restaurant_orders_id_key ON restaurant_orders (id)`,
    );
    console.log('Migration: ensured id column on restaurant_orders');
  } catch (err) {
    console.log('Migration check for restaurant_orders id:', err.message);
  }

  await ensureRestaurantOrderWorkflowColumns();

  // Migration: Add points_earned column to catering_orders
  try {
    await pool.query(`ALTER TABLE catering_orders ADD COLUMN IF NOT EXISTS points_earned INTEGER DEFAULT 0`);
    console.log('Migration: Added points_earned column to catering_orders');
  } catch (err) {
    console.log('Migration check for catering_orders points_earned:', err.message);
  }

  // Migration: Add points_earned column to event_orders
  try {
    await pool.query(`ALTER TABLE event_orders ADD COLUMN IF NOT EXISTS points_earned INTEGER DEFAULT 0`);
    console.log('Migration: Added points_earned column to event_orders');
  } catch (err) {
    console.log('Migration check for event_orders points_earned:', err.message);
  }


  try {
    await pool.query(
      `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS feedback_stars INTEGER`,
    );
    await pool.query(
      `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS feedback_remarks TEXT`,
    );
    await pool.query(
      `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS feedback_submitted_at TIMESTAMPTZ`,
    );
    console.log('Migration: Added restaurant order feedback columns');
  } catch (err) {
    console.log('Migration check for restaurant_orders feedback:', err.message);
  }

  // Migration: seating plan (floor image + tables + seats) for event_orders
  try {
    await pool.query(
      `ALTER TABLE event_orders ADD COLUMN IF NOT EXISTS seating_plan JSONB NOT NULL DEFAULT '{}'::jsonb`,
    );
    console.log('Migration: Added seating_plan column to event_orders');
  } catch (err) {
    console.log('Migration check for event_orders seating_plan:', err.message);
  }

  // Migration: theme_design for catering+event orders only (event_orders table)
  try {
    await pool.query(
      `ALTER TABLE event_orders ADD COLUMN IF NOT EXISTS theme_design JSONB NOT NULL DEFAULT '{}'::jsonb`,
    );
    console.log('Migration: ensured theme_design on event_orders');
  } catch (err) {
    console.log('Migration check for event_orders theme_design:', err.message);
  }

  // Migration: order_status column (Supabase schema; legacy deployments may have `status`)
  try {
    const roCols = await getTableColumnNames('restaurant_orders');
    if (!roCols.has('order_status')) {
      if (roCols.has('status')) {
        await pool.query(
          `ALTER TABLE restaurant_orders RENAME COLUMN status TO order_status`,
        );
        console.log('Migration: renamed restaurant_orders.status → order_status');
      } else {
        await pool.query(
          `ALTER TABLE restaurant_orders ADD COLUMN order_status TEXT NOT NULL DEFAULT 'PENDING_CASHIER'`,
        );
        console.log('Migration: added restaurant_orders.order_status');
      }
    }
  } catch (err) {
    console.log('Migration restaurant_orders order_status:', err.message);
  }

  // Restaurant order workflow columns + guest checkout
  try {
    await pool.query(
      `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS user_email TEXT`,
    );
    await pool.query(
      `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS payment_proof TEXT`,
    );
    await pool.query(
      `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS payment_uploaded BOOLEAN NOT NULL DEFAULT FALSE`,
    );
    await pool.query(
      `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS amount_paid DECIMAL(10,2)`,
    );
    await pool.query(
      `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS change_given DECIMAL(10,2)`,
    );
    await pool.query(`
      ALTER TABLE restaurant_orders DROP CONSTRAINT IF EXISTS restaurant_orders_status_check
    `);
    await pool.query(`
      ALTER TABLE restaurant_orders DROP CONSTRAINT IF EXISTS restaurant_orders_order_status_check
    `);
    await pool.query(`
      UPDATE restaurant_orders SET order_status = 'pending_cashier' WHERE order_status = 'pending'
    `);
    await pool.query(`
      UPDATE restaurant_orders SET order_status = 'in_preparation'
      WHERE order_status IN ('confirmed', 'preparing')
    `);
    await pool.query(`
      ALTER TABLE restaurant_orders ADD CONSTRAINT restaurant_orders_order_status_check
      CHECK (order_status IN (
        'pending_cashier', 'in_preparation', 'out_for_delivery', 'delivered', 'cancelled'
      ))
    `);
    console.log('Migration: restaurant_orders workflow columns and statuses');
  } catch (err) {
    console.log('Migration restaurant_orders workflow:', err.message);
  }

  try {
    await ensureCustomerTrayDraftsSchema();
  } catch (err) {
    console.warn('[initDb] customer_tray_drafts schema skipped:', err.message);
  }

  try {
    await pool.query(`
      INSERT INTO id_counters (prefix, last_number) VALUES ('USR', 0)
      ON CONFLICT (prefix) DO NOTHING
    `);
    await pool.query(`
      INSERT INTO id_counters (prefix, last_number) VALUES ('ORD', 0)
      ON CONFLICT (prefix) DO NOTHING
    `);
    await pool.query(`
      INSERT INTO id_counters (prefix, last_number) VALUES ('TR', 0)
      ON CONFLICT (prefix) DO NOTHING
    `);
  } catch (err) {
    console.log('Migration id_counters USR/ORD/TR:', err.message);
  }

  // Migration: Add non-perishable catering business fields to inventory table
  try {
    await pool.query(`ALTER TABLE inventory ADD COLUMN IF NOT EXISTS storage_requirements TEXT`);
    await pool.query(`ALTER TABLE inventory ADD COLUMN IF NOT EXISTS maintenance_schedule TEXT`);
    await pool.query(`ALTER TABLE inventory ADD COLUMN IF NOT EXISTS warranty_expiry TIMESTAMPTZ`);
    await pool.query(`ALTER TABLE inventory ADD COLUMN IF NOT EXISTS condition TEXT DEFAULT 'good' CHECK (condition IN ('excellent', 'good', 'fair', 'poor'))`);
    await pool.query(`ALTER TABLE inventory ADD COLUMN IF NOT EXISTS last_maintenance_date TIMESTAMPTZ`);
    await pool.query(`ALTER TABLE inventory ADD COLUMN IF NOT EXISTS next_maintenance_date TIMESTAMPTZ`);
    await pool.query(`ALTER TABLE inventory ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'discontinued', 'maintenance'))`);
    console.log('Migration: Added non-perishable catering business fields to inventory table');
  } catch (err) {
    console.log('Migration check for inventory fields:', err.message);
  }

  // Create website_content table for persistent staff edits
  await pool.query(`
    CREATE TABLE IF NOT EXISTS website_content (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      content JSONB NOT NULL DEFAULT '{}',
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS system_settings (
      key TEXT PRIMARY KEY,
      value JSONB NOT NULL DEFAULT '{}'::jsonb,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  const dishCount = await pool.query(`SELECT COUNT(*) FROM menu_dishes`);
  if (parseInt(dishCount.rows[0].count, 10) === 0) {
    console.log(
      "[initDb] menu_dishes is empty — add dishes via staff Menu admin (default CSV seed disabled).",
    );
  }
}

const ROLE_ACCOUNT_LIMITS_KEY = 'role_account_limits';

/** @returns {Record<string, number>} */
export async function getRoleAccountLimits() {
  try {
    const r = await pool.query(
      `SELECT value FROM system_settings WHERE key = $1`,
      [ROLE_ACCOUNT_LIMITS_KEY],
    );
    if (r.rows.length === 0) return {};
    const v = r.rows[0].value;
    if (!v || typeof v !== 'object') return {};
    return v;
  } catch (e) {
    console.log('getRoleAccountLimits:', e.message);
    return {};
  }
}

export async function setRoleAccountLimits(limits) {
  await pool.query(
    `INSERT INTO system_settings (key, value, updated_at)
     VALUES ($1, $2::jsonb, now())
     ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()`,
    [ROLE_ACCOUNT_LIMITS_KEY, JSON.stringify(limits ?? {})],
  );
}

/**
 * Next ORD-#### that is unique vs both id_counters and existing restaurant_orders
 * (counters can drift after manual imports / restores).
 */
export async function allocateRestaurantOrderNo() {
  const roCols = await getTableColumnNames('restaurant_orders');
  const idCol =
    roCols.has('order_id')
      ? 'order_id'
      : roCols.has('order_no')
        ? 'order_no'
        : null;

  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("SELECT pg_advisory_xact_lock(902103447)");
    const maxRow = idCol
      ? await client.query(`
      SELECT COALESCE(MAX(
        CASE
          WHEN ${idCol} ~ '^ORD-[0-9]+$'
          THEN NULLIF((regexp_match(${idCol}, '^ORD-([0-9]+)$'))[1], '')::integer
          ELSE NULL
        END
      ), 0)::int AS mx
      FROM restaurant_orders
    `)
      : { rows: [{ mx: 0 }] };
    const tableMax = Number(maxRow.rows[0]?.mx ?? 0) || 0;
    const ctr = await client.query(
      `SELECT last_number FROM id_counters WHERE prefix = 'ORD' FOR UPDATE`,
    );
    const counterVal =
      ctr.rows.length > 0 ? Number(ctr.rows[0].last_number) || 0 : 0;
    const next = Math.max(tableMax, counterVal) + 1;
    await client.query(
      `INSERT INTO id_counters (prefix, last_number, updated_at)
       VALUES ('ORD', $1, now())
       ON CONFLICT (prefix) DO UPDATE SET
         last_number = $1,
         updated_at = now()`,
      [next],
    );
    await client.query("COMMIT");
    return `ORD-${String(next).padStart(6, "0")}`;
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
}

const LOYALTY_PROGRAM_CONFIG_KEY = 'loyalty_program_config';

/** @returns {{ pointsConditions: unknown[], rewardsConditions: unknown[] }} */
export async function getLoyaltyProgramConfig() {
  try {
    const r = await pool.query(
      `SELECT value FROM system_settings WHERE key = $1`,
      [LOYALTY_PROGRAM_CONFIG_KEY],
    );
    if (r.rows.length === 0) {
      return { pointsConditions: [], rewardsConditions: [] };
    }
    const v = r.rows[0].value;
    if (!v || typeof v !== 'object') {
      return { pointsConditions: [], rewardsConditions: [] };
    }
    return {
      pointsConditions: Array.isArray(v.pointsConditions) ? v.pointsConditions : [],
      rewardsConditions: Array.isArray(v.rewardsConditions) ? v.rewardsConditions : [],
    };
  } catch (e) {
    console.log('getLoyaltyProgramConfig:', e.message);
    return { pointsConditions: [], rewardsConditions: [] };
  }
}

export async function setLoyaltyProgramConfig(config) {
  await pool.query(
    `INSERT INTO system_settings (key, value, updated_at)
     VALUES ($1, $2::jsonb, now())
     ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()`,
    [LOYALTY_PROGRAM_CONFIG_KEY, JSON.stringify(config ?? {})],
  );
}

let restaurantOrderWorkflowColumnsPromise = null;

/** Critical restaurant_orders columns used before full initDb (auto-cancel, payment). */
export async function ensureRestaurantOrderWorkflowColumns() {
  if (!restaurantOrderWorkflowColumnsPromise) {
    restaurantOrderWorkflowColumnsPromise =
      ensureRestaurantOrderWorkflowColumnsOnce().catch((err) => {
        restaurantOrderWorkflowColumnsPromise = null;
        throw err;
      });
  }
  return restaurantOrderWorkflowColumnsPromise;
}

async function ensureRestaurantOrderWorkflowColumnsOnce() {
  const tableCols = await getTableColumnNames('restaurant_orders');
  if (tableCols.size === 0) return;

  if (!tableCols.has('order_status')) {
    if (tableCols.has('status')) {
      await pool.query(
        `ALTER TABLE restaurant_orders RENAME COLUMN status TO order_status`,
      );
      console.log('[db] renamed restaurant_orders.status → order_status');
    } else {
      await pool.query(
        `ALTER TABLE restaurant_orders ADD COLUMN order_status TEXT NOT NULL DEFAULT 'PENDING_CASHIER'`,
      );
      console.log('[db] added restaurant_orders.order_status');
    }
  }

  const alters = [
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS user_email TEXT`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS payment_proof TEXT`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS payment_uploaded BOOLEAN NOT NULL DEFAULT FALSE`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS amount_paid DECIMAL(10,2)`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS change_given DECIMAL(10,2)`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS last_customer_followup_at TIMESTAMPTZ`,
  ];
  for (const sql of alters) {
    await pool.query(sql);
  }
}

let customerTrayDraftsSchemaPromise = null;

/** Ensures customer_tray_drafts has customer_id PK (legacy tables may lack it). */
export async function ensureCustomerTrayDraftsSchema() {
  if (!customerTrayDraftsSchemaPromise) {
    customerTrayDraftsSchemaPromise = ensureCustomerTrayDraftsSchemaOnce().catch(
      (err) => {
        customerTrayDraftsSchemaPromise = null;
        throw err;
      },
    );
  }
  return customerTrayDraftsSchemaPromise;
}

/**
 * Child tables (tray_drafts, restaurant_orders.customer_id) use TEXT.
 * Production customer_accounts.id is often UUID — FK TEXT → UUID is invalid in Postgres.
 */
export async function resolveCustomerIdChildColumn() {
  const parentType = await getColumnSqlType('customer_accounts', 'id');
  const parentIsUuid = parentType === 'UUID';
  return {
    sqlType: 'TEXT',
    withFk: !parentIsUuid && parentType === 'TEXT',
    parentIsUuid,
  };
}

/** JOIN when customer_accounts.id may be UUID and child.customer_id is TEXT. */
export function customerAccountIdJoinSql(caAlias, childAlias) {
  return `${caAlias}.id::text = ${childAlias}.customer_id::text`;
}

/** When customer_accounts.id is UUID, child tables use TEXT customer_id (uuid string); optional customer_code for CUS- ids. */
export async function ensureCustomerAccountsUuidCompat() {
  const parentType = await getColumnSqlType('customer_accounts', 'id');
  if (parentType !== 'UUID') return { parentIsUuid: false };

  await pool.query(
    `ALTER TABLE customer_accounts ADD COLUMN IF NOT EXISTS customer_code TEXT`,
  );
  try {
    await pool.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS customer_accounts_customer_code_key
       ON customer_accounts (customer_code) WHERE customer_code IS NOT NULL`,
    );
  } catch (err) {
    console.warn('[db] customer_code unique index:', err.message);
  }

  for (const table of ['restaurant_orders', 'customer_tray_drafts']) {
    try {
      await pool.query(
        `ALTER TABLE ${table} DROP CONSTRAINT IF EXISTS ${table}_customer_id_fkey`,
      );
    } catch (_) {}
  }

  return { parentIsUuid: true };
}

async function createCustomerTrayDraftsTable(withFk) {
  const fkClause = withFk
    ? ' REFERENCES customer_accounts(id) ON DELETE CASCADE'
    : '';
  await pool.query(`
    CREATE TABLE customer_tray_drafts (
      customer_id TEXT PRIMARY KEY${fkClause},
      user_email TEXT,
      tray_lines JSONB NOT NULL DEFAULT '[]'::jsonb,
      tray_items JSONB NOT NULL DEFAULT '[]'::jsonb,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
}

async function ensureCustomerTrayDraftsTrayItemsColumn() {
  const cols = await getTableColumnNames('customer_tray_drafts');

  await pool.query(
    `ALTER TABLE customer_tray_drafts ADD COLUMN IF NOT EXISTS tray_lines JSONB NOT NULL DEFAULT '[]'::jsonb`,
  );
  await pool.query(
    `ALTER TABLE customer_tray_drafts ADD COLUMN IF NOT EXISTS tray_items JSONB NOT NULL DEFAULT '[]'::jsonb`,
  );

  try {
    const legacyItemsExpr = cols.has('items') ? `, items` : '';
    await pool.query(`
      UPDATE customer_tray_drafts
      SET tray_lines = COALESCE(NULLIF(tray_lines, '[]'::jsonb), tray_items${legacyItemsExpr}, '[]'::jsonb),
          tray_items = COALESCE(NULLIF(tray_items, '[]'::jsonb), tray_lines${legacyItemsExpr}, '[]'::jsonb)
      WHERE tray_lines IS NULL OR tray_lines = '[]'::jsonb
         OR tray_items IS NULL OR tray_items = '[]'::jsonb
    `);
  } catch (err) {
    console.warn('[db] customer_tray_drafts tray_lines/tray_items backfill:', err.message);
  }
}

async function resolveTrayDraftsCustomerIdType() {
  return resolveCustomerIdChildColumn();
}

async function ensureCustomerTrayDraftsSchemaOnce() {
  const { withFk: wantFk, parentIsUuid } = await resolveTrayDraftsCustomerIdType();
  const cols = await getTableColumnNames('customer_tray_drafts');

  if (cols.size === 0) {
    try {
      await createCustomerTrayDraftsTable(wantFk);
      console.log('[db] created customer_tray_drafts (customer_id TEXT)');
    } catch (err) {
      console.warn('[db] customer_tray_drafts with FK failed, retrying without FK:', err.message);
      await createCustomerTrayDraftsTable(false);
      console.log('[db] created customer_tray_drafts (customer_id TEXT, no FK)');
    }
    await ensureCustomerTrayDraftsTrayItemsColumn();
    return;
  }

  if (cols.has('customer_id')) {
    const childType = await getColumnSqlType('customer_tray_drafts', 'customer_id');
    if (childType === 'UUID' || (childType && childType !== 'TEXT')) {
      try {
        await pool.query(
          `ALTER TABLE customer_tray_drafts
           ALTER COLUMN customer_id TYPE TEXT USING customer_id::text`,
        );
        console.log('[db] customer_tray_drafts.customer_id → TEXT');
      } catch (err) {
        console.warn('[db] could not cast customer_tray_drafts.customer_id to TEXT:', err.message);
      }
    }
    if (parentIsUuid) {
      try {
        await pool.query(
          `ALTER TABLE customer_tray_drafts DROP CONSTRAINT IF EXISTS customer_tray_drafts_customer_id_fkey`,
        );
      } catch (_) {}
    }
    await pool.query(
      `ALTER TABLE customer_tray_drafts ADD COLUMN IF NOT EXISTS tray_lines JSONB NOT NULL DEFAULT '[]'::jsonb`,
    );
    await pool.query(
      `ALTER TABLE customer_tray_drafts ADD COLUMN IF NOT EXISTS tray_items JSONB NOT NULL DEFAULT '[]'::jsonb`,
    );
    await pool.query(
      `ALTER TABLE customer_tray_drafts ADD COLUMN IF NOT EXISTS user_email TEXT`,
    );
    await pool.query(
      `ALTER TABLE customer_tray_drafts ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`,
    );
    await ensureCustomerTrayDraftsTrayItemsColumn();
    return;
  }

  for (const legacyCol of ['account_id', 'user_id', 'customer_account_id']) {
    if (cols.has(legacyCol)) {
      await pool.query(
        `ALTER TABLE customer_tray_drafts RENAME COLUMN ${legacyCol} TO customer_id`,
      );
      console.log(`[db] renamed customer_tray_drafts.${legacyCol} → customer_id`);
      await pool.query(
        `ALTER TABLE customer_tray_drafts ADD COLUMN IF NOT EXISTS tray_lines JSONB NOT NULL DEFAULT '[]'::jsonb`,
      );
      await pool.query(
        `ALTER TABLE customer_tray_drafts ADD COLUMN IF NOT EXISTS tray_items JSONB NOT NULL DEFAULT '[]'::jsonb`,
      );
      await pool.query(
        `ALTER TABLE customer_tray_drafts ADD COLUMN IF NOT EXISTS user_email TEXT`,
      );
      await pool.query(
        `ALTER TABLE customer_tray_drafts ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`,
      );
      await ensureCustomerTrayDraftsTrayItemsColumn();
      return;
    }
  }

  console.warn(
    '[db] customer_tray_drafts missing customer_id — recreating table (draft rows dropped)',
  );
  await pool.query(`DROP TABLE IF EXISTS customer_tray_drafts CASCADE`);
  try {
    await createCustomerTrayDraftsTable(wantFk);
    console.log('[db] recreated customer_tray_drafts (customer_id TEXT)');
  } catch (err) {
    console.warn('[db] recreate with FK failed, without FK:', err.message);
    await createCustomerTrayDraftsTable(false);
    console.log('[db] recreated customer_tray_drafts (customer_id TEXT, no FK)');
  }
}

let orderCateringIdColumnsPromise = null;

function pickCateringIdCol(cols) {
  if (cols.has('catering_id')) return 'catering_id';
  if (cols.has('inquiry_id')) return 'inquiry_id';
  return null;
}

/** Ensures catering_id exists on event_orders and catering_orders (migrates legacy inquiry_id). */
export async function ensureOrderCateringIdColumns() {
  if (!orderCateringIdColumnsPromise) {
    orderCateringIdColumnsPromise = ensureOrderCateringIdColumnsOnce().catch((err) => {
      orderCateringIdColumnsPromise = null;
      throw err;
    });
  }
  return orderCateringIdColumnsPromise;
}

/** @deprecated use ensureOrderCateringIdColumns */
export const ensureOrderInquiryIdColumns = ensureOrderCateringIdColumns;

async function ensureOrderCateringIdColumnsOnce() {
  for (const table of ['event_orders', 'catering_orders']) {
    const cols = await getTableColumnNames(table);
    if (cols.size === 0) continue;

    if (cols.has('inquiry_id') && !cols.has('catering_id')) {
      await pool.query(
        `ALTER TABLE ${table} RENAME COLUMN inquiry_id TO catering_id`,
      );
      console.log(`[db] Renamed inquiry_id → catering_id on ${table}`);
      cols.delete('inquiry_id');
      cols.add('catering_id');
    }

    if (!cols.has('catering_id')) {
      await pool.query(
        `ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS catering_id TEXT`,
      );
      console.log(`[db] Added catering_id column to ${table}`);
    }

    await pool.query(`DROP INDEX IF EXISTS ${table}_inquiry_id_key`);
    await pool.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS ${table}_catering_id_key
       ON ${table} (catering_id)
       WHERE catering_id IS NOT NULL`,
    );
  }
}

/** @returns {Promise<Set<string>>} */
export async function getTableColumnNames(tableName) {
  const r = await pool.query(
    `SELECT column_name
     FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = $1`,
    [tableName],
  );
  return new Set(r.rows.map((row) => row.column_name));
}

/** @returns {Promise<string|null>} SQL type for DDL (TEXT, UUID, INTEGER, …) */
export async function getColumnSqlType(tableName, columnName) {
  const r = await pool.query(
    `SELECT data_type, udt_name
     FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = $1 AND column_name = $2`,
    [tableName, columnName],
  );
  if (!r.rows.length) return null;
  const { data_type: dt, udt_name: udt } = r.rows[0];
  if (dt === 'uuid' || udt === 'uuid') return 'UUID';
  if (dt === 'integer' || dt === 'bigint' || dt === 'smallint') return 'INTEGER';
  if (dt === 'text' || dt === 'character varying') return 'TEXT';
  return 'TEXT';
}

export const CATERING_STATUS_VALUES = [
  'online_inquiries',
  'for_down_payment',
  'on_going',
  'for_full_payment',
  'completed',
  'cancelled',
];

/** Map legacy catering/event status values before CHECK constraints are applied. */
export async function migrateCateringOrderStatuses(tableName) {
  const cols = await getTableColumnNames(tableName);
  if (cols.size === 0 || !cols.has('status')) return;

  await pool.query(
    `UPDATE ${tableName} SET status = 'online_inquiries'
     WHERE status IN ('new_event', 'online_inquiry')`,
  );
  await pool.query(
    `UPDATE ${tableName} SET status = 'on_going'
     WHERE status IN ('for_processing', 'for_post_analysis')`,
  );
  await pool.query(
    `UPDATE ${tableName} SET status = 'for_down_payment'
     WHERE status IN ('for_downpayment')`,
  );
  await pool.query(
    `UPDATE ${tableName} SET status = 'online_inquiries'
     WHERE status IS NULL OR trim(status::text) = ''`,
  );
  await pool.query(
    `UPDATE ${tableName} SET status = 'online_inquiries'
     WHERE status IS NOT NULL AND status NOT IN (${CATERING_STATUS_VALUES.map((s) => `'${s}'`).join(', ')})`,
  );
}

/**
 * Catalog tables store unique allergen / meal-type labels (column `name`).
 * Older DBs may have junction tables with the same names — rename and recreate.
 */
async function ensureMenuCatalogTable(tableName) {
  const allowed = new Set(['menu_dishes_allergens', 'menu_dishes_meal_types']);
  if (!allowed.has(tableName)) {
    throw new Error(`ensureMenuCatalogTable: invalid table ${tableName}`);
  }

  const cols = await getTableColumnNames(tableName);
  if (cols.size === 0) {
    await pool.query(`
      CREATE TABLE ${tableName} (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      );
    `);
  } else if (!cols.has('name')) {
    const legacy = `${tableName}_legacy_junction`;
    const legacyExists = await getTableColumnNames(legacy);
    const renameTo =
      legacyExists.size > 0
        ? `${tableName}_legacy_${Date.now()}`
        : legacy;
    try {
      await pool.query(`ALTER TABLE ${tableName} RENAME TO ${renameTo}`);
      console.log(`Migration: renamed legacy ${tableName} to ${renameTo}`);
    } catch (err) {
      const msg = String(err?.message || err);
      if (!/already exists|duplicate/i.test(msg)) {
        throw err;
      }
      console.log(`Migration: ${tableName} rename skipped (${msg})`);
    }
    const afterRename = await getTableColumnNames(tableName);
    if (afterRename.size === 0) {
      await pool.query(`
        CREATE TABLE ${tableName} (
          id SERIAL PRIMARY KEY,
          name TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        );
      `);
    }
  }

  try {
    const indexName =
      tableName === 'menu_dishes_allergens'
        ? 'idx_menu_dishes_allergens_name_lower'
        : 'idx_menu_dishes_meal_types_name_lower';
    await pool.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS ${indexName}
       ON ${tableName} (lower(trim(name)))`,
    );
  } catch (err) {
    console.log(`Index create (${tableName}):`, err.message);
  }
}

/** @returns {string[]} */
export async function getMenuAllergenCatalog() {
  try {
    const r = await pool.query(
      `SELECT name FROM menu_dishes_allergens ORDER BY lower(name) ASC`,
    );
    return r.rows.map((row) => String(row.name).trim()).filter(Boolean);
  } catch (e) {
    console.log('getMenuAllergenCatalog:', e.message);
    return [];
  }
}

/** @returns {string[]} */
export async function getCustomAllergenPresets() {
  return getMenuAllergenCatalog();
}

/** Upsert custom allergen labels from dish form into menu_dishes_allergens. */
export async function upsertMenuAllergensFromSerialized(serialized, basePresetList) {
  const known = new Set(
    (basePresetList || []).map((s) => String(s).trim().toLowerCase()).filter(Boolean),
  );
  const parts = String(serialized || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  for (const p of parts) {
    if (known.has(p.toLowerCase())) continue;
    known.add(p.toLowerCase());
    try {
      await pool.query(
        `INSERT INTO menu_dishes_allergens (name)
         SELECT $1 WHERE NOT EXISTS (
           SELECT 1 FROM menu_dishes_allergens WHERE lower(trim(name)) = lower(trim($1))
         )`,
        [p],
      );
    } catch (e) {
      console.log('upsertMenuAllergensFromSerialized:', e.message);
    }
  }
  return getMenuAllergenCatalog();
}

/** @returns {string[]} */
export async function getMenuMealTypeCatalog() {
  try {
    const r = await pool.query(
      `SELECT name FROM menu_dishes_meal_types ORDER BY lower(name) ASC`,
    );
    return r.rows.map((row) => String(row.name).trim()).filter(Boolean);
  } catch (e) {
    console.log('getMenuMealTypeCatalog:', e.message);
    return [];
  }
}

/** Ensure meal type exists in catalog; returns canonical name. */
export async function upsertMenuMealType(name) {
  const trimmed = String(name || '').trim();
  if (!trimmed) return '';
  try {
    await pool.query(
      `INSERT INTO menu_dishes_meal_types (name)
       SELECT $1 WHERE NOT EXISTS (
         SELECT 1 FROM menu_dishes_meal_types WHERE lower(trim(name)) = lower(trim($1))
       )`,
      [trimmed],
    );
  } catch (e) {
    console.log('upsertMenuMealType:', e.message);
  }
  return trimmed;
}

/** @deprecated use upsertMenuAllergensFromSerialized */
export async function mergeCustomAllergensFromSerialized(serialized, presetList) {
  return upsertMenuAllergensFromSerialized(serialized, presetList);
}

/** Serial staff account id: USR-0001, USR-0002, … */
export async function allocateStaffUserId() {
  return generateSequentialId('USR', 4);
}

/**
 * Catering / event order public id: TR-000001 (shared counter for catering_orders + event_orders).
 */
export async function allocateCateringTransactionId() {
  const cateringCols = await getTableColumnNames('catering_orders');
  const eventCols = await getTableColumnNames('event_orders');
  const catIdCol = pickCateringIdCol(cateringCols);
  const evIdCol = pickCateringIdCol(eventCols);

  const trMaxSubquery = (table, idCol) =>
    idCol
      ? `COALESCE((
          SELECT MAX(
            CASE
              WHEN ${idCol} ~ '^TR-[0-9]+$'
              THEN NULLIF((regexp_match(${idCol}, '^TR-([0-9]+)$'))[1], '')::integer
              ELSE NULL
            END
          ) FROM ${table}
        ), 0)`
      : '0';

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock(902103448)');

    const maxFromTables = await client.query(`
      SELECT GREATEST(
        ${trMaxSubquery('catering_orders', catIdCol)},
        ${trMaxSubquery('event_orders', evIdCol)}
      )::int AS mx
    `);
    const tableMax = Number(maxFromTables.rows[0]?.mx ?? 0) || 0;
    const ctr = await client.query(
      `SELECT last_number FROM id_counters WHERE prefix = 'TR' FOR UPDATE`,
    );
    const counterVal =
      ctr.rows.length > 0 ? Number(ctr.rows[0].last_number) || 0 : 0;
    const next = Math.max(tableMax, counterVal) + 1;
    await client.query(
      `INSERT INTO id_counters (prefix, last_number, updated_at)
       VALUES ('TR', $1, now())
       ON CONFLICT (prefix) DO UPDATE SET
         last_number = $1,
         updated_at = now()`,
      [next],
    );
    await client.query('COMMIT');
    return `TR-${String(next).padStart(6, '0')}`;
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}

export { pool, generateUserId, generateSequentialId };
