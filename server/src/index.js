import "dotenv/config";
import express from "express";
import cors from "cors";
import jwt from "jsonwebtoken";
import bcrypt from "bcryptjs";
import nodemailer from "nodemailer";
import postgres from 'postgres'
import path from 'path'
import { fileURLToPath } from 'url'
import { initDb, pool, generateUserId } from "./db.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
app.use(cors());
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ limit: "50mb", extended: true }));

const PORT = process.env.PORT ? Number(process.env.PORT) : 3000;
const JWT_SECRET = process.env.JWT_SECRET || "dev-change-me";
const connectionString = process.env.DATABASE_URL
const sql = postgres(connectionString)

const allowedRoles = new Set(["admin", "manager", "supervisor", "super_admin"]);
const allowedHelpStatuses = new Set(["unresolved", "resolved"]);

function signToken({ userId, role }) {
  return jwt.sign({ role }, JWT_SECRET, {
    subject: userId,
    expiresIn: "30m",
  });
}
// OTP generation
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

//Email Transporter
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.TRANSPORTER_EMAIL,
    pass: process.env.TRANSPORTER_PASSWORD,
  },
});
// Send OTP function
async function sendOtpEmail(email, otp) {
  await transporter.sendMail({
    from: process.env.TRANSPORTER_EMAIL,
    to: email,
    subject: "Verify your Curatering account.",
    text: `Welcome to Curatering! \n If you did not request this email, please ignore this message. \n Your OTP is ${otp}. \n This OTP will expire in 10 minutes`,
  });
}

// Send Password Reset Email function
async function sendPasswordResetEmail(email, resetCode, fullName) {
  await transporter.sendMail({
    from: process.env.TRANSPORTER_EMAIL,
    to: email,
    subject: "Password Reset - Curatering",
    text: `Hello ${fullName || 'Customer'},\n\nYou requested to reset your password for your Curatering account.\n\nYour password reset code is: ${resetCode}\n\nThis code will expire in 30 minutes.\n\nIf you did not request this password reset, please ignore this email and your password will remain unchanged.\n\nBest regards,\nCuratering Team`,
  });
}

// Send Password Changed Email function
async function sendPasswordChangedEmail(email, fullName) {
  await transporter.sendMail({
    from: process.env.TRANSPORTER_EMAIL,
    to: email,
    subject: "Your Password Has Been Changed - Curatering",
    text: `Hello ${fullName || 'Customer'},\n\nYour password for your Curatering account has been successfully changed.\n\nIf you did not make this change, please contact us immediately.\n\nBest regards,\nCuratering Team`,
  });
}

function authRequired(req, res, next) {
  const header = req.headers.authorization || "";
  const [scheme, token] = header.split(" ");
  if (scheme !== "Bearer" || !token) {
    return res.status(401).json({ message: "Missing bearer token" });
  }

  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = {
      id: payload.sub,
      role: payload.role,
    };
    return next();
  } catch (e) {
    return res.status(401).json({ message: "Invalid token" });
  }
}

function requireSuperAdmin(req, res, next) {
  if (req.user?.role !== "super_admin") {
    return res.status(403).json({ message: "Super Admin only" });
  }
  return next();
}

function requireRoles(req, res, next, allowed) {
  const role = req.user?.role;
  if (role === "super_admin") return next();
  if (!allowed.has(role)) {
    return res.status(403).json({ message: "Not allowed" });
  }
  return next();
}

async function logAction({
  client,
  userId,
  feature = "",
  action,
  other = null,
}) {
  const q = client ?? pool;
  await q.query(
    `INSERT INTO action_logs (user_id, feature, action, other)
     VALUES ($1, $2, $3, $4);`,
    [userId, feature, action, other],
  );
}

app.post("/api/auth/login", async (req, res) => {
  try {
    const { email, password } = req.body || {};
    console.log("Login attempt:", { email, passwordLength: password?.length });
    
    if (!email || !password) {
      console.log("Missing email or password");
      return res
        .status(400)
        .json({ message: "email and password are required" });
    }

    const result = await pool.query(
      `SELECT id, email, full_name, role, archived, password_hash, page_permissions, is_verified
       FROM users
       WHERE email = $1
       LIMIT 1;`,
      [email],
    );

    console.log("User query result:", {
      rowCount: result.rowCount,
      userFound: result.rowCount > 0,
      email: email
    });

    if (result.rowCount === 0) {
      console.log("User not found for email:", email);
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const user = result.rows[0];
    console.log("User data:", {
      id: user.id,
      email: user.email,
      role: user.role,
      archived: user.archived,
      is_verified: user.is_verified
    });
    
    if (user.archived) {
      console.log("Account is archived");
      return res.status(401).json({ message: "Account archived" });
    }

    const ok = await bcrypt.compare(password, user.password_hash);
    console.log("Password comparison result:", ok);
    
    if (!ok) {
      console.log("Password mismatch for email:", email);
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const token = signToken({ userId: user.id, role: user.role });
    console.log("Login successful for:", email);
    
    return res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        fullName: user.full_name,
        role: user.role,
        archived: user.archived,
        isVerified: user.is_verified,
        pagePermissions: user.page_permissions || {},
      },
    });
  } catch (e) {
    console.error("Login error:", e);
    return res.status(500).json({ message: "Login failed" });
  }
});

app.get("/api/auth/me", authRequired, async (req, res) => {
  const { id } = req.user;
  const result = await pool.query(
    `SELECT id, email, full_name, role, archived, page_permissions
     FROM users
     WHERE id = $1
     LIMIT 1;`,
    [id],
  );

  if (result.rowCount === 0)
    return res.status(404).json({ message: "User not found" });
  const u = result.rows[0];
  return res.json({
    user: {
      id: u.id,
      email: u.email,
      fullName: u.full_name,
      role: u.role,
      archived: u.archived,
      pagePermissions: u.page_permissions || {},
    },
  });
});

//Help request
app.post("/api/help-requests", authRequired, async (req, res) => {
  try {
    const { feature, problem, request } = req.body || {};
    if (!feature || !problem || !request) {
      return res
        .status(400)
        .json({ message: "feature, problem, request are required" });
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
      action: "sent help request",
      other: { helpRequestId: result.rows[0].id },
    });

    return res.json({ ok: true, id: result.rows[0].id });
  } catch (e) {
    return res.status(500).json({ message: "Failed to send help request" });
  }
});

