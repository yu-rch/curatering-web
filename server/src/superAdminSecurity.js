import crypto from "node:crypto";
import { pool, allocateStaffUserId } from "./db.js";

export const LAST_SUPER_ADMIN_MESSAGE =
  "Cannot remove the last active Super Admin.";

const SYSTEM_CONTROL_LOCK_KEY = 902103449;

export class LastSuperAdminError extends Error {
  constructor(message = LAST_SUPER_ADMIN_MESSAGE) {
    super(message);
    this.name = "LastSuperAdminError";
    this.status = 409;
  }
}

export class RecoveryConsumedError extends Error {
  constructor(
    message = "Recovery credential already used. Rotate SUPER_ADMIN_RECOVERY_SECRET.",
  ) {
    super(message);
    this.name = "RecoveryConsumedError";
    this.status = 403;
  }
}

function timingSafeEqualString(a, b) {
  const left = Buffer.from(String(a ?? ""), "utf8");
  const right = Buffer.from(String(b ?? ""), "utf8");
  if (left.length !== right.length) {
    if (right.length > 0) {
      crypto.timingSafeEqual(right, right);
    }
    return false;
  }
  if (left.length === 0) return false;
  return crypto.timingSafeEqual(left, right);
}

export function hashRecoverySecret(secret) {
  return crypto.createHash("sha256").update(String(secret), "utf8").digest("hex");
}

export function recoverySecretMatchesEnv(provided) {
  const expected = process.env.SUPER_ADMIN_RECOVERY_SECRET;
  if (!expected || typeof provided !== "string" || !provided) return false;
  return timingSafeEqualString(provided, expected);
}

export async function getActiveSuperAdminCount(client = pool) {
  const result = await client.query(
    `SELECT COUNT(*)::int AS n
     FROM users
     WHERE role = 'super_admin' AND archived = FALSE`,
  );
  return Number(result.rows[0]?.n) || 0;
}

export async function ensureSystemControlRow(client = pool) {
  await client.query(
    `INSERT INTO system_control (id) VALUES (1)
     ON CONFLICT (id) DO NOTHING`,
  );
}

export async function withSuperAdminSecurityLock(fn) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("SELECT pg_advisory_xact_lock($1)", [
      SYSTEM_CONTROL_LOCK_KEY,
    ]);
    await ensureSystemControlRow(client);
    await client.query(`SELECT id FROM system_control WHERE id = 1 FOR UPDATE`);
    const result = await fn(client);
    await client.query("COMMIT");
    return result;
  } catch (e) {
    try {
      await client.query("ROLLBACK");
    } catch {
      // ignore rollback errors
    }
    throw e;
  } finally {
    client.release();
  }
}

export async function assertNotLastActiveSuperAdmin(client, targetUserId) {
  const target = await client.query(
    `SELECT id, role, archived
     FROM users
     WHERE id = $1
     FOR UPDATE`,
    [targetUserId],
  );
  if (target.rowCount === 0) {
    const err = new Error("User not found");
    err.status = 404;
    err.name = "UserNotFoundError";
    throw err;
  }
  const row = target.rows[0];
  if (row.role !== "super_admin" || row.archived === true) {
    return row;
  }
  const count = await getActiveSuperAdminCount(client);
  if (count <= 1) {
    throw new LastSuperAdminError();
  }
  return row;
}

export async function ensurePrimarySuperAdmin(client, preferredUserId = null) {
  await ensureSystemControlRow(client);
  const ctrl = await client.query(
    `SELECT primary_super_admin_id FROM system_control WHERE id = 1`,
  );
  const currentId = ctrl.rows[0]?.primary_super_admin_id || null;
  if (currentId) {
    const current = await client.query(
      `SELECT id FROM users
       WHERE id = $1 AND role = 'super_admin' AND archived = FALSE
       LIMIT 1`,
      [currentId],
    );
    if (current.rowCount > 0) return current.rows[0].id;
  }

  if (preferredUserId) {
    const preferred = await client.query(
      `SELECT id FROM users
       WHERE id = $1 AND role = 'super_admin' AND archived = FALSE
       LIMIT 1`,
      [preferredUserId],
    );
    if (preferred.rowCount > 0) {
      await client.query(
        `UPDATE system_control
         SET primary_super_admin_id = $1, updated_at = now()
         WHERE id = 1`,
        [preferredUserId],
      );
      return preferredUserId;
    }
  }

  const oldest = await client.query(
    `SELECT id FROM users
     WHERE role = 'super_admin' AND archived = FALSE
     ORDER BY created_at ASC
     LIMIT 1`,
  );
  const nextId = oldest.rows[0]?.id || null;
  await client.query(
    `UPDATE system_control
     SET primary_super_admin_id = $1, updated_at = now()
     WHERE id = 1`,
    [nextId],
  );
  return nextId;
}

