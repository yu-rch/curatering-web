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

  // Default 120s — Supabase default statement_timeout is often ~8s; heavy list queries need more.
  const statementTimeout =
    process.env.PG_STATEMENT_TIMEOUT?.trim() || "120s";

  return {
    connectionString: cs,
    max: Number(process.env.PG_POOL_MAX || 25),
    idleTimeoutMillis: Number(process.env.PG_IDLE_TIMEOUT_MS || 10000), // Reduced from 30s to 10s
    connectionTimeoutMillis: Number(process.env.PG_CONNECTION_TIMEOUT_MS || 20000),
    keepAlive: true,
    options: `-c statement_timeout=${statementTimeout}`,
    // Supabase / managed Postgres: TLS required; pooler may drop idle sockets — keepAlive + timeouts help.
    ...(isSupabase || process.env.PG_SSL === "1"
      ? { ssl: { rejectUnauthorized: false } }
      : {}),
  };
}

const config = buildPgPoolConfig();
console.log("PostgreSQL pool configuration:", { max: config.max, connectionString: config.connectionString ? "***" : "individual params" });
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

/** Minimal tables for login/signup — runs in seconds so the API can accept auth before full initDb. */
export async function ensureAuthSchemaQuick() {
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
      phone TEXT,
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

  await pool.query(`
    CREATE TABLE IF NOT EXISTS customer_profiles (
      id SERIAL PRIMARY KEY,
      customer_id TEXT NOT NULL REFERENCES customer_accounts(id) ON DELETE CASCADE,
      loyalty_points INTEGER NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      UNIQUE(customer_id)
    );
  `);

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
      status TEXT NOT NULL CHECK (status IN ('new_event','online_inquiries','for_processing','for_post_analysis','completed')),

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
      status TEXT NOT NULL CHECK (status IN ('new_event','online_inquiries','for_processing','for_post_analysis','completed','cancelled')),

      order_type TEXT NOT NULL CHECK (order_type IN ('catering')),
      
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

  // Update catering_orders status constraint to include 'cancelled'
  try {
    await pool.query(`
      ALTER TABLE catering_orders
      DROP CONSTRAINT IF EXISTS catering_orders_status_check;
    `);

    await pool.query(`
      ALTER TABLE catering_orders
      ADD CONSTRAINT catering_orders_status_check CHECK (status IN ('new_event','online_inquiries','for_processing','for_post_analysis','completed','cancelled'));
    `);
  } catch (err) {
    // Constraint might already exist with different definition, log but don't fail
    console.warn('Warning: Could not update catering_orders_status_check constraint:', err.message);
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

  // Add inquiry_id column for formatted IDs (INQ-000000, MINQ-000000)
  await pool.query(`
    ALTER TABLE event_orders
    ADD COLUMN IF NOT EXISTS inquiry_id TEXT UNIQUE;
  `);

  await pool.query(`
    ALTER TABLE catering_orders
    ADD COLUMN IF NOT EXISTS inquiry_id TEXT UNIQUE;
  `);

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
    ADD COLUMN IF NOT EXISTS image_base64 TEXT;
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

  // Create cart tables for synchronization
  await pool.query(`
    CREATE TABLE IF NOT EXISTS cart_sessions (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      device_id TEXT NOT NULL,
      customer_token TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS cart_items (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      session_id uuid REFERENCES cart_sessions(id) ON DELETE CASCADE,
      dish_id TEXT NOT NULL,
      dish_name TEXT NOT NULL,
      dish_price TEXT NOT NULL,
      dish_category TEXT NOT NULL,
      dish_type TEXT NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 1,
      selected_sauce TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cart_sessions_device ON cart_sessions(device_id);
  `);

  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cart_sessions_token ON cart_sessions(customer_token);
  `);

  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cart_items_session ON cart_items(session_id);
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
      phone TEXT,
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

  // Migration: Add loyalty points columns to customer_accounts if they don't exist
  try {
    await pool.query(`ALTER TABLE customer_accounts ADD COLUMN IF NOT EXISTS restaurant_loyalty_points INTEGER NOT NULL DEFAULT 0`);
    await pool.query(`ALTER TABLE customer_accounts ADD COLUMN IF NOT EXISTS catering_loyalty_points INTEGER NOT NULL DEFAULT 0`);
    console.log('Migration: Added loyalty points columns to customer_accounts');
  } catch (err) {
    console.log('Migration check for customer_accounts loyalty points columns:', err.message);
  }

  // Create customer_profiles table for delivery addresses and additional info
  await pool.query(`
    CREATE TABLE IF NOT EXISTS customer_profiles (
      id SERIAL PRIMARY KEY,
      customer_id TEXT NOT NULL REFERENCES customer_accounts(id) ON DELETE CASCADE,
      delivery_address TEXT,
      delivery_lat DECIMAL(10,8),
      delivery_lng DECIMAL(10,8),
      loyalty_points INTEGER NOT NULL DEFAULT 0,
      restaurant_loyalty_points INTEGER NOT NULL DEFAULT 0,
      catering_loyalty_points INTEGER NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      UNIQUE(customer_id)
    );
  `);


  // Create restaurant_orders table for customer orders
  await pool.query(`
    CREATE TABLE IF NOT EXISTS restaurant_orders (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      order_no TEXT UNIQUE,
      customer_id TEXT REFERENCES customer_accounts(id) ON DELETE SET NULL,
      full_name TEXT,
      phone TEXT,
      items JSONB NOT NULL DEFAULT '[]'::jsonb,
      total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
      delivery_address TEXT NOT NULL,
      delivery_lat DECIMAL(10,8),
      delivery_lng DECIMAL(10,8),
      delivery_time TIMESTAMPTZ,
      delivery_notes TEXT,
      status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'preparing', 'out_for_delivery', 'delivered', 'cancelled')),
      payment_reference TEXT,
      payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'failed')),
      delivery_tracking_url TEXT,
      points_earned INTEGER DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  // Migration: Add delivery_time column if it doesn't exist
  try {
    await pool.query(
      `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS delivery_time TIMESTAMPTZ`,
    );
    console.log('Migration: Added delivery_time column to restaurant_orders');
  } catch (err) {
    console.log(
      'Migration check for restaurant_orders delivery_time:',
      err.message,
    );
  }

  // Some deployments have delivery_time NOT NULL without a default; allow null
  // and rely on INSERT COALESCE(now()) so legacy clients stay valid.
  try {
    await pool.query(
      `ALTER TABLE restaurant_orders ALTER COLUMN delivery_time DROP NOT NULL`,
    );
    console.log('Migration: delivery_time may be null on restaurant_orders');
  } catch (err) {
    console.log('Migration check restaurant_orders delivery_time nullability:', err.message);
  }

  // Migration: Add full_name and phone columns if they don't exist (for existing tables)
  try {
    await pool.query(`ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS full_name TEXT`);
    await pool.query(`ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS phone TEXT`);
    console.log('Migration: Added full_name and phone columns to restaurant_orders');
  } catch (err) {
    console.log('Migration check for restaurant_orders columns:', err.message);
  }

  // Migration: Add order_no column to restaurant_orders
  try {
    await pool.query(`ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS order_no TEXT UNIQUE`);
    console.log('Migration: Added order_no column to restaurant_orders');
  } catch (err) {
    console.log('Migration check for restaurant_orders order_no:', err.message);
  }

  // Migration: Add points_earned column to restaurant_orders
  try {
    await pool.query(`ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS points_earned INTEGER DEFAULT 0`);
    console.log('Migration: Added points_earned column to restaurant_orders');
  } catch (err) {
    console.log('Migration check for restaurant_orders points_earned:', err.message);
  }

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

  // Migration: seating plan (floor image + tables + seats) for event_orders
  try {
    await pool.query(
      `ALTER TABLE event_orders ADD COLUMN IF NOT EXISTS seating_plan JSONB NOT NULL DEFAULT '{}'::jsonb`,
    );
    console.log('Migration: Added seating_plan column to event_orders');
  } catch (err) {
    console.log('Migration check for event_orders seating_plan:', err.message);
  }

  // Migration: Fix invalid status values in existing restaurant_orders data
  try {
    console.log('Migration: Fixing invalid status values in restaurant_orders...');
    
    // Check for and fix invalid status values
    const invalidStatusResult = await pool.query(`
      SELECT id, status FROM restaurant_orders 
      WHERE status NOT IN ('pending', 'confirmed', 'preparing', 'out_for_delivery', 'delivered', 'cancelled')
    `);
    
    if (invalidStatusResult.rowCount > 0) {
      console.log(`Found ${invalidStatusResult.rowCount} orders with invalid status values`);
      
      // Update invalid status values to valid ones
      await pool.query(`UPDATE restaurant_orders SET status = 'confirmed' WHERE status = 'processing'`);
      await pool.query(`UPDATE restaurant_orders SET status = 'out_for_delivery' WHERE status = 'for_delivery'`);
      await pool.query(`UPDATE restaurant_orders SET status = 'delivered' WHERE status = 'completed'`);
      
      console.log('Migration: Fixed invalid status values in restaurant_orders');
    } else {
      console.log('Migration: No invalid status values found');
    }
  } catch (err) {
    console.log('Migration check for invalid status values:', err.message);
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

  // Insert default dishes from CSV if table is empty
  const dishCount = await pool.query(`SELECT COUNT(*) FROM menu_dishes`);
  if (parseInt(dishCount.rows[0].count) === 0) {
    console.log('Inserting default menu dishes...');
    

    for (const set of cateringSets) {
      await pool.query(`
        INSERT INTO menu_dishes (name, price, category, pax_options, ingredients)
        VALUES ($1, $2, $3, $4, $5)
      `, [set.name, '0.00', 'catering', JSON.stringify(['10 pax', '20 pax', '30 pax', '50 pax', '100 pax']), JSON.stringify(set.ingredients)]);
    }

    for (const item of restaurantItems) {
      await pool.query(`
        INSERT INTO menu_dishes (name, price, category, pax_options, ingredients, sauces)
        VALUES ($1, $2, $3, $4, $5, $6)
      `, [item.name, item.price, item.category, JSON.stringify(['1 pax', '5 pax', '10 pax', '20 pax', '50 pax']), JSON.stringify(item.ingredients), JSON.stringify(item.sauces || [])]);
    }
    
    console.log('Default menu dishes inserted successfully');
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
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("SELECT pg_advisory_xact_lock(902103447)");
    const maxRow = await client.query(`
      SELECT COALESCE(MAX(
        CASE
          WHEN order_no ~ '^ORD-[0-9]+$'
          THEN (regexp_match(order_no, '^ORD-([0-9]+)$'))[1]::integer
          ELSE NULL
        END
      ), 0)::int AS mx
      FROM restaurant_orders
    `);
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
    return `ORD-${String(next).padStart(4, "0")}`;
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
}

export { pool, generateUserId, generateSequentialId };
