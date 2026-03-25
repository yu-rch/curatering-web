import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';

import { initDb, pool } from './db.js';

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT ? Number(process.env.PORT) : 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'dev-change-me';

const allowedRoles = new Set(['admin', 'manager', 'supervisor', 'super_admin']);
const allowedHelpStatuses = new Set(['unresolved', 'resolved']);

function signToken({ userId, role }) {
  return jwt.sign(
    { role },
    JWT_SECRET,
    {
      subject: userId,
      expiresIn: '8h',
    },
  );
}

function authRequired(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ message: 'Missing bearer token' });
  }

  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = {
      id: payload.sub,
      role: payload.role,
    };
    return next();
  } catch (e) {
    return res.status(401).json({ message: 'Invalid token' });
  }
}

function requireSuperAdmin(req, res, next) {
  if (req.user?.role !== 'super_admin') {
    return res.status(403).json({ message: 'Super Admin only' });
  }
  return next();
}

function requireRoles(req, res, next, allowed) {
  const role = req.user?.role;
  if (role === 'super_admin') return next();
  if (!allowed.has(role)) {
    return res.status(403).json({ message: 'Not allowed' });
  }
  return next();
}

async function logAction({ client, userId, feature = '', action, other = null }) {
  const q = client ?? pool;
  await q.query(
    `INSERT INTO action_logs (user_id, feature, action, other)
     VALUES ($1, $2, $3, $4);`,
    [userId, feature, action, other],
  );
}

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({ message: 'email and password are required' });
    }

    const result = await pool.query(
      `SELECT id, email, full_name, role, archived, password_hash
       FROM users
       WHERE email = $1
       LIMIT 1;`,
      [email],
    );

    if (result.rowCount === 0) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const user = result.rows[0];
    if (user.archived) {
      return res.status(401).json({ message: 'Account archived' });
    }

    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const token = signToken({ userId: user.id, role: user.role });
    return res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        fullName: user.full_name,
        role: user.role,
        archived: user.archived,
      },
    });
  } catch (e) {
    return res.status(500).json({ message: 'Login failed' });
  }
});

app.get('/api/auth/me', authRequired, async (req, res) => {
  const { id } = req.user;
  const result = await pool.query(
    `SELECT id, email, full_name, role, archived
     FROM users
     WHERE id = $1
     LIMIT 1;`,
    [id],
  );

  if (result.rowCount === 0) return res.status(404).json({ message: 'User not found' });
  const u = result.rows[0];
  return res.json({
    user: {
      id: u.id,
      email: u.email,
      fullName: u.full_name,
      role: u.role,
      archived: u.archived,
    },
  });
});

// User request help (from Settings module)
app.post('/api/help-requests', authRequired, async (req, res) => {
  try {
    const { feature, problem, request } = req.body || {};
    if (!feature || !problem || !request) {
      return res.status(400).json({ message: 'feature, problem, request are required' });
    }

    const result = await pool.query(
      `INSERT INTO help_requests (user_id, feature, problem, request, status)
       VALUES ($1, $2, $3, $4, 'unresolved')
       RETURNING id;`,
      [req.user.id, feature, problem, request],
    );

    await logAction({
      userId: req.user.id,
      feature,
      action: 'sent help request',
      other: { helpRequestId: result.rows[0].id },
    });

    return res.json({ ok: true, id: result.rows[0].id });
  } catch (e) {
    return res.status(500).json({ message: 'Failed to send help request' });
  }
});

// Super Admin: Users
app.get('/api/super-admin/users', authRequired, requireSuperAdmin, async (req, res) => {
  const { search, role, archived } = req.query || {};

  const where = [];
  const params = [];
  let i = 1;

  if (search) {
    where.push(`(email ILIKE $${i} OR full_name ILIKE $${i})`);
    params.push(`%${search}%`);
    i++;
  }

  if (role) {
    where.push(`role = $${i}`);
    params.push(role);
    i++;
  }

  if (archived !== undefined) {
    const archivedBool = archived === 'true';
    where.push(`archived = $${i}`);
    params.push(archivedBool);
    i++;
  }

  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

  const result = await pool.query(
    `SELECT id, email, full_name, role, archived
     FROM users
     ${whereSql}
     ORDER BY created_at DESC
     LIMIT 200;`,
    params,
  );

  return res.json({
    users: result.rows.map((u) => ({
      id: u.id,
      email: u.email,
      fullName: u.full_name,
      role: u.role,
      archived: u.archived,
    })),
  });
});