export async function getSuperAdminSecuritySnapshot(client = pool) {
  await ensureSystemControlRow(client);
  const count = await getActiveSuperAdminCount(client);
  const ctrl = await client.query(
    `SELECT primary_super_admin_id FROM system_control WHERE id = 1`,
  );
  const users = await client.query(
    `SELECT id, email, full_name, archived
     FROM users
     WHERE role = 'super_admin' AND archived = FALSE
     ORDER BY created_at ASC`,
  );
  return {
    activeCount: count,
    primarySuperAdminId: ctrl.rows[0]?.primary_super_admin_id || null,
    superAdmins: users.rows.map((u) => ({
      id: u.id,
      email: u.email,
      fullName: u.full_name,
      archived: u.archived === true,
    })),
  };
}

export async function requireActiveSuperAdminFromDb(req, res, next) {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(403).json({ message: "Super Admin only" });
    }
    const result = await pool.query(
      `SELECT role, archived FROM users WHERE id = $1 LIMIT 1`,
      [userId],
    );
    const row = result.rows[0];
    if (!row || row.role !== "super_admin" || row.archived === true) {
      return res.status(403).json({ message: "Super Admin only" });
    }
    req.user.role = row.role;
    return next();
  } catch (e) {
    console.error("requireActiveSuperAdminFromDb", e);
    return res.status(403).json({ message: "Super Admin only" });
  }
}

export async function assertRecoverySecretNotConsumed(client, secret) {
  const incomingHash = hashRecoverySecret(secret);
  const row = await client.query(
    `SELECT recovery_secret_hash FROM system_control WHERE id = 1`,
  );
  const stored = row.rows[0]?.recovery_secret_hash;
  if (stored && timingSafeEqualString(stored, incomingHash)) {
    throw new RecoveryConsumedError();
  }
  return incomingHash;
}

export async function consumeRecoverySecret(client, secretHash, primaryUserId) {
  await client.query(
    `UPDATE system_control
     SET recovery_secret_hash = $1,
         recovery_version = recovery_version + 1,
         primary_super_admin_id = $2,
         updated_at = now()
     WHERE id = 1`,
    [secretHash, primaryUserId],
  );
}

export async function restoreOrCreateSuperAdmin(
  client,
  { email, passwordHash, fullName },
) {
  const existing = await client.query(
    `SELECT id FROM users WHERE lower(trim(email::text)) = $1 LIMIT 1`,
    [email],
  );

  let userId;
  let created = false;
  if (existing.rowCount > 0) {
    userId = existing.rows[0].id;
    await client.query(
      `UPDATE users
       SET email = $1,
           password_hash = $2,
           full_name = $3,
           role = 'super_admin',
           archived = FALSE,
           is_verified = TRUE,
           otp_code = NULL,
           otp_expiry = NULL
       WHERE id = $4`,
      [email, passwordHash, fullName, userId],
    );
  } else {
    userId = await allocateStaffUserId();
    created = true;
    await client.query(
      `INSERT INTO users
        (id, email, password_hash, full_name, role, archived, is_verified)
       VALUES ($1, $2, $3, $4, 'super_admin', FALSE, TRUE)`,
      [userId, email, passwordHash, fullName],
    );
  }

  return { userId, created };
}

export function sendSuperAdminSecurityError(res, e) {
  if (e instanceof LastSuperAdminError || e?.name === "LastSuperAdminError") {
    res.status(409).json({ error: e.message });
    return true;
  }
  if (e?.name === "UserNotFoundError" || e?.status === 404) {
    res.status(404).json({ message: e.message || "User not found" });
    return true;
  }
  if (e instanceof RecoveryConsumedError || e?.name === "RecoveryConsumedError") {
    res.status(403).json({ error: e.message });
    return true;
  }
  return false;
}
