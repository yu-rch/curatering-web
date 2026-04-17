import { Pool } from "pg";

const pool = new Pool(
  process.env.DATABASE_URL
    ? { connectionString: process.env.DATABASE_URL }
    : {
        host: process.env.PGHOST || process.env.DB_HOST,
        port: process.env.PGPORT
          ? Number(process.env.PGPORT)
          : process.env.DB_PORT
            ? Number(process.env.DB_PORT)
            : undefined,
        user: process.env.PGUSER || process.env.DB_USER,
        password: process.env.PGPASSWORD || process.env.DB_PASSWORD,
        database: process.env.PGDATABASE || process.env.DB_NAME,
      },
);

// Function to generate CTR-4 random ID
function generateUserId() {
  const randomNum = Math.floor(1000 + Math.random() * 9000); // 4 random digits
  return `CTR-${randomNum}`;
}

export async function initDb() {
  await pool.query(`CREATE EXTENSION IF NOT EXISTS pgcrypto;`);

  // Check if users table exists with uuid type and migrate if needed
  const tableExists = await pool.query(`
    SELECT EXISTS (
      SELECT FROM information_schema.tables 
      WHERE table_name = 'users'
    );
  `);

  if (tableExists.rows[0].exists) {
    // Check if id column is still uuid type
    const idColumn = await pool.query(`
      SELECT data_type 
      FROM information_schema.columns 
      WHERE table_name = 'users' AND column_name = 'id';
    `);
    
    if (idColumn.rows.length > 0 && idColumn.rows[0].data_type === 'uuid') {
      // Helper function to check if table exists
      const tableExistsCheck = async (tableName) => {
        const result = await pool.query(`
          SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_name = '${tableName}'
          );
        `);
        return result.rows[0].exists;
      };

      // Migrate to text-based ID - only process tables that exist
      if (await tableExistsCheck('help_requests')) {
        await pool.query(`ALTER TABLE help_requests DROP CONSTRAINT IF EXISTS help_requests_user_id_fkey;`);
        await pool.query(`ALTER TABLE help_requests DROP CONSTRAINT IF EXISTS help_requests_resolved_by_fkey;`);
        await pool.query(`ALTER TABLE help_requests ALTER COLUMN user_id TYPE TEXT;`);
        await pool.query(`ALTER TABLE help_requests ALTER COLUMN resolved_by TYPE TEXT;`);
      }
      if (await tableExistsCheck('notifications')) {
        await pool.query(`ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_user_id_fkey;`);
        await pool.query(`ALTER TABLE notifications ALTER COLUMN user_id TYPE TEXT;`);
      }
      if (await tableExistsCheck('action_logs')) {
        await pool.query(`ALTER TABLE action_logs DROP CONSTRAINT IF EXISTS action_logs_user_id_fkey;`);
        await pool.query(`ALTER TABLE action_logs ALTER COLUMN user_id TYPE TEXT;`);
      }
      if (await tableExistsCheck('resolved_help_requests')) {
        await pool.query(`ALTER TABLE resolved_help_requests DROP CONSTRAINT IF EXISTS resolved_help_requests_resolved_by_fkey;`);
        await pool.query(`ALTER TABLE resolved_help_requests ALTER COLUMN resolved_by TYPE TEXT;`);
      }
      if (await tableExistsCheck('catering_orders')) {
        await pool.query(`ALTER TABLE catering_orders DROP CONSTRAINT IF EXISTS catering_orders_created_by_fkey;`);
        await pool.query(`ALTER TABLE catering_orders DROP CONSTRAINT IF EXISTS catering_orders_updated_by_fkey;`);
        await pool.query(`ALTER TABLE catering_orders DROP CONSTRAINT IF EXISTS catering_orders_customer_id_fkey;`);
        await pool.query(`ALTER TABLE catering_orders ALTER COLUMN created_by TYPE TEXT;`);
        await pool.query(`ALTER TABLE catering_orders ALTER COLUMN updated_by TYPE TEXT;`);
        await pool.query(`ALTER TABLE catering_orders ALTER COLUMN customer_id TYPE TEXT;`);
      }
      if (await tableExistsCheck('event_orders')) {
        await pool.query(`ALTER TABLE event_orders DROP CONSTRAINT IF EXISTS event_orders_created_by_fkey;`);
        await pool.query(`ALTER TABLE event_orders DROP CONSTRAINT IF EXISTS event_orders_updated_by_fkey;`);
        await pool.query(`ALTER TABLE event_orders DROP CONSTRAINT IF EXISTS event_orders_customer_id_fkey;`);
        await pool.query(`ALTER TABLE event_orders ALTER COLUMN created_by TYPE TEXT;`);
        await pool.query(`ALTER TABLE event_orders ALTER COLUMN updated_by TYPE TEXT;`);
        await pool.query(`ALTER TABLE event_orders ALTER COLUMN customer_id TYPE TEXT;`);
      }
      if (await tableExistsCheck('user_rewards')) {
        await pool.query(`ALTER TABLE user_rewards DROP CONSTRAINT IF EXISTS user_rewards_user_id_fkey;`);
        await pool.query(`ALTER TABLE user_rewards ALTER COLUMN user_id TYPE TEXT;`);
      }
      
      await pool.query(`ALTER TABLE users ALTER COLUMN id TYPE TEXT;`);
    }
  }

  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      full_name TEXT NOT NULL,
      role TEXT NOT NULL CHECK (role IN ('admin','manager','supervisor','super_admin')),
      is_verified BOOLEAN DEFAULT FALSE,
      otp_code VARCHAR(6),
      otp_expiry TIMESTAMP,
      archived BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
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
    ADD COLUMN IF NOT EXISTS full_payment_amount DECIMAL(10,2) DEFAULT 0.00;
  `);

  await pool.query(`
    ALTER TABLE event_orders
    ADD COLUMN IF NOT EXISTS full_payment_status TEXT DEFAULT 'pending' CHECK (full_payment_status IN ('pending','paid','cancelled'));
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

  // Insert sample rewards
  await pool.query(`
    INSERT INTO rewards (title, description, points_cost, category, icon_name, color, is_limited) VALUES
    ('10% Off Next Order', 'Get 10% discount on your next catering order', 500, 'Discount', 'local_offer', 'green', FALSE),
    ('Free Birthday Cake', 'Complimentary birthday cake with any catering order', 800, 'Free Item', 'cake', 'pink', FALSE),
    ('Priority Service', 'Skip the queue and get priority service for your event', 1200, 'Service', 'star', 'amber', FALSE),
    ('Double Points Day', 'Earn 2x points on all orders for one day', 0, 'Bonus', 'diamond', 'purple', TRUE),
    ('VIP Event Access', 'Exclusive access to VIP events and special offers', 2000, 'Exclusive', 'emoji_events', 'deepOrange', FALSE)
    ON CONFLICT DO NOTHING;
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
    ADD COLUMN IF NOT EXISTS full_payment_amount DECIMAL(10,2) DEFAULT 0.00;
  `);

  await pool.query(`
    ALTER TABLE catering_orders
    ADD COLUMN IF NOT EXISTS full_payment_status TEXT DEFAULT 'pending' CHECK (full_payment_status IN ('pending','paid','cancelled'));
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

  // Add set_menus column (JSONB array) to track which sets each dish belongs to
  await pool.query(`
    ALTER TABLE menu_dishes
    ADD COLUMN IF NOT EXISTS set_menus JSONB NOT NULL DEFAULT '[]'::jsonb;
  `);

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

  // Create customer_accounts table
  await pool.query(`
    CREATE TABLE IF NOT EXISTS customer_accounts (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
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

  // Create restaurant_orders table for customer orders
  await pool.query(`
    CREATE TABLE IF NOT EXISTS restaurant_orders (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      customer_id uuid REFERENCES customer_accounts(id) ON DELETE SET NULL,
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
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  // Insert default dishes from CSV if table is empty
  const dishCount = await pool.query(`SELECT COUNT(*) FROM menu_dishes`);
  if (parseInt(dishCount.rows[0].count) === 0) {
    console.log('Inserting default menu dishes...');
    
    // Catering Set dishes (from CSV)
    const cateringSets = [
      { name: 'SET A', ingredients: ['Crispy Pata (Medium)', 'Fried Chicken (8 pcs)', 'Chopsuey', 'Shanghai (25 pcs)', 'Rice (3 pcs)'] },
      { name: 'SET B', ingredients: ['Lechon Belly (1kg)', 'Chicken Curry (8 pcs)', 'Chopsuey', 'Carbonara (1 tray)', 'Rice (3 pcs)'] },
      { name: 'SET C', ingredients: ['Lechon Belly (1kg)', 'Fried Chicken (8 pcs)', 'Chopsuey', 'Shanghai (25 pcs)', 'Rice (3 pcs)'] },
      { name: 'SET D', ingredients: ['Lechon Belly (1kg)', 'Chicken Curry (8 pcs)', 'Lumpiang Sariwa (15 pcs)', 'Carbonara (1 tray)', 'Rice (3 pcs)'] },
      { name: 'SET E', ingredients: ['Lechon Belly (1kg)', 'Fried Chicken (8 pcs)', 'Chopsuey', 'Lumpiang Sariwa (15 pcs)', 'Rice (3 pcs)'] },
      { name: 'SET F', ingredients: ['Crispy Pata (Large)', 'Fried Chicken (12 pcs)', 'Chopsuey', 'Shanghai (30 pcs)', 'Rice (4 pcs)'] },
      { name: 'SET G', ingredients: ['Lechon Belly (2kg)', 'Chicken Curry (12 pcs)', 'Chopsuey', 'Carbonara (2 trays)', 'Rice (4 pcs)'] },
      { name: 'SET H', ingredients: ['Lechon Belly (2kg)', 'Fried Chicken (12 pcs)', 'Chopsuey', 'Shanghai (30 pcs)', 'Rice (4 pcs)'] },
      { name: 'SET I', ingredients: ['Lechon Belly (2kg)', 'Chicken Curry (12 pcs)', 'Lumpiang Sariwa (20 pcs)', 'Carbonara (2 trays)', 'Rice (4 pcs)'] },
    ];

    for (const set of cateringSets) {
      await pool.query(`
        INSERT INTO menu_dishes (name, price, category, pax_options, ingredients)
        VALUES ($1, $2, $3, $4, $5)
      `, [set.name, '0.00', 'catering', JSON.stringify(['10 pax', '20 pax', '30 pax', '50 pax', '100 pax']), JSON.stringify(set.ingredients)]);
    }

    // Restaurant menu items
    const restaurantItems = [
      // Rice Meals
      { name: 'Bistek', price: '180', category: 'restaurant', ingredients: ['Beef', 'Onions', 'Soy Sauce', 'Calamansi', 'Garlic', 'Rice'], sauces: [] },
      { name: 'Pork Steak', price: '170', category: 'restaurant', ingredients: ['Pork', 'Onions', 'Soy Sauce', 'Calamansi', 'Garlic', 'Rice'], sauces: [] },
      { name: 'Chicken Curry', price: '170', category: 'restaurant', ingredients: ['Chicken', 'Coconut Milk', 'Curry Powder', 'Potatoes', 'Carrots', 'Rice'], sauces: [] },
      { name: 'Porkchop', price: '170', category: 'restaurant', ingredients: ['Pork', 'Gravy', 'Rice'], sauces: ['Gravy'] },
      { name: 'Fried Chicken', price: '170', category: 'restaurant', ingredients: ['Chicken', 'Rice'], sauces: ['Gravy'] },
      { name: 'Beefsteak', price: '180', category: 'restaurant', ingredients: ['Beef', 'Onions', 'Soy Sauce', 'Calamansi', 'Garlic', 'Rice'], sauces: [] },
      { name: 'Liempo', price: '180', category: 'restaurant', ingredients: ['Pork Belly', 'Soy Sauce', 'Vinegar', 'Garlic', 'Rice'], sauces: [] },
      { name: 'Pata Kare-Kare', price: '195', category: 'restaurant', ingredients: ['Pork Pata', 'Peanut Sauce', 'Vegetables', 'Rice'], sauces: ['Bagoong'] },
      { name: 'Beef Kare-Kare', price: '195', category: 'restaurant', ingredients: ['Beef', 'Peanut Sauce', 'Vegetables', 'Rice'], sauces: ['Bagoong'] },
      { name: 'Sinigang na Baboy', price: '195', category: 'restaurant', ingredients: ['Pork', 'Tamarind', 'Vegetables', 'Rice'], sauces: [] },
      { name: 'Sinigang na Beef', price: '195', category: 'restaurant', ingredients: ['Beef', 'Tamarind', 'Vegetables', 'Rice'], sauces: [] },
      { name: 'Lechon Kawali', price: '170', category: 'restaurant', ingredients: ['Pork Belly', 'Lechon Sauce', 'Rice'], sauces: ['Lechon Sauce'] },
      { name: 'Buttered Chicken', price: '220', category: 'restaurant', ingredients: ['Chicken', 'Butter', 'Garlic', 'Rice'], sauces: [] },
      { name: 'Crispy Pata (Solo)', price: '250', category: 'restaurant', ingredients: ['Pork Pata', 'Soy Vinegar Dip', 'Rice'], sauces: ['Soy Vinegar Dip'] },
      { name: 'Crispy Pata (Buddy)', price: '350', category: 'restaurant', ingredients: ['Pork Pata', 'Soy Vinegar Dip', 'Rice'], sauces: ['Soy Vinegar Dip'] },
      { name: 'Crispy Pata (Superbuddy)', price: '430', category: 'restaurant', ingredients: ['Pork Pata', 'Soy Vinegar Dip', 'Rice'], sauces: ['Soy Vinegar Dip'] },
      // Silog Meals
      { name: 'Tapsilog', price: '150', category: 'restaurant', ingredients: ['Tapa', 'Egg', 'Garlic Rice'], sauces: [] },
      { name: 'Bacsilog', price: '130', category: 'restaurant', ingredients: ['Bacon', 'Egg', 'Garlic Rice'], sauces: [] },
      { name: 'Hamsilog', price: '130', category: 'restaurant', ingredients: ['Ham', 'Egg', 'Garlic Rice'], sauces: [] },
      { name: 'Chicksilog', price: '150', category: 'restaurant', ingredients: ['Chicken', 'Egg', 'Garlic Rice'], sauces: [] },
      { name: 'Liemposilog', price: '150', category: 'restaurant', ingredients: ['Liempo', 'Egg', 'Garlic Rice'], sauces: [] },
      { name: 'Porksilog', price: '150', category: 'restaurant', ingredients: ['Pork Chop', 'Egg', 'Garlic Rice'], sauces: [] },
      { name: 'Sisig Silog', price: '180', category: 'restaurant', ingredients: ['Sisig', 'Egg', 'Garlic Rice'], sauces: [] },
      { name: 'Chao Fan', price: '130', category: 'restaurant', ingredients: ['Rice', 'Vegetables', 'Meat'], sauces: [] },
      // Pasta
      { name: 'Carbonara', price: '200', category: 'restaurant', ingredients: ['Pasta', 'Cream', 'Bacon', 'Mushroom', 'Cheese'], sauces: [] },
      { name: 'Spaghetti', price: '180', category: 'restaurant', ingredients: ['Pasta', 'Tomato Sauce', 'Hotdog', 'Ground Pork'], sauces: [] },
      // Sandwiches
      { name: 'Hamburger', price: '80', category: 'restaurant', ingredients: ['Bun', 'Beef Patty', 'Lettuce', 'Tomato'], sauces: [] },
      { name: 'Cheese Burger', price: '90', category: 'restaurant', ingredients: ['Bun', 'Beef Patty', 'Cheese', 'Lettuce', 'Tomato'], sauces: [] },
      { name: 'Ham Sandwich', price: '60', category: 'restaurant', ingredients: ['Bread', 'Ham', 'Lettuce', 'Mayonnaise'], sauces: [] },
      // Drinks
      { name: 'Coke', price: '40', category: 'restaurant', ingredients: ['Coca-Cola'], sauces: [] },
      { name: 'Sprite', price: '40', category: 'restaurant', ingredients: ['Sprite'], sauces: [] },
      { name: 'Royal', price: '40', category: 'restaurant', ingredients: ['Royal Tru-Orange'], sauces: [] },
      { name: 'Coke Zero', price: '45', category: 'restaurant', ingredients: ['Coke Zero'], sauces: [] },
      { name: 'Iced Tea', price: '35', category: 'restaurant', ingredients: ['Tea', 'Lemon', 'Sugar', 'Ice'], sauces: [] },
      { name: 'Pineapple Juice', price: '35', category: 'restaurant', ingredients: ['Pineapple Juice'], sauces: [] },
      { name: 'Iced Coffee', price: '50', category: 'restaurant', ingredients: ['Coffee', 'Milk', 'Sugar', 'Ice'], sauces: [] },
      { name: 'Hot Coffee', price: '45', category: 'restaurant', ingredients: ['Coffee', 'Milk', 'Sugar'], sauces: [] },
      // Crispy Pata Family
      { name: 'Crispy Pata (Small)', price: '550', category: 'restaurant', ingredients: ['Pork Pata', 'Soy Vinegar Dip'], sauces: ['Soy Vinegar Dip'] },
      { name: 'Crispy Pata (Medium)', price: '780', category: 'restaurant', ingredients: ['Pork Pata', 'Soy Vinegar Dip'], sauces: ['Soy Vinegar Dip'] },
      { name: 'Crispy Pata (Large)', price: '950', category: 'restaurant', ingredients: ['Pork Pata', 'Soy Vinegar Dip'], sauces: ['Soy Vinegar Dip'] },
      // Patatim Family
      { name: 'Patatim (Small)', price: '550', category: 'restaurant', ingredients: ['Pork Pata', 'Star Anise', 'Soy Sauce', 'Sugar'], sauces: [] },
      { name: 'Patatim (Medium)', price: '780', category: 'restaurant', ingredients: ['Pork Pata', 'Star Anise', 'Soy Sauce', 'Sugar'], sauces: [] },
      { name: 'Patatim (Large)', price: '950', category: 'restaurant', ingredients: ['Pork Pata', 'Star Anise', 'Soy Sauce', 'Sugar'], sauces: [] },
      // Champorado
      { name: 'Champorado', price: '80', category: 'restaurant', ingredients: ['Rice', 'Chocolate', 'Milk', 'Sugar'], sauces: [] },
    ];

    for (const item of restaurantItems) {
      await pool.query(`
        INSERT INTO menu_dishes (name, price, category, pax_options, ingredients, sauces)
        VALUES ($1, $2, $3, $4, $5, $6)
      `, [item.name, item.price, item.category, JSON.stringify(['1 pax', '5 pax', '10 pax', '20 pax', '50 pax']), JSON.stringify(item.ingredients), JSON.stringify(item.sauces || [])]);
    }
    
    console.log('Default menu dishes inserted successfully');
  }
}

export { pool, generateUserId };