app.post('/api/super-admin/users', authRequired, requireSuperAdmin, async (req, res) => {
  try {
    const { email, password, fullName, role } = req.body || {};
    if (!email || !password || !fullName || !role) {
      return res.status(400).json({ message: 'email, password, fullName, role are required' });
    }

    if (!allowedRoles.has(role)) {
      return res.status(400).json({ message: 'Invalid role' });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    await pool.query(
      `INSERT INTO users (email, password_hash, full_name, role, archived)
       VALUES ($1, $2, $3, $4, FALSE);`,
      [email, passwordHash, fullName, role],
    );

    await logAction({
      userId: req.user.id,
      feature: '',
      action: 'created account',
      other: { email, role },
    });

    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ message: 'Failed to create user' });
  }
});

app.post('/api/super-admin/users/:userId', authRequired, requireSuperAdmin, async (req, res) => {
  try {
    const { userId } = req.params;
    const { fullName, role } = req.body || {};
    if (!fullName || !role) {
      return res.status(400).json({ message: 'fullName and role are required' });
    }

    if (!allowedRoles.has(role)) {
      return res.status(400).json({ message: 'Invalid role' });
    }

    await pool.query(
      `UPDATE users
       SET full_name = $1, role = $2
       WHERE id = $3;`,
      [fullName, role, userId],
    );

    await logAction({
      userId: req.user.id,
      feature: '',
      action: 'updated account',
      other: { userId, role },
    });

    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ message: 'Failed to update user' });
  }
});

app.post('/api/super-admin/users/:userId/archive', authRequired, requireSuperAdmin, async (req, res) => {
  try {
    const { userId } = req.params;
    const { archived } = req.body || {};
    const nextArchived = archived === true;

    await pool.query(
      `UPDATE users
       SET archived = $1
       WHERE id = $2;`,
      [nextArchived, userId],
    );

    await logAction({
      userId: req.user.id,
      feature: '',
      action: nextArchived ? 'archived account' : 'unarchived account',
      other: { userId, archived: nextArchived },
    });

    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ message: 'Failed to update archive status' });
  }
});

// Super Admin: Help Requests
app.get('/api/super-admin/help-requests', authRequired, requireSuperAdmin, async (req, res) => {
  const { search, status } = req.query || {};

  const where = [];
  const params = [];
  let i = 1;

  if (status && allowedHelpStatuses.has(status)) {
    where.push(`hr.status = $${i}`);
    params.push(status);
    i++;
  }

  if (search) {
    where.push(`(
      u.full_name ILIKE $${i}
      OR hr.feature ILIKE $${i}
      OR hr.problem ILIKE $${i}
      OR hr.request ILIKE $${i}
    )`);
    params.push(`%${search}%`);
    i++;
  }

  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

  const result = await pool.query(
    `SELECT
      hr.id,
      hr.user_id,
      u.full_name AS "userName",
      hr.feature,
      hr.problem,
      hr.request,
      hr.status,
      hr.created_at AS "createdAt"
     FROM help_requests hr
     JOIN users u ON u.id = hr.user_id
     ${whereSql}
     ORDER BY hr.created_at DESC
     LIMIT 500;`,
    params,
  );

  return res.json({
    helpRequests: result.rows.map((r) => ({
      id: r.id,
      userId: r.user_id,
      userName: r.userName,
      feature: r.feature,
      problem: r.problem,
      request: r.request,
      status: r.status,
      createdAt: r.createdAt.toISOString(),
    })),
  });
});