// Super Admin: Users
app.get(
  "/api/super-admin/users",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
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
      const archivedBool = archived === "true";
      where.push(`archived = $${i}`);
      params.push(archivedBool);
      i++;
    }

    const whereSql = where.length ? `WHERE ${where.join(" AND ")}` : "";

    const result = await pool.query(
      `SELECT id, email, full_name, role, archived, page_permissions
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
        pagePermissions: u.page_permissions || {},
      })),
    });
  },
);

//create account
app.post("/api/super-admin/users", authRequired, requireSuperAdmin, async (req, res) => {
    try {
      const { email, password, fullName, role } = req.body || {};

      if (!email || !password || !fullName || !role) {
        return res
          .status(400)
          .json({ message: "email, password, fullName, role are required" });
      }

      if (!allowedRoles.has(role)) {
        return res.status(400).json({ message: "Invalid role" });
      }

      const passwordHash = await bcrypt.hash(password, 10);
      const otp = generateOTP();
      const expiry = new Date(Date.now() + 10 * 60 * 1000); // 10 mins
      const existing = await pool.query(
        `SELECT id FROM users WHERE email = $1`,
        [email]
      );

      if (existing.rows.length > 0) {
        return res.status(400).json({ message: "Email already exists" });
      }
      
      const userId = generateUserId();
      await pool.query(
        `INSERT INTO users 
        (id, email, password_hash, full_name, role, archived, is_verified, otp_code, otp_expiry)
       VALUES ($1, $2, $3, $4, $5, FALSE, FALSE, $6, $7);`,
        [userId, email, passwordHash, fullName, role, otp, expiry],
      );

      await sendOtpEmail(email, otp);

      await logAction({
        userId: req.user.id,
        feature: "",
        action: "created account (OTP sent)",
        other: { email, role },
      });

      return res.json({
        ok: true,
        message: "User created. OTP sent to email.",
      });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: "Failed to create user" });
    }
  },
);

//verify email
app.post("/api/auth/verify-otp", async (req, res) => {
  try {
    const { email, otp } = req.body;

    const result = await pool.query(`SELECT * FROM users WHERE email = $1`, [
      email,
    ]);

    if (result.rows.length === 0) {
      return res.status(404).json({ message: "User not found" });
    }

    const user = result.rows[0];

    if (user.otp_code !== otp) {
      return res.status(400).json({ message: "Invalid OTP" });
    }

    if (new Date() > user.otp_expiry) {
      return res.status(400).json({ message: "OTP expired" });
    }

    await pool.query(
      `UPDATE users 
       SET is_verified = TRUE, otp_code = NULL, otp_expiry = NULL
       WHERE email = $1`,
      [email],
    );

    return res.json({ message: "Account verified successfully" });
  } catch (e) {
    return res.status(500).json({ message: "Verification failed" });
  }
});

app.post(
  "/api/super-admin/users/:userId",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
    try {
      const { userId } = req.params;
      const { fullName, role } = req.body || {};
      if (!fullName || !role) {
        return res
          .status(400)
          .json({ message: "fullName and role are required" });
      }

      if (!allowedRoles.has(role)) {
        return res.status(400).json({ message: "Invalid role" });
      }

      await pool.query(
        `UPDATE users
       SET full_name = $1, role = $2
       WHERE id = $3;`,
        [fullName, role, userId],
      );

      await logAction({
        userId: req.user.id,
        feature: "",
        action: "updated account",
        other: { userId, role },
      });

      return res.json({ ok: true });
    } catch (e) {
      return res.status(500).json({ message: "Failed to update user" });
    }
  },
);

app.post(
  "/api/super-admin/users/:userId/page-permissions",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
    try {
      const { userId } = req.params;
      const { pagePermissions } = req.body || {};
      if (!pagePermissions || typeof pagePermissions !== "object") {
        return res
          .status(400)
          .json({ message: "pagePermissions object is required" });
      }

      await pool.query(
        `UPDATE users SET page_permissions = $1::jsonb WHERE id = $2;`,
        [JSON.stringify(pagePermissions), userId],
      );

      await logAction({
        userId: req.user.id,
        feature: "",
        action: "updated page permissions",
        other: { userId },
      });

      return res.json({ ok: true });
    } catch (e) {
      return res
        .status(500)
        .json({ message: "Failed to update page permissions" });
    }
  },
);

app.post(
  "/api/super-admin/users/:userId/archive",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
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
        feature: "",
        action: nextArchived ? "archived account" : "unarchived account",
        other: { userId, archived: nextArchived },
      });

      return res.json({ ok: true });
    } catch (e) {
      return res
        .status(500)
        .json({ message: "Failed to update archive status" });
    }
  },
);

// Super Admin: Help Requests
app.get(
  "/api/super-admin/help-requests",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
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

    const whereSql = where.length ? `WHERE ${where.join(" AND ")}` : "";

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
  },
);

app.post(
  "/api/super-admin/help-requests/:requestId/resolve",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
    const { requestId } = req.params;

    const client = await pool.connect();
    try {
      await client.query("BEGIN;");

      const hrRes = await client.query(
        `SELECT id, user_id, feature
       FROM help_requests
       WHERE id = $1;`,
        [requestId],
      );

      if (hrRes.rowCount === 0) {
        await client.query("ROLLBACK;");
        return res.status(404).json({ message: "Help request not found" });
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
        [hr.user_id, "Your concern has been resolved. Thank you!"],
      );

      // Action log for the resolver
      await logAction({
        client,
        userId: req.user.id,
        feature: hr.feature,
        action: "resolved help request",
        other: { helpRequestId: hr.id, resolvedUserId: hr.user_id },
      });

      await client.query("COMMIT;");
      return res.json({ ok: true });
    } catch (e) {
      await client.query("ROLLBACK;");
      return res
        .status(500)
        .json({ message: "Failed to resolve help request" });
    } finally {
      client.release();
    }
  },
);

// Super Admin: Action Logs
app.get(
  "/api/super-admin/action-logs",
  authRequired,
  requireSuperAdmin,
  async (req, res) => {
    const { search } = req.query || {};

    const params = [];
    let whereSql = "";
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
  },
);

// Manager: create/list/finalize event orders
app.post(
  "/api/manager/events/orders",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "admin"])),
  async (req, res) => {
    try {
      const {
        eventTitle,
        orderType,
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

      // For catering-only orders, event-specific fields are optional
      const isCateringOnly = orderType === 'catering';
      
      if (
        !orderType ||
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
        return res.status(400).json({ message: "Missing required fields" });
      }

      // For catering+event orders, require event-specific fields
      if (!isCateringOnly && (!eventTitle || !eventType || !formalityLevel)) {
        return res.status(400).json({ message: "Missing required event fields" });
      }

      let result;
      
      if (isCateringOnly) {
        // Use separate catering_orders table for catering-only orders
        result = await pool.query(
          `INSERT INTO catering_orders
            (source, status, order_type, customer_name, contact_person, contact_number, email_address,
             schedule_slots, address, guest_count, menu, theme_design, created_by, updated_by)
          VALUES
            ('new_event', 'for_processing', 'catering', $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
           RETURNING id;`,
          [
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
          ]
        );
      } else {
        // Use event_orders table for catering+event orders
        result = await pool.query(
          `INSERT INTO event_orders
            (source, status, event_title, order_type, event_type, formality_level,
             customer_name, contact_person, contact_number, email_address,
             schedule_slots, address, guest_count, menu, theme_design,
             created_by, updated_by)
           VALUES
            ('new_event', 'for_processing', $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
           RETURNING id;`,
          [
            eventTitle,
            orderType,
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
          ]
        );
      }

      await logAction({
        userId: req.user.id,
        feature: "Events",
        action: "submitted new event",
        other: { orderId: result.rows[0].id },
      });

      return res.json({ ok: true, id: result.rows[0].id });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: "Failed to create order" });
    }
  },
);

app.get(
  "/api/manager/events/orders",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "admin"])),
  async (req, res) => {
    const { status } = req.query || {};
    if (!status)
      return res
        .status(400)
        .json({ message: "status query param is required" });

    const result = await pool.query(
      `SELECT
        id,
        source,
        status,
        null AS "eventTitle",
        'catering' AS "eventType",
        null AS "formalityLevel",
        customer_name AS "customerName",
        contact_person AS "contactPerson",
        contact_number AS "contactNumber",
        email_address AS "emailAddress",
        schedule_slots AS "scheduleSlots",
        address,
        guest_count AS "guestCount",
        menu,
        theme_design AS "themeDesign",
        post_analysis AS "postAnalysis",
        created_at
       FROM catering_orders
       WHERE status = $1 OR (status = 'cancelled' AND $1 = 'completed')
       UNION ALL
       SELECT
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
        theme_design AS "themeDesign",
        post_analysis AS "postAnalysis",
        created_at
       FROM event_orders
       WHERE status = $1 OR (status = 'cancelled' AND $1 = 'completed')
       ORDER BY created_at DESC
       LIMIT 500;`,
      [status],
    );

    return res.json({ orders: result.rows });
  },
);

app.post(
  "/api/manager/events/orders/:orderId/finalize",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "admin"])),
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
        return res
          .status(404)
          .json({ message: "Online inquiry not found or not finalizable" });
      }

      await logAction({
        userId: req.user.id,
        feature: "Events",
        action: "finalized online inquiry",
        other: { orderId },
      });

      return res.json({ ok: true, id: result.rows[0].id });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: "Failed to finalize order" });
    }
  },
);

// Supervisor: list/update processing orders
app.get(
  "/api/supervisor/events/orders",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["supervisor", "admin"])),
  async (req, res) => {
    const { status } = req.query || {};
    if (!status)
      return res
        .status(400)
        .json({ message: "status query param is required" });

    const result = await pool.query(
      `SELECT
        id,
        source,
        status,
        null AS "eventTitle",
        'catering' AS "eventType",
        null AS "formalityLevel",
        customer_name AS "customerName",
        contact_person AS "contactPerson",
        contact_number AS "contactNumber",
        email_address AS "emailAddress",
        schedule_slots AS "scheduleSlots",
        address,
        guest_count AS "guestCount",
        menu,
        theme_design AS "themeDesign",
        post_analysis AS "postAnalysis",
        created_at
       FROM catering_orders
       WHERE status = $1 OR (status = 'cancelled' AND $1 = 'completed')
       UNION ALL
       SELECT
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
        theme_design AS "themeDesign",
        post_analysis AS "postAnalysis",
        created_at
       FROM event_orders
       WHERE status = $1 OR (status = 'cancelled' AND $1 = 'completed')
       ORDER BY created_at DESC
       LIMIT 500;`,
      [status],
    );

    return res.json({ orders: result.rows });
  },
);

app.post(
  "/api/events/orders/:orderId/complete-post-analysis",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "supervisor", "admin"])),
  async (req, res) => {
    try {
      const { orderId } = req.params;
      const { businessCardsGivenAway, onTheSpotInquiries, complaints } =
        req.body || {};

      const postAnalysis = {
        businessCardsGivenAway: Number(businessCardsGivenAway) || 0,
        onTheSpotInquiries: Number(onTheSpotInquiries) || 0,
        complaints: Number(complaints) || 0,
      };

      const result = await pool.query(
        `UPDATE event_orders
         SET
           status = 'completed',
           post_analysis = $1::jsonb,
           updated_by = $2,
           updated_at = now()
         WHERE id = $3
           AND status = 'for_post_analysis'
         RETURNING id;`,
        [JSON.stringify(postAnalysis), req.user.id, orderId],
      );

      if (result.rowCount === 0) {
        return res
          .status(404)
          .json({
            message: "Post-analysis order not found or already completed",
          });
      }

      await logAction({
        userId: req.user.id,
        feature: "Events",
        action: "completed post-event analysis",
        other: { orderId, postAnalysis },
      });

      return res.json({ ok: true, id: result.rows[0].id });
    } catch (e) {
      console.error(e);
      return res
        .status(500)
        .json({ message: "Failed to complete post-analysis" });
    }
  },
);

app.post(
  "/api/supervisor/events/orders/:orderId",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["supervisor", "admin"])),
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
        return res.status(404).json({ message: "Processing order not found" });
      }

      await logAction({
        userId: req.user.id,
        feature: "Events",
        action: "updated for processing",
        other: { orderId },
      });

      return res.json({ ok: true, id: result.rows[0].id });
    } catch (e) {
      console.error(e);
      return res
        .status(500)
        .json({ message: "Failed to update processing order" });
    }
  },
);

// Public: customer submits online inquiries
app.post("/api/public/online-inquiries", async (req, res) => {
  try {
    const {
      orderType,
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

    const isCateringOnly = orderType === 'catering';

    // Validate required fields
    if (
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
      return res.status(400).json({ message: "Missing required fields" });
    }

    // Only validate event-specific fields for catering+event
    if (!isCateringOnly) {
      if (!eventTitle || !eventType || !formalityLevel) {
        return res.status(400).json({ message: "Missing required event fields" });
      }
    }

    let result;
    if (isCateringOnly) {
      // Use catering_orders table for catering-only orders
      result = await pool.query(
        `INSERT INTO catering_orders
          (source, status, order_type, customer_name, contact_person, contact_number, email_address,
           schedule_slots, address, guest_count, menu, theme_design)
        VALUES
          ('online_inquiry', 'online_inquiries', 'catering', $1, $2, $3, $4, $5, $6, $7, $8, $9)
         RETURNING id;`,
        [
          customerName,
          contactPerson,
          contactNumber,
          emailAddress,
          JSON.stringify(scheduleSlots),
          address,
          Number(guestCount),
          JSON.stringify(menu),
          JSON.stringify(themeDesign),
        ]
      );
    } else {
      // Use event_orders table for catering+event orders
      result = await pool.query(
        `INSERT INTO event_orders
          (source, status, event_title, order_type, event_type, formality_level,
           customer_name, contact_person, contact_number, email_address,
           schedule_slots, address, guest_count, menu, theme_design)
         VALUES
          ('online_inquiry', 'online_inquiries',
           $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
         RETURNING id;`,
        [
          eventTitle,
          'catering_event',
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
        ]
      );
    }

    return res.json({ ok: true, id: result.rows[0].id });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ message: "Failed to create online inquiry" });
  }
});

// Debug endpoint to check test account
app.get("/api/debug/test-account", async (req, res) => {
  try {
    const testEmail = "admin@curatering.test";
    const result = await pool.query(
      `SELECT id, email, full_name, role, is_verified, archived
       FROM users
       WHERE email = $1`,
      [testEmail]
    );
    
    if (result.rowCount === 0) {
      return res.json({ 
        message: "Test account not found",
        email: testEmail 
      });
    }
    
    const user = result.rows[0];
    return res.json({ 
      message: "Test account found",
      user: {
        id: user.id,
        email: user.email,
        fullName: user.full_name,
        role: user.role,
        isVerified: user.is_verified,
        archived: user.archived
      }
    });
  } catch (e) {
    return res.status(500).json({ message: "Failed to check test account" });
  }
});

// Debug endpoint to list users (development only)
app.get("/api/debug/users", async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, email, full_name, role, is_verified, archived
       FROM users
       ORDER BY created_at DESC
       LIMIT 10;`
    );
    return res.json({ users: result.rows });
  } catch (e) {
    return res.status(500).json({ message: "Failed to fetch users" });
  }
});

