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

const cateringSets = [
  { name: 'Set Menu A', ingredients: ['Chicken Adobo', 'Pancit Canton', 'Steamed Rice', 'Lumpiang Shanghai', 'Fruit Salad'] },
  { name: 'Set Menu B', ingredients: ['Beef Caldereta', 'Chopsuey', 'Garlic Rice', 'Fish Fillet', 'Leche Flan'] },
  { name: 'Set Menu C', ingredients: ['Pork Sinigang', 'Grilled Tilapia', 'Java Rice', 'Pork BBQ', 'Buko Pandan'] },
];

const restaurantItems = [
  { name: 'Chicken Adobo', price: '180.00', category: 'main_course', ingredients: ['Chicken', 'Soy Sauce', 'Vinegar', 'Garlic'], sauces: [] },
  { name: 'Beef Caldereta', price: '220.00', category: 'main_course', ingredients: ['Beef', 'Tomato Sauce', 'Potatoes', 'Carrots'], sauces: [] },
  { name: 'Pancit Canton', price: '150.00', category: 'noodles', ingredients: ['Egg Noodles', 'Vegetables', 'Soy Sauce'], sauces: [] },
  { name: 'Lumpiang Shanghai', price: '120.00', category: 'appetizer', ingredients: ['Ground Pork', 'Vegetables', 'Wrapper'], sauces: ['Sweet & Sour Sauce'] },
  { name: 'Steamed Rice', price: '35.00', category: 'rice', ingredients: ['Rice'], sauces: [] },
  { name: 'Leche Flan', price: '60.00', category: 'dessert', ingredients: ['Eggs', 'Milk', 'Sugar'], sauces: [] },
];

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
  await pool.query(`
    ALTER TABLE catering_orders
    DROP CONSTRAINT IF EXISTS catering_orders_status_check;
  `);

  await pool.query(`
    ALTER TABLE catering_orders
    ADD CONSTRAINT catering_orders_status_check CHECK (status IN ('new_event','online_inquiries','for_processing','for_post_analysis','completed','cancelled'));
  `);

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

  // Create inventory table
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
      status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'discontinued')),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      created_by TEXT REFERENCES users(id),
      updated_by TEXT REFERENCES users(id)
    );
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

  // Migrations commented out - no longer needed
  // Migration: Update coordinate columns precision to float8 (async, non-blocking)
  /*
  try {
    // Run coordinate column updates in background without blocking startup
    setTimeout(async () => {
      try {
        console.log('Background: Updating coordinate columns precision...');
        // Use a separate connection for migrations to avoid pool interference
        const client = await pool.connect();
        try {
          await client.query(`ALTER TABLE restaurant_orders ALTER COLUMN delivery_lat TYPE float8 USING delivery_lat::float8`);
          await client.query(`ALTER TABLE restaurant_orders ALTER COLUMN delivery_lng TYPE float8 USING delivery_lng::float8`);
          await client.query(`ALTER TABLE customer_profiles ALTER COLUMN delivery_lat TYPE float8 USING delivery_lat::float8`);
          await client.query(`ALTER TABLE customer_profiles ALTER COLUMN delivery_lng TYPE float8 USING delivery_lng::float8`);
          console.log('Background: Coordinate columns precision updated successfully');
        } finally {
          client.release();
        }
      } catch (err) {
        console.log('Background: Coordinate columns precision update:', err.message);
      }
    }, 5000); // Start after 5 seconds to allow server to fully initialize
  } catch (err) {
    console.log('Migration check for coordinate columns precision:', err.message);
  }
  */

  // Migration: Add performance indexes for restaurant orders (async, non-blocking)
  /*
  try {
    // Run index creation in background without blocking startup
    setTimeout(async () => {
      try {
        console.log('Background: Creating restaurant orders indexes...');
        // Use a separate connection for migrations to avoid pool interference
        const client = await pool.connect();
        try {
          await client.query(`CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_restaurant_orders_status ON restaurant_orders(status)`);
          await client.query(`CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_restaurant_orders_created_at ON restaurant_orders(created_at DESC)`);
          await client.query(`CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_restaurant_orders_status_created_at ON restaurant_orders(status, created_at DESC)`);
          console.log('Background: Restaurant orders indexes created successfully');
        } finally {
          client.release();
        }
      } catch (err) {
        console.log('Background: Restaurant orders indexes creation:', err.message);
      }
    }, 6000); // Start after 6 seconds to allow server to fully initialize
  } catch (err) {
    console.log('Migration check for restaurant orders indexes:', err.message);
  }
  */

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

export { pool, generateUserId, generateSequentialId };