app.post('/api/super-admin/help-requests/:requestId/resolve', authRequired, requireSuperAdmin, async (req, res) => {
  const { requestId } = req.params;

  const client = await pool.connect();
  try {
    await client.query('BEGIN;');

    const hrRes = await client.query(
      `SELECT id, user_id, feature
       FROM help_requests
       WHERE id = $1;`,
      [requestId],
    );

    if (hrRes.rowCount === 0) {
      await client.query('ROLLBACK;');
      return res.status(404).json({ message: 'Help request not found' });
    }

    const hr = hrRes.rows[0];

    await client.query(
      `UPDATE help_requests
       SET status = 'resolved',
           resolved_at = now(),
           resolved_by = $1
       WHERE id = $2;`,
      [req.user.id, requestId],
    );

    // Notification to the sender
    await client.query(
      `INSERT INTO notifications (user_id, message)
       VALUES ($1, $2);`,
      [hr.user_id, 'Your concern has been resolved. Thank you!'],
    );

    // Action log for the resolver
    await logAction({
      client,
      userId: req.user.id,
      feature: hr.feature,
      action: 'resolved help request',
      other: { helpRequestId: hr.id, resolvedUserId: hr.user_id },
    });

    await client.query('COMMIT;');
    return res.json({ ok: true });
  } catch (e) {
    await client.query('ROLLBACK;');
    return res.status(500).json({ message: 'Failed to resolve help request' });
  } finally {
    client.release();
  }
});

// Super Admin: Action Logs
app.get('/api/super-admin/action-logs', authRequired, requireSuperAdmin, async (req, res) => {
  const { search } = req.query || {};

  const params = [];
  let whereSql = '';
  if (search) {
    whereSql = `WHERE (
      u.full_name ILIKE $1 OR
      al.feature ILIKE $1 OR
      al.action ILIKE $1
    )`;
    params.push(`%${search}%`);
  }

  const result = await pool.query(
    `SELECT
      al.id,
      al.user_id,
      u.full_name AS "userName",
      al.feature,
      al.action,
      al.other,
      al.created_at AS "createdAt"
     FROM action_logs al
     JOIN users u ON u.id = al.user_id
     ${whereSql}
     ORDER BY al.created_at DESC
     LIMIT 500;`,
    params,
  );

  return res.json({
    actionLogs: result.rows.map((r) => ({
      id: r.id,
      userName: r.userName,
      feature: r.feature,
      action: r.action,
      other: r.other,
      createdAt: r.createdAt.toISOString(),
    })),
  });
});

// Manager: create/list/finalize event orders
app.post(
  '/api/manager/events/orders',
  authRequired,
  (req, res, next) => requireRoles(req, res, next, new Set(['manager', 'admin'])),
  async (req, res) => {
    try {
      const {
        eventTitle,
        eventType,
        formalityLevel,
        customerName,
        contactPerson,
        contactNumber,
        emailAddress,
        scheduleSlots,
        address,
        guestCount,
        menu,
        themeDesign,
      } = req.body || {};

      if (
        !eventTitle ||
        !eventType ||
        !formalityLevel ||
        !customerName ||
        !contactPerson ||
        !contactNumber ||
        !emailAddress ||
        !address ||
        guestCount === undefined ||
        !Array.isArray(scheduleSlots) ||
        !Array.isArray(menu) ||
        !themeDesign
      ) {
        return res.status(400).json({ message: 'Missing required fields' });
      }

      const result = await pool.query(
        `INSERT INTO event_orders
          (source, status, event_title, event_type, formality_level,
           customer_name, contact_person, contact_number, email_address,
           schedule_slots, address, guest_count, menu, theme_design,
           created_by, updated_by)
         VALUES
          ('new_event', 'for_processing', $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
         RETURNING id;`,
        [
          eventTitle,
          eventType,
          formalityLevel,
          customerName,
          contactPerson,
          contactNumber,
          emailAddress,
          JSON.stringify(scheduleSlots),
          address,
          Number(guestCount),
          JSON.stringify(menu),
          JSON.stringify(themeDesign),
          req.user.id,
          req.user.id,
        ],
      );

      await logAction({
        userId: req.user.id,
        feature: 'Events',
        action: 'submitted new event',
        other: { orderId: result.rows[0].id },
      });

      return res.json({ ok: true, id: result.rows[0].id });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: 'Failed to create order' });
    }
  },
);