// Accept an order (move to post-analysis)
app.post(
  "/api/events/orders/:orderId/accept",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "supervisor", "admin"])),
  async (req, res) => {
    try {
      const { orderId } = req.params;

      const result = await pool.query(
        `UPDATE event_orders
         SET
           status = 'for_post_analysis',
           updated_by = $1,
           updated_at = now()
         WHERE id = $2
           AND status = 'for_processing'
         RETURNING id;`,
        [req.user.id, orderId],
      );

      if (result.rowCount === 0) {
        return res
          .status(404)
          .json({ message: "Processing order not found or already completed" });
      }

      await logAction({
        userId: req.user.id,
        feature: "Events",
        action: "accepted order",
        other: { orderId },
      });

      return res.json({ ok: true, id: result.rows[0].id });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: "Failed to accept order" });
    }
  },
);

// Cancel an order
app.post(
  "/api/events/orders/:orderId/cancel",
  authRequired,
  (req, res, next) =>
    requireRoles(req, res, next, new Set(["manager", "supervisor", "admin"])),
  async (req, res) => {
    try {
      const { orderId } = req.params;

      // First try event_orders table
      let result = await pool.query(
        `UPDATE event_orders
         SET
           status = 'cancelled',
           updated_by = $1,
           updated_at = now()
         WHERE id = $2
           AND status IN ('for_processing', 'online_inquiries', 'new_event')
         RETURNING id;`,
        [req.user.id, orderId],
      );

      // If no rows affected, try catering_orders table
      if (result.rowCount === 0) {
        result = await pool.query(
          `UPDATE catering_orders
           SET
             status = 'cancelled',
             updated_by = $1,
             updated_at = now()
           WHERE id = $2
             AND status IN ('for_processing', 'new_event')
           RETURNING id;`,
          [req.user.id, orderId],
        );
      }

      if (result.rowCount === 0) {
        return res
          .status(404)
          .json({ message: "Order not found or cannot be cancelled" });
      }

      await logAction({
        userId: req.user.id,
        feature: "Events",
        action: "cancelled order",
        other: { orderId },
      });

      return res.json({ ok: true, id: result.rows[0].id });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: "Failed to cancel order" });
    }
  },
);