app.get(
  '/api/manager/events/orders',
  authRequired,
  (req, res, next) => requireRoles(req, res, next, new Set(['manager', 'admin'])),
  async (req, res) => {
    const { status } = req.query || {};
    if (!status) return res.status(400).json({ message: 'status query param is required' });

    const result = await pool.query(
      `SELECT
        id,
        source,
        status,
        event_title AS "eventTitle",
        event_type AS "eventType",
        formality_level AS "formalityLevel",
        customer_name AS "customerName",
        contact_person AS "contactPerson",
        contact_number AS "contactNumber",
        email_address AS "emailAddress",
        schedule_slots AS "scheduleSlots",
        address,
        guest_count AS "guestCount",
        menu,
        theme_design AS "themeDesign"
       FROM event_orders
       WHERE status = $1
       ORDER BY created_at DESC
       LIMIT 500;`,
      [status],
    );

    return res.json({ orders: result.rows });
  },
);

app.post(
  '/api/manager/events/orders/:orderId/finalize',
  authRequired,
  (req, res, next) => requireRoles(req, res, next, new Set(['manager', 'admin'])),
  async (req, res) => {
    try {
      const { orderId } = req.params;
      const {
        eventTitle,
        eventType,
        formalityLevel,
        customerName,
        contactPerson,
        contactNumber,
        emailAddress,
        scheduleSlots,
        address,
        guestCount,
        menu,
        themeDesign,
      } = req.body || {};

      const result = await pool.query(
        `UPDATE event_orders
         SET
           event_title = $1,
           event_type = $2,
           formality_level = $3,
           customer_name = $4,
           contact_person = $5,
           contact_number = $6,
           email_address = $7,
           schedule_slots = $8,
           address = $9,
           guest_count = $10,
           menu = $11,
           theme_design = $12,
           status = 'for_processing',
           updated_by = $13,
           updated_at = now()
         WHERE id = $14
           AND source = 'online_inquiry'
           AND status = 'online_inquiries'
         RETURNING id;`,
        [
          eventTitle,
          eventType,
          formalityLevel,
          customerName,
          contactPerson,
          contactNumber,
          emailAddress,
          JSON.stringify(scheduleSlots || []),
          address,
          Number(guestCount),
          JSON.stringify(menu || []),
          JSON.stringify(themeDesign || {}),
          req.user.id,
          orderId,
        ],
      );

      if (result.rowCount === 0) {
        return res.status(404).json({ message: 'Online inquiry not found or not finalizable' });
      }

      await logAction({
        userId: req.user.id,
        feature: 'Events',
        action: 'finalized online inquiry',
        other: { orderId },
      });

      return res.json({ ok: true, id: result.rows[0].id });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: 'Failed to finalize order' });
    }
  },
);

// Supervisor: list/update processing orders
app.get(
  '/api/supervisor/events/orders',
  authRequired,
  (req, res, next) => requireRoles(req, res, next, new Set(['supervisor', 'admin'])),
  async (req, res) => {
    const { status } = req.query || {};
    if (!status) return res.status(400).json({ message: 'status query param is required' });

    const result = await pool.query(
      `SELECT
        id,
        source,
        status,
        event_title AS "eventTitle",
        event_type AS "eventType",
        formality_level AS "formalityLevel",
        customer_name AS "customerName",
        contact_person AS "contactPerson",
        contact_number AS "contactNumber",
        email_address AS "emailAddress",
        schedule_slots AS "scheduleSlots",
        address,
        guest_count AS "guestCount",
        menu,
        theme_design AS "themeDesign"
       FROM event_orders
       WHERE status = $1
       ORDER BY created_at DESC
       LIMIT 500;`,
      [status],
    );

    return res.json({ orders: result.rows });
  },
);

app.post(
  '/api/supervisor/events/orders/:orderId',
  authRequired,
  (req, res, next) => requireRoles(req, res, next, new Set(['supervisor', 'admin'])),
  async (req, res) => {
    try {
      const { orderId } = req.params;
      const {
        eventTitle,
        eventType,
        formalityLevel,
        customerName,
        contactPerson,
        contactNumber,
        emailAddress,
        scheduleSlots,
        address,
        guestCount,
        menu,
        themeDesign,
      } = req.body || {};

      const result = await pool.query(
        `UPDATE event_orders
         SET
           event_title = $1,
           event_type = $2,
           formality_level = $3,
           customer_name = $4,
           contact_person = $5,
           contact_number = $6,
           email_address = $7,
           schedule_slots = $8,
           address = $9,
           guest_count = $10,
           menu = $11,
           theme_design = $12,
           updated_by = $13,
           updated_at = now()
         WHERE id = $14
           AND status = 'for_processing'
         RETURNING id;`,
        [
          eventTitle,
          eventType,
          formalityLevel,
          customerName,
          contactPerson,
          contactNumber,
          emailAddress,
          JSON.stringify(scheduleSlots || []),
          address,
          Number(guestCount),
          JSON.stringify(menu || []),
          JSON.stringify(themeDesign || {}),
          req.user.id,
          orderId,
        ],
      );

      if (result.rowCount === 0) {
        return res.status(404).json({ message: 'Processing order not found' });
      }

      await logAction({
        userId: req.user.id,
        feature: 'Events',
        action: 'updated for processing',
        other: { orderId },
      });

      return res.json({ ok: true, id: result.rows[0].id });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: 'Failed to update processing order' });
    }
  },
);

// Public: customer submits online inquiries
app.post('/api/public/online-inquiries', async (req, res) => {
  try {
    const {
      eventTitle,
      eventType,
      formalityLevel,
      customerName,
      contactPerson,
      contactNumber,
      emailAddress,
      scheduleSlots,
      address,
      guestCount,
      menu,
      themeDesign,
    } = req.body || {};

    if (
      !eventTitle ||
      !eventType ||
      !formalityLevel ||
      !customerName ||
      !contactPerson ||
      !contactNumber ||
      !emailAddress ||
      !address ||
      guestCount === undefined ||
      !Array.isArray(scheduleSlots) ||
      !Array.isArray(menu) ||
      !themeDesign
    ) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    const result = await pool.query(
      `INSERT INTO event_orders
        (source, status, event_title, event_type, formality_level,
         customer_name, contact_person, contact_number, email_address,
         schedule_slots, address, guest_count, menu, theme_design)
       VALUES
        ('online_inquiry', 'online_inquiries',
         $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
       RETURNING id;`,
      [
        eventTitle,
        eventType,
        formalityLevel,
        customerName,
        contactPerson,
        contactNumber,
        emailAddress,
        JSON.stringify(scheduleSlots),
        address,
        Number(guestCount),
        JSON.stringify(menu),
        JSON.stringify(themeDesign),
      ],
    );

    return res.json({ ok: true, id: result.rows[0].id });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ message: 'Failed to create online inquiry' });
  }
});

async function seedSuperAdminIfNeeded() {
  const email = process.env.SEED_SUPER_ADMIN_EMAIL;
  const password = process.env.SEED_SUPER_ADMIN_PASSWORD;
  const fullName = process.env.SEED_SUPER_ADMIN_FULL_NAME || 'Super Admin';

  if (!email || !password) return;

  const existing = await pool.query(`SELECT id FROM users WHERE email = $1 LIMIT 1;`, [email]);
  if (existing.rowCount > 0) return;

  const passwordHash = await bcrypt.hash(password, 10);
  await pool.query(
    `INSERT INTO users (email, password_hash, full_name, role, archived)
     VALUES ($1, $2, $3, 'super_admin', FALSE);`,
    [email, passwordHash, fullName],
  );
}

initDb()
  .then(() => seedSuperAdminIfNeeded())
  .then(() => {
    app.listen(PORT, () => {
      console.log(`Curatering server listening on port ${PORT}`);
    });
  })
  .catch((err) => {
    console.error('Failed to init DB/server:', err);
    process.exit(1);
  });