async function seedSuperAdminIfNeeded() {
  const email = process.env.SEED_SUPER_ADMIN_EMAIL;
  const password = process.env.SEED_SUPER_ADMIN_PASSWORD;
  const fullName = process.env.SEED_SUPER_ADMIN_FULL_NAME || "Super Admin";

  if (!email || !password) {
    // Create default test super admin for development
    const testEmail = "admin@curatering.test";
    const testPassword = "admin123";
    const testFullName = "Test Super Admin";
    const existing = await pool.query(
      `SELECT id FROM users WHERE email = $1 LIMIT 1;`,
      [testEmail],
    );
    
    if (existing.rowCount === 0) {
      const passwordHash = await bcrypt.hash(testPassword, 10);
      const userId = generateUserId();
      await pool.query(
        `INSERT INTO users (id, email, password_hash, full_name, role, archived, is_verified)
         VALUES ($1, $2, $3, $4, 'super_admin', FALSE, TRUE);`,
        [userId, testEmail, passwordHash, testFullName],
      );
    } else {}
    return;
  }

  const existing = await pool.query(
    `SELECT id FROM users WHERE email = $1 LIMIT 1;`,
    [email],
  );
  if (existing.rowCount > 0) return;

  const passwordHash = await bcrypt.hash(password, 10);
  const userId = generateUserId();
  await pool.query(
    `INSERT INTO users (id, email, password_hash, full_name, role, archived)
     VALUES ($1, $2, $3, $4, 'super_admin', FALSE);`,
    [userId, email, passwordHash, fullName],
  );
}

initDb()
  .then(() => seedSuperAdminIfNeeded())
  .then(async () => {
    // Checklist CRUD operations
    app.put('/api/events/orders/:orderId/checklist/:itemId', authRequired, async (req, res) => {
      try {
        const { orderId, itemId } = req.params;
        const { isCompleted, title, description, price, assignedTo } = req.body;
        
        // Determine which table to use
        const orderResult = await pool.query(
          'SELECT id FROM event_orders WHERE id = $1 UNION ALL SELECT id FROM catering_orders WHERE id = $1 LIMIT 1',
          [orderId]
        );
        
        if (orderResult.rows.length === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }
        
        // Update checklist item
        const result = await pool.query(
          `UPDATE event_orders 
           SET checklist = jsonb_set(
             checklist,
             array(
               (SELECT idx FROM jsonb_array_elements(checklist) WITH ORDINALITY arr(elem, idx) 
                WHERE elem->>'id' = $2)::int - 1
             ),
             $3::jsonb,
             true
           )
           WHERE id = $1
           RETURNING checklist`,
          [orderId, itemId, JSON.stringify({ id: itemId, title, description, price, assignedTo, isCompleted })]
        );
        
        if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Checklist item not found' });
        }
        
        res.json({ checklist: result.rows[0].checklist });
      } catch (error) {
        console.error('Error updating checklist item:', error);
        res.status(500).json({ error: 'Failed to update checklist item' });
      }
    });

    app.post('/api/events/orders/:orderId/checklist', authRequired, async (req, res) => {
      try {
        const { orderId } = req.params;
        const item = req.body;
        
        // Determine which table to use
        const orderResult = await pool.query(
          'SELECT id FROM event_orders WHERE id = $1 UNION ALL SELECT id FROM catering_orders WHERE id = $1 LIMIT 1',
          [orderId]
        );
        
        if (orderResult.rows.length === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }
        
        // Add checklist item
        const result = await pool.query(
          'UPDATE event_orders SET checklist = checklist || $1::jsonb WHERE id = $2 RETURNING checklist',
          [JSON.stringify(item), orderId]
        );
        
        res.json({ checklist: result.rows[0].checklist });
      } catch (error) {
        console.error('Error adding checklist item:', error);
        res.status(500).json({ error: 'Failed to add checklist item' });
      }
    });

    app.delete('/api/events/orders/:orderId/checklist/:itemId', authRequired, async (req, res) => {
      try {
        const { orderId, itemId } = req.params;
        
        // Determine which table to use
        const orderResult = await pool.query(
          'SELECT id FROM event_orders WHERE id = $1 UNION ALL SELECT id FROM catering_orders WHERE id = $1 LIMIT 1',
          [orderId]
        );
        
        if (orderResult.rows.length === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }
        
        // Remove checklist item
        const result = await pool.query(
          `UPDATE event_orders 
           SET checklist = (
             SELECT jsonb_agg(elem) 
             FROM jsonb_array_elements(checklist) elem 
             WHERE elem->>'id' != $1
           )
           WHERE id = $2
           RETURNING checklist`,
          [itemId, orderId]
        );
        
        res.json({ checklist: result.rows[0].checklist });
      } catch (error) {
        console.error('Error deleting checklist item:', error);
        res.status(500).json({ error: 'Failed to delete checklist item' });
      }
    });

    
// Loyalty Rewards API endpoints
    app.get('/api/loyalty/user-points', authRequired, async (req, res) => {
      try {
        const userId = req.user.id;
        
        // Calculate user points from completed orders
        const ordersResult = await pool.query(
          `SELECT 
             COUNT(*) as total_orders,
             COALESCE(SUM(total_cost), 0) as total_spent
           FROM (
             SELECT total_cost FROM event_orders 
             WHERE customer_id = $1 AND final_status = 'successful'
             UNION ALL
             SELECT total_cost FROM catering_orders 
             WHERE customer_id = $1 AND final_status = 'successful'
           ) orders`,
          [userId]
        );
        
        const { total_orders, total_spent } = ordersResult.rows[0];
        const points = Math.floor(total_spent * 0.1); // 10% of total spent
        
        // Get redeemed rewards
        const redeemedResult = await pool.query(
          'SELECT * FROM user_rewards WHERE user_id = $1 AND redeemed = true',
          [userId]
        );
        
        res.json({
          userPoints: points,
          totalOrders: parseInt(total_orders),
          totalSpent: parseFloat(total_spent),
          redeemedRewards: redeemedResult.rows,
        });
      } catch (error) {
        console.error('Error fetching user points:', error);
        res.status(500).json({ error: 'Failed to fetch user points' });
      }
    });

    app.get('/api/loyalty/rewards', authRequired, async (req, res) => {
      try {
        const result = await pool.query(
          'SELECT * FROM rewards WHERE active = true ORDER BY points_cost ASC'
        );
        
        res.json({ rewards: result.rows });
      } catch (error) {
        console.error('Error fetching rewards:', error);
        res.status(500).json({ error: 'Failed to fetch rewards' });
      }
    });

    app.post('/api/loyalty/redeem', authRequired, async (req, res) => {
      try {
        const { rewardId } = req.body;
        const userId = req.user.id;
        
        // Get reward details
        const rewardResult = await pool.query(
          'SELECT * FROM rewards WHERE id = $1 AND active = true',
          [rewardId]
        );
        
        if (rewardResult.rows.length === 0) {
          return res.status(404).json({ error: 'Reward not found' });
        }
        
        const reward = rewardResult.rows[0];
        
        // Calculate user points
        const pointsResult = await pool.query(
          `SELECT COALESCE(SUM(total_cost), 0) as total_spent
           FROM (
             SELECT total_cost FROM event_orders 
             WHERE customer_id = $1 AND final_status = 'successful'
             UNION ALL
             SELECT total_cost FROM catering_orders 
             WHERE customer_id = $1 AND final_status = 'successful'
           ) orders`,
          [userId]
        );
        
        const userPoints = Math.floor(pointsResult.rows[0].total_spent * 0.1);
        
        if (userPoints < reward.points_cost) {
          return res.status(400).json({ error: 'Insufficient points' });
        }
        
        // Check if already redeemed
        const existingResult = await pool.query(
          'SELECT * FROM user_rewards WHERE user_id = $1 AND reward_id = $2',
          [userId, rewardId]
        );
        
        if (existingResult.rows.length > 0) {
          return res.status(400).json({ error: 'Reward already redeemed' });
        }
        
        // Create redemption record
        await pool.query(
          `INSERT INTO user_rewards (user_id, reward_id, redeemed_at, points_used)
           VALUES ($1, $2, NOW(), $3)`,
          [userId, rewardId, reward.points_cost]
        );
        
        res.json({ 
          message: 'Reward redeemed successfully',
          pointsUsed: reward.points_cost,
          remainingPoints: userPoints - reward.points_cost
        });
      } catch (error) {
        console.error('Error redeeming reward:', error);
        res.status(500).json({ error: 'Failed to redeem reward' });
      }
    });

    app.get('/api/loyalty/user-rewards', authRequired, async (req, res) => {
      try {
        const userId = req.user.id;
        
        const result = await pool.query(
          `SELECT ur.*, r.title, r.description, r.category, r.points_cost
           FROM user_rewards ur
           JOIN rewards r ON ur.reward_id = r.id
           WHERE ur.user_id = $1
           ORDER BY ur.redeemed_at DESC`,
          [userId]
        );
        
        res.json({ rewards: result.rows });
      } catch (error) {
        console.error('Error fetching user rewards:', error);
        res.status(500).json({ error: 'Failed to fetch user rewards' });
      }
    });

    // Menu Dishes API endpoints
    // Public endpoint - only returns active (non-archived) dishes
    app.get('/api/menu/dishes', async (req, res) => {
      try {
        const result = await pool.query(
          `SELECT id, name, price, category, pax_options, sauces, ingredients,
                  image_base64, archived, archived_at, created_at, updated_at, type, set_menus
           FROM menu_dishes
           WHERE archived = false
           ORDER BY category, name`
        );
        res.json({ dishes: result.rows });
      } catch (error) {
        console.error('Error fetching menu dishes:', error);
        res.status(500).json({ error: 'Failed to fetch menu dishes' });
      }
    });

    // Protected endpoint - returns all dishes including archived (for admin)
    app.get('/api/menu/dishes/all', authRequired, async (req, res) => {
      try {
        const result = await pool.query(
          `SELECT id, name, price, category, pax_options, sauces, ingredients,
                  image_base64, archived, archived_at, created_at, updated_at, type, set_menus
           FROM menu_dishes
           ORDER BY category, name`
        );
        res.json({ dishes: result.rows });
      } catch (error) {
        console.error('Error fetching all menu dishes:', error);
        res.status(500).json({ error: 'Failed to fetch menu dishes' });
      }
    });

    app.post('/api/menu/dishes', authRequired, async (req, res) => {
      try {
        const { name, price, category, paxOptions, sauces, ingredients, imageBase64, type } = req.body || {};
        
        if (!name || !price) {
          return res.status(400).json({ error: 'Name and price are required' });
        }

        const result = await pool.query(
          `INSERT INTO menu_dishes (name, price, category, pax_options, sauces, ingredients, image_base64, type, set_menus)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
           RETURNING *`,
          [name, price, category || 'catering', JSON.stringify(paxOptions || []), JSON.stringify(sauces || []), JSON.stringify(ingredients || []), imageBase64 || null, type || '', JSON.stringify([])]
        );
        
        res.status(201).json({ dish: result.rows[0] });
      } catch (error) {
        console.error('Error creating menu dish:', error);
        res.status(500).json({ error: 'Failed to create menu dish' });
      }
    });

    app.put('/api/menu/dishes/:dishId', authRequired, async (req, res) => {
      try {
        const { dishId } = req.params;
        const { name, price, category, paxOptions, sauces, ingredients, imageBase64, type } = req.body || {};
        
        const result = await pool.query(
          `UPDATE menu_dishes
           SET name = $1, price = $2, category = $3, pax_options = $4, 
               sauces = $5, ingredients = $6, image_base64 = $7, type = $8, set_menus = $9, updated_at = now()
           WHERE id = $10
           RETURNING *`,
          [name, price, category, JSON.stringify(paxOptions), JSON.stringify(sauces), JSON.stringify(ingredients), imageBase64, type, JSON.stringify(req.body.setMenus || []), dishId]
        );
        
        if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Dish not found' });
        }
        
        res.json({ dish: result.rows[0] });
      } catch (error) {
        console.error('Error updating menu dish:', error);
        res.status(500).json({ error: 'Failed to update menu dish' });
      }
    });

    app.post('/api/menu/dishes/:dishId/archive', authRequired, async (req, res) => {
      try {
        const { dishId } = req.params;
        const { archived } = req.body || {};
        
        const result = await pool.query(
          `UPDATE menu_dishes
           SET archived = $1, archived_at = CASE WHEN $1 THEN now() ELSE null END, updated_at = now()
           WHERE id = $2
           RETURNING *`,
          [archived, dishId]
        );
        
        if (result.rowCount === 0) {
          return res.status(404).json({ error: 'Dish not found' });
        }
        
        res.json({ dish: result.rows[0] });
      } catch (error) {
        console.error('Error archiving menu dish:', error);
        res.status(500).json({ error: 'Failed to archive menu dish' });
      }
    });

    // Set Menus API endpoints
    app.get('/api/set-menus', authRequired, async (req, res) => {
      try {
        const result = await pool.query(
          `SELECT id, name, dish_ids, archived, created_at 
           FROM set_menus 
           WHERE archived = FALSE 
           ORDER BY name`
        );

        res.json({ setMenus: result.rows });
      } catch (error) {
        console.error('Error fetching set menus:', error);
        res.status(500).json({ error: 'Failed to fetch set menus' });
      }
    });

    app.post('/api/set-menus', authRequired, async (req, res) => {
      try {
        const { name, dishIds } = req.body || {};
        
        if (!name || !dishIds || !Array.isArray(dishIds)) {
          return res.status(400).json({ error: 'Name and dishIds array are required' });
        }

        // Check for duplicate name
        const existingResult = await pool.query(
          'SELECT id FROM set_menus WHERE LOWER(name) = LOWER($1) AND archived = FALSE',
          [name]
        );
        
        if (existingResult.rows.length > 0) {
          return res.status(400).json({ error: 'A set menu with this name already exists' });
        }

        const result = await pool.query(
          `INSERT INTO set_menus (name, dish_ids, archived, created_at, updated_at)
           VALUES ($1, $2, FALSE, now(), now())
           RETURNING *`,
          [name, dishIds]
        );

        res.status(201).json({ setMenu: result.rows[0] });
      } catch (error) {
        console.error('Error creating set menu:', error);
        res.status(500).json({ error: 'Failed to create set menu' });
      }
    });

    app.put('/api/set-menus/:setMenuId', authRequired, async (req, res) => {
      try {
        const { setMenuId } = req.params;
        const { name, dishIds } = req.body || {};
        
        if (!name || !dishIds || !Array.isArray(dishIds)) {
          return res.status(400).json({ error: 'Name and dishIds array are required' });
        }

        // Check for duplicate name (excluding current set menu)
        const existingResult = await pool.query(
          'SELECT id FROM set_menus WHERE LOWER(name) = LOWER($1) AND id != $2 AND archived = FALSE',
          [name, setMenuId]
        );
        
        if (existingResult.rows.length > 0) {
          return res.status(400).json({ error: 'A set menu with this name already exists' });
        }

        const result = await pool.query(
          `UPDATE set_menus
           SET name = $1, dish_ids = $2, updated_at = now()
           WHERE id = $3 AND archived = FALSE
           RETURNING *`,
          [name, dishIds, setMenuId]
        );

        if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Set menu not found' });
        }

        res.json({ setMenu: result.rows[0] });
      } catch (error) {
        console.error('Error updating set menu:', error);
        res.status(500).json({ error: 'Failed to update set menu' });
      }
    });

    app.post('/api/set-menus/:setMenuId/archive', authRequired, async (req, res) => {
      try {
        const { setMenuId } = req.params;
        const { archived } = req.body || {};

        const result = await pool.query(
          `UPDATE set_menus
           SET archived = $1, updated_at = now()
           WHERE id = $2
           RETURNING *`,
          [archived, setMenuId]
        );

        if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Set menu not found' });
        }

        res.json({ setMenu: result.rows[0] });
      } catch (error) {
        console.error('Error archiving set menu:', error);
        res.status(500).json({ error: 'Failed to archive set menu' });
      }
    });

    // Customer Authentication endpoints
    app.post('/api/customer/signup', async (req, res) => {
      try {
        const { email, password, fullName, phone } = req.body || {};
        
        if (!email || !password || !fullName) {
          return res.status(400).json({ error: 'Email, password, and full name are required' });
        }

        // Check if customer already exists
        const existingCustomer = await pool.query(
          'SELECT id FROM customer_accounts WHERE email = $1',
          [email.toLowerCase()]
        );
        
        console.log('Existing customer check:', { found: existingCustomer.rows.length > 0, count: existingCustomer.rows.length });
        
        if (existingCustomer.rows.length > 0) {
          console.log('Rejecting signup: Email already registered -', email.toLowerCase());
          return res.status(400).json({ error: 'Email already registered' });
        }

        const passwordHash = await bcrypt.hash(password, 10);
        const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
        const otpExpiry = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

        const result = await pool.query(
          `INSERT INTO customer_accounts (email, password_hash, full_name, phone, otp_code, otp_expiry)
           VALUES ($1, $2, $3, $4, $5, $6)
           RETURNING id, email, full_name, is_verified`,
          [email.toLowerCase(), passwordHash, fullName, phone || null, otpCode, otpExpiry]
        );

        // Send OTP email
        try {
          await sendOtpEmail(email, otpCode);
        } catch (emailError) {
          console.error('Failed to send OTP email:', emailError);
          // Still return success since account was created, but log the email error
        }

        res.status(201).json({ 
          customer: result.rows[0],
          message: 'Account created. Please verify your email with the OTP sent.'
        });
      } catch (error) {
        console.error('Error signing up customer:', error);
        res.status(500).json({ error: 'Failed to create account' });
      }
    });

    app.post('/api/customer/verify-otp', async (req, res) => {
      try {
        const { email, otpCode } = req.body || {};
        
        if (!email || !otpCode) {
          return res.status(400).json({ error: 'Email and OTP code are required' });
        }

        const result = await pool.query(
          `SELECT id, otp_expiry FROM customer_accounts 
           WHERE email = $1 AND otp_code = $2 AND is_verified = FALSE`,
          [email.toLowerCase(), otpCode]
        );

        if (result.rows.length === 0) {
          return res.status(400).json({ error: 'Invalid OTP or email' });
        }

        if (new Date() > result.rows[0].otp_expiry) {
          return res.status(400).json({ error: 'OTP has expired' });
        }

        await pool.query(
          `UPDATE customer_accounts 
           SET is_verified = TRUE, otp_code = NULL, otp_expiry = NULL 
           WHERE id = $1`,
          [result.rows[0].id]
        );

        res.json({ message: 'Email verified successfully' });
      } catch (error) {
        console.error('Error verifying OTP:', error);
        res.status(500).json({ error: 'Failed to verify OTP' });
      }
    });

    app.post('/api/customer/login', async (req, res) => {
      try {
        const { email, password } = req.body || {};
        
        if (!email || !password) {
          return res.status(400).json({ error: 'Email and password are required' });
        }

        const result = await pool.query(
          'SELECT * FROM customer_accounts WHERE email = $1 AND archived = FALSE',
          [email.toLowerCase()]
        );

        if (result.rows.length === 0) {
          return res.status(401).json({ error: 'Invalid email or password' });
        }

        const customer = result.rows[0];
        const isValidPassword = await bcrypt.compare(password, customer.password_hash);

        if (!isValidPassword) {
          return res.status(401).json({ error: 'Invalid email or password' });
        }

        if (!customer.is_verified) {
          // Resend OTP
          const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
          const otpExpiry = new Date(Date.now() + 10 * 60 * 1000);
          
          await pool.query(
            `UPDATE customer_accounts 
             SET otp_code = $1, otp_expiry = $2 
             WHERE id = $3`,
            [otpCode, otpExpiry, customer.id]
          );
          
          // Send OTP email
          try {
            await sendOtpEmail(email, otpCode);
          } catch (emailError) {
            console.error('Failed to send OTP email:', emailError);
          }
          
          return res.status(403).json({ 
            error: 'Email not verified',
            requiresVerification: true,
            message: 'Please verify your email with the OTP sent.'
          });
        }

        const token = jwt.sign(
          { customerId: customer.id, role: 'customer' },
          JWT_SECRET,
          { expiresIn: '7d' }
        );

        res.json({ 
          token,
          customer: {
            id: customer.id,
            email: customer.email,
            fullName: customer.full_name,
            phone: customer.phone
          }
        });
      } catch (error) {
        console.error('Error logging in customer:', error);
        res.status(500).json({ error: 'Failed to login' });
      }
    });

    // Forgot Password endpoint
    app.post('/api/customer/forgot-password', async (req, res) => {
      try {
        const { email } = req.body || {};
        
        if (!email) {
          return res.status(400).json({ error: 'Email is required' });
        }

        // Check if customer exists
        const customerResult = await pool.query(
          'SELECT id, email, full_name FROM customer_accounts WHERE email = $1',
          [email.toLowerCase()]
        );

        if (customerResult.rows.length === 0) {
          // Don't reveal if email exists or not for security
          return res.json({ message: 'If an account exists, a reset code will be sent' });
        }

        const customer = customerResult.rows[0];
        
        // Generate 6-digit reset code
        const resetCode = Math.floor(100000 + Math.random() * 900000).toString();
        
        // Store reset code with expiration (30 minutes)
        await pool.query(
          `UPDATE customer_accounts 
           SET reset_code = $1, reset_code_expires = NOW() + INTERVAL '30 minutes'
           WHERE id = $2`,
          [resetCode, customer.id]
        );

        // Send reset code via email
        try {
          await sendPasswordResetEmail(customer.email, resetCode, customer.full_name);
          console.log(`Password reset code sent to ${customer.email}: ${resetCode}`);
        } catch (emailError) {
          console.error('Failed to send password reset email:', emailError);
          // Still return success to avoid revealing email issues
        }

        res.json({ message: 'Reset code sent to your email' });
      } catch (error) {
        console.error('Error in forgot password:', error);
        res.status(500).json({ error: 'Failed to process request' });
      }
    });

    // Reset Password endpoint
    app.post('/api/customer/reset-password', async (req, res) => {
      try {
        const { email, resetCode, newPassword } = req.body || {};
        
        if (!email || !resetCode || !newPassword) {
          return res.status(400).json({ error: 'Email, reset code, and new password are required' });
        }

        if (newPassword.length < 6) {
          return res.status(400).json({ error: 'Password must be at least 6 characters' });
        }

        // Find customer with valid reset code
        const customerResult = await pool.query(
          `SELECT id, email, full_name FROM customer_accounts 
           WHERE email = $1 
           AND reset_code = $2 
           AND reset_code_expires > NOW()`,
          [email.toLowerCase(), resetCode]
        );

        if (customerResult.rows.length === 0) {
          return res.status(400).json({ error: 'Invalid or expired reset code' });
        }

        const customer = customerResult.rows[0];
        
        // Hash new password
        const hashedPassword = await bcrypt.hash(newPassword, 10);
        
        // Update password and clear reset code
        await pool.query(
          `UPDATE customer_accounts 
           SET password_hash = $1, reset_code = NULL, reset_code_expires = NULL
           WHERE id = $2`,
          [hashedPassword, customer.id]
        );

        // Send password changed notification email
        try {
          await sendPasswordChangedEmail(customer.email, customer.full_name);
        } catch (emailError) {
          console.error('Failed to send password changed email:', emailError);
        }

        res.json({ message: 'Password reset successful' });
      } catch (error) {
        console.error('Error resetting password:', error);
        res.status(500).json({ error: 'Failed to reset password' });
      }
    });

    // Restaurant Order endpoints
    const customerAuthRequired = (req, res, next) => {
      const token = req.headers.authorization?.replace('Bearer ', '');
      
      if (!token) {
        return res.status(401).json({ error: 'Authentication required' });
      }

      try {
        const decoded = jwt.verify(token, JWT_SECRET);
        if (decoded.role !== 'customer') {
          return res.status(403).json({ error: 'Customer access required' });
        }
        req.customer = { id: decoded.customerId };
        next();
      } catch (error) {
        return res.status(401).json({ error: 'Invalid token' });
      }
    };

    app.post('/api/restaurant/orders', customerAuthRequired, async (req, res) => {
      try {
        const { items, fullName, phone, deliveryAddress, deliveryLat, deliveryLng, deliveryNotes, totalAmount } = req.body || {};
        const customerId = req.customer.id;
        
        if (!items || !Array.isArray(items) || items.length === 0) {
          return res.status(400).json({ error: 'Items are required' });
        }

        if (!deliveryAddress) {
          return res.status(400).json({ error: 'Delivery address is required' });
        }

        const result = await pool.query(
          `INSERT INTO restaurant_orders (customer_id, full_name, phone, items, total_amount, delivery_address, delivery_lat, delivery_lng, delivery_notes)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
           RETURNING *`,
          [customerId, fullName || null, phone || null, JSON.stringify(items), totalAmount || 0, deliveryAddress, deliveryLat, deliveryLng, deliveryNotes || null]
        );

        res.status(201).json({ order: result.rows[0] });
      } catch (error) {
        console.error('Error creating restaurant order:', error);
        res.status(500).json({ error: 'Failed to create order' });
      }
    });

    app.post('/api/restaurant/orders/:orderId/payment', customerAuthRequired, async (req, res) => {
      try {
        const { orderId } = req.params;
        const { paymentReference } = req.body || {};
        
        if (!paymentReference) {
          return res.status(400).json({ error: 'Payment reference is required' });
        }

        const result = await pool.query(
          `UPDATE restaurant_orders
           SET payment_reference = $1, payment_status = 'paid', status = 'confirmed', updated_at = now()
           WHERE id = $2 AND customer_id = $3
           RETURNING *`,
          [paymentReference, orderId, req.customer.id]
        );

        if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }

        res.json({ order: result.rows[0] });
      } catch (error) {
        console.error('Error updating payment:', error);
        res.status(500).json({ error: 'Failed to update payment' });
      }
    });

    app.get('/api/restaurant/orders/:orderId', customerAuthRequired, async (req, res) => {
      try {
        const { orderId } = req.params;
        
        const result = await pool.query(
          'SELECT * FROM restaurant_orders WHERE id = $1 AND customer_id = $2',
          [orderId, req.customer.id]
        );

        if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Order not found' });
        }

        res.json({ order: result.rows[0] });
      } catch (error) {
        console.error('Error fetching order:', error);
        res.status(500).json({ error: 'Failed to fetch order' });
      }
    });

    app.get('/api/restaurant/orders', customerAuthRequired, async (req, res) => {
      try {
        const result = await pool.query(
          'SELECT * FROM restaurant_orders WHERE customer_id = $1 ORDER BY created_at DESC',
          [req.customer.id]
        );

        res.json({ orders: result.rows });
      } catch (error) {
        console.error('Error fetching orders:', error);
        res.status(500).json({ error: 'Failed to fetch orders' });
      }
    });

    // Customer Account Management (Super Admin only)
    app.get('/api/admin/customers', authRequired, async (req, res) => {
      try {
        // Check if user is super admin
        const userResult = await pool.query(
          'SELECT role FROM users WHERE id = $1',
          [req.user.id]
        );
        
        if (userResult.rows.length === 0 || userResult.rows[0].role !== 'super_admin') {
          return res.status(403).json({ error: 'Super admin access required' });
        }

        const result = await pool.query(
          `SELECT id, email, full_name, phone, is_verified, archived, created_at 
           FROM customer_accounts 
           WHERE archived = FALSE 
           ORDER BY created_at DESC`
        );

        res.json({ customers: result.rows });
      } catch (error) {
        console.error('Error fetching customers:', error);
        res.status(500).json({ error: 'Failed to fetch customers' });
      }
    });

    app.get('/api/admin/customers/:customerId', authRequired, async (req, res) => {
      try {
        const { customerId } = req.params;
        
        // Check if user is super admin
        const userResult = await pool.query(
          'SELECT role FROM users WHERE id = $1',
          [req.user.id]
        );
        
        if (userResult.rows.length === 0 || userResult.rows[0].role !== 'super_admin') {
          return res.status(403).json({ error: 'Super admin access required' });
        }

        const customerResult = await pool.query(
          `SELECT id, email, full_name, phone, is_verified, archived, created_at 
           FROM customer_accounts 
           WHERE id = $1`,
          [customerId]
        );

        if (customerResult.rows.length === 0) {
          return res.status(404).json({ error: 'Customer not found' });
        }

        // Get customer orders
        const ordersResult = await pool.query(
          `SELECT id, total_amount, status, payment_status, created_at 
           FROM restaurant_orders 
           WHERE customer_id = $1 
           ORDER BY created_at DESC`,
          [customerId]
        );

        // Calculate loyalty points (10% of total spent)
        const totalSpent = ordersResult.rows.reduce((sum, order) => {
          return sum + parseFloat(order.total_amount || 0);
        }, 0);
        const loyaltyPoints = Math.floor(totalSpent * 0.1);

        res.json({ 
          customer: customerResult.rows[0],
          orders: ordersResult.rows,
          loyaltyPoints,
          totalSpent,
        });
      } catch (error) {
        console.error('Error fetching customer details:', error);
        res.status(500).json({ error: 'Failed to fetch customer details' });
      }
    });

    app.put('/api/admin/customers/:customerId/archive', authRequired, async (req, res) => {
      try {
        const { customerId } = req.params;
        const { archived } = req.body || {};
        
        // Check if user is super admin
        const userResult = await pool.query(
          'SELECT role FROM users WHERE id = $1',
          [req.user.id]
        );
        
        if (userResult.rows.length === 0 || userResult.rows[0].role !== 'super_admin') {
          return res.status(403).json({ error: 'Super admin access required' });
        }

        const result = await pool.query(
          `UPDATE customer_accounts
           SET archived = $1, updated_at = now()
           WHERE id = $2
           RETURNING *`,
          [archived, customerId]
        );

        if (result.rows.length === 0) {
          return res.status(404).json({ error: 'Customer not found' });
        }

        res.json({ customer: result.rows[0] });
      } catch (error) {
        console.error('Error archiving customer:', error);
        res.status(500).json({ error: 'Failed to archive customer' });
      }
    });

    // Import dishes from CSV
    app.post('/api/menu/dishes/import-csv', authRequired, async (req, res) => {
      try {
        const { csvData, csvType } = req.body || {};
        
        if (!csvData || !csvType) {
          return res.status(400).json({ error: 'CSV data and type are required' });
        }

        const lines = csvData.split('\n');
        const headers = lines[0].split(',').map(h => h.trim());
        let imported = 0;
        let errors = [];
        
        // Track set menus to create for catering import
        const setMenusToCreate = new Map(); // setName -> [dishNames]

        for (let i = 1; i < lines.length; i++) {
          const line = lines[i].trim();
          if (!line) continue;

          try {
            const values = line.split(',').map(v => v.trim().replace(/^"|"$/g, ''));
            
            if (csvType === 'restaurant') {
              // 2sa.csv format: TYPE,DISH,SIZE,PRICE,SAUCES,TAG,CATEGORY
              const type = values[0] || '';
              const name = values[1] || '';
              const size = values[2] || '';
              const price = values[3] || '0';
              const sauces = values[4] ? values[4].split(',').map(s => s.trim()) : [];
              const tag = values[5] || '';
              const category = values[6] || 'restaurant';
              
              // Create pax options based on size
              let paxOptions = ['1 pax'];
              if (size === 'TRAY') {
                paxOptions = ['10-20 pax', '25-40 pax', '50-70 pax', '80-100 pax', '100+ pax'];
              }

              await pool.query(
                `INSERT INTO menu_dishes (name, price, category, pax_options, sauces, ingredients, type)
                 VALUES ($1, $2, $3, $4, $5, $6, $7)
                 ON CONFLICT DO NOTHING`,
                [name, price, category, JSON.stringify(paxOptions), JSON.stringify(sauces), JSON.stringify([tag]), type]
              );
              imported++;
            } else if (csvType === 'catering') {
              // sads.csv format: SET NAME,SET DISHES,INGREDIENTS,TAG,CATEGORY
              const setName = values[0] || '';
              const dishName = values[1] || '';
              const ingredients = values[2] ? values[2].split(',').map(i => i.trim()) : [];
              const tag = values[3] || '';
              const category = values[4] || 'catering';
              
              // Track for set menu creation
              if (setName && !setMenusToCreate.has(setName)) {
                setMenusToCreate.set(setName, []);
              }
              if (setName && dishName) {
                setMenusToCreate.get(setName).push(dishName);
              }
              
              await pool.query(
                `INSERT INTO menu_dishes (name, price, category, pax_options, ingredients, type)
                 VALUES ($1, $2, $3, $4, $5, $6)
                 ON CONFLICT DO NOTHING`,
                [dishName, '0.00', category, JSON.stringify(['10-20 pax', '25-40 pax', '50-70 pax', '80-100 pax', '100+ pax']), JSON.stringify(ingredients), setName]
              );
              imported++;
            } else if (csvType === 'catering-dishes') {
              // sadv.csv format: DISHES,INGREDIENTS,TAG,CATEGORY
              const dishName = values[0] || '';
              const ingredients = values[1] ? values[1].split(',').map(i => i.trim()) : [];
              const tag = values[2] || '';
              const category = values[3] || 'catering';
              
              await pool.query(
                `INSERT INTO menu_dishes (name, price, category, pax_options, ingredients, type)
                 VALUES ($1, $2, $3, $4, $5, $6)
                 ON CONFLICT DO NOTHING`,
                [dishName, '0.00', category, JSON.stringify(['10-20 pax', '25-40 pax', '50-70 pax', '80-100 pax', '100+ pax']), JSON.stringify(ingredients), tag]
              );
              imported++;
            }
          } catch (err) {
            errors.push({ line: i + 1, error: err.message });
          }
        }
        
        // Create set menus for catering import
        let setMenusCreated = 0;
        if (csvType === 'catering' && setMenusToCreate.size > 0) {
          for (const [setName, dishNames] of setMenusToCreate.entries()) {
            try {
              // Get dish IDs for this set
              const dishResult = await pool.query(
                `SELECT id FROM menu_dishes WHERE name = ANY($1) AND type = $2`,
                [dishNames, setName]
              );
              const dishIds = dishResult.rows.map(r => r.id);
              
              if (dishIds.length > 0) {
                // Check if set menu already exists
                const existingResult = await pool.query(
                  `SELECT id FROM set_menus WHERE name = $1`,
                  [setName]
                );
                
                if (existingResult.rows.length > 0) {
                  // Update existing set menu
                  await pool.query(
                    `UPDATE set_menus SET dish_ids = $1, updated_at = now() WHERE name = $2`,
                    [JSON.stringify(dishIds), setName]
                  );
                } else {
                  // Create new set menu
                  await pool.query(
                    `INSERT INTO set_menus (name, dish_ids) VALUES ($1, $2)`,
                    [setName, JSON.stringify(dishIds)]
                  );
                }
                setMenusCreated++;
              }
            } catch (err) {
              console.error(`Error creating set menu ${setName}:`, err);
              errors.push({ line: 0, error: `Failed to create set menu ${setName}: ${err.message}` });
            }
          }
        }

        res.json({ 
          message: `Imported ${imported} dishes${setMenusCreated > 0 ? ` and created ${setMenusCreated} set menus` : ''}`,
          imported,
          setMenusCreated,
          errors: errors.slice(0, 10) // Limit errors returned
        });
      } catch (error) {
        console.error('Error importing dishes from CSV:', error);
        res.status(500).json({ error: 'Failed to import dishes from CSV' });
      }
    });

    // Get all set menus
    app.get('/api/menu/set-menus', async (req, res) => {
      try {
        const result = await pool.query(
          `SELECT id, name, dish_ids, archived, created_at, updated_at 
           FROM set_menus 
           WHERE archived = false 
           ORDER BY name`
        );
        res.json({ setMenus: result.rows });
      } catch (error) {
        console.error('Error fetching set menus:', error);
        res.status(500).json({ error: 'Failed to fetch set menus' });
      }
    });

    // Create a new set menu
    app.post('/api/menu/set-menus', authRequired, async (req, res) => {
      try {
        const { name } = req.body || {};
        
        if (!name) {
          return res.status(400).json({ error: 'Set menu name is required' });
        }

        const result = await pool.query(
          `INSERT INTO set_menus (name, dish_ids) VALUES ($1, $2) RETURNING *`,
          [name, JSON.stringify([])]
        );
        
        res.json({ setMenu: result.rows[0] });
      } catch (error) {
        console.error('Error creating set menu:', error);
        res.status(500).json({ error: 'Failed to create set menu' });
      }
    });

    // Delete a set menu
    app.delete('/api/menu/set-menus/:id', authRequired, async (req, res) => {
      try {
        const { id } = req.params;
        
        await pool.query(
          `DELETE FROM set_menus WHERE id = $1`,
          [id]
        );
        
        res.json({ success: true });
      } catch (error) {
        console.error('Error deleting set menu:', error);
        res.status(500).json({ error: 'Failed to delete set menu' });
      }
    });

    // Add dish to a set menu
    app.post('/api/menu/dishes/:dishId/add-to-set', authRequired, async (req, res) => {
      try {
        const { dishId } = req.params;
        const { setName } = req.body || {};
        
        if (!setName) {
          return res.status(400).json({ error: 'Set name is required' });
        }

        // Get current set_menus for the dish
        const dishResult = await pool.query(
          `SELECT set_menus FROM menu_dishes WHERE id = $1`,
          [dishId]
        );
        
        if (dishResult.rows.length === 0) {
          return res.status(404).json({ error: 'Dish not found' });
        }
        
        let currentSets = dishResult.rows[0].set_menus || [];
        
        // Add the set if not already present
        if (!currentSets.includes(setName)) {
          currentSets.push(setName);
          
          await pool.query(
            `UPDATE menu_dishes SET set_menus = $1, updated_at = now() WHERE id = $2`,
            [JSON.stringify(currentSets), dishId]
          );
        }
        
        res.json({ success: true, setMenus: currentSets });
      } catch (error) {
        console.error('Error adding dish to set:', error);
        res.status(500).json({ error: 'Failed to add dish to set' });
      }
    });

    // Remove dish from a set menu
    app.post('/api/menu/dishes/:dishId/remove-from-set', authRequired, async (req, res) => {
      try {
        const { dishId } = req.params;
        const { setName } = req.body || {};
        
        if (!setName) {
          return res.status(400).json({ error: 'Set name is required' });
        }

        // Get current set_menus for the dish
        const dishResult = await pool.query(
          `SELECT set_menus FROM menu_dishes WHERE id = $1`,
          [dishId]
        );
        
        if (dishResult.rows.length === 0) {
          return res.status(404).json({ error: 'Dish not found' });
        }
        
        let currentSets = dishResult.rows[0].set_menus || [];
        
        // Remove the set
        currentSets = currentSets.filter(s => s !== setName);
        
        await pool.query(
          `UPDATE menu_dishes SET set_menus = $1, updated_at = now() WHERE id = $2`,
          [JSON.stringify(currentSets), dishId]
        );
        
        res.json({ success: true, setMenus: currentSets });
      } catch (error) {
        console.error('Error removing dish from set:', error);
        res.status(500).json({ error: 'Failed to remove dish from set' });
      }
    });

    // Get dishes by set name
    app.get('/api/menu/dishes/by-set/:setName', async (req, res) => {
      try {
        const { setName } = req.params;
        
        const result = await pool.query(
          `SELECT id, name, price, category, pax_options, sauces, ingredients,
                  image_base64, archived, type, set_menus, created_at, updated_at
           FROM menu_dishes 
           WHERE set_menus @> $1::jsonb AND archived = false
           ORDER BY name`,
          [JSON.stringify([setName])]
        );
        
        res.json({ dishes: result.rows });
      } catch (error) {
        console.error('Error fetching dishes by set:', error);
        res.status(500).json({ error: 'Failed to fetch dishes' });
      }
    });

    app.listen(PORT, () => {
      console.log(`Curatering server listening on port ${PORT}`);
    });
  })
  .catch((err) => {
    console.error("Failed to init DB/server:", err);
    process.exit(1);
  });

export default sql;
