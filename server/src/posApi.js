import bcrypt from "bcryptjs";
import {
  ensureRestaurantOrdersCanonicalColumns,
  buildRestaurantOrderSelectSql,
  restaurantOrderLookupWhereSql,
  restaurantOrderIdInsertColumn,
  restaurantOrderItemsInsertSql,
  parseRestaurantOrderTrayItems,
  normalizeRestaurantOrderStatus,
} from "./order_schema.js";
import { getTableColumnNames } from "./db.js";

/**
 * Mobile-compatible POS API (/api/mobile/pos/*) and staff JWT aliases (/api/cashier/pos/*).
 * Maps restaurant_orders rows to the mobile PosOrder shape.
 */

let cachedRestaurantOrderSelect = null;

async function restaurantOrderSelectSql() {
  if (!cachedRestaurantOrderSelect) {
    const cols = await ensureRestaurantOrdersCanonicalColumns();
    cachedRestaurantOrderSelect = buildRestaurantOrderSelectSql(cols);
  }
  return cachedRestaurantOrderSelect;
}

export async function ensureRestaurantPosColumns(pool) {
  const cols = [
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS order_source TEXT NOT NULL DEFAULT 'WEB_APP'`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS pos_customer_label TEXT`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS payment_method TEXT`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS cashier_amount_received_initial DECIMAL(12,2)`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS cashier_amount_received_balance DECIMAL(12,2)`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS payment_proof_balance TEXT`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS balance_proof_pending_review BOOLEAN NOT NULL DEFAULT FALSE`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS pos_claimed BOOLEAN NOT NULL DEFAULT FALSE`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS pos_claimed_at TIMESTAMPTZ`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS payment_proof_initial TEXT`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS payment_reference_initial TEXT`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS payment_reference_balance TEXT`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS amount_paid DECIMAL(10,2)`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS change_given DECIMAL(10,2)`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS payment_proof TEXT`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS payment_uploaded BOOLEAN NOT NULL DEFAULT FALSE`,
    `ALTER TABLE restaurant_orders ADD COLUMN IF NOT EXISTS note TEXT NOT NULL DEFAULT ''`,
  ];
  for (const sql of cols) {
    try {
      await pool.query(sql);
    } catch (err) {
      console.warn("[pos] column migration:", err.message);
    }
  }
}

function fulfillmentStageFromRow(row) {
  return normalizeRestaurantOrderStatus(row.order_status);
}

function orderStatusFromFulfillmentStage(stage) {
  const s = String(stage || "").toUpperCase();
  if (s === "PENDING_CASHIER") return "PENDING_CASHIER";
  if (s === "IN_PREPARATION") return "IN_PREPARATION";
  if (s === "OUT_FOR_DELIVERY") return "OUT_FOR_DELIVERY";
  if (s === "DELIVERED") return "DELIVERED";
  return "PENDING_CASHIER";
}

function posStatusLabel(row) {
  const os = normalizeRestaurantOrderStatus(row.order_status);
  const total = Number(row.total_cost ?? row.total_amount ?? 0);
  const paid = Number(row.cashier_amount_received_initial ?? row.amount_paid ?? 0);
  const supplemental = Number(row.cashier_amount_received_balance ?? 0);

  if (os === "CANCELLED") return "CANCELLED";
  if (paid > 0 && paid < total && os === "PENDING_CASHIER") {
    return "PAYMENT INSUFFICIENT";
  }
  if (row.balance_proof_pending_review && row.payment_proof_balance) {
    return "BALANCE PAYMENT CONFIRMATION";
  }
  if (os === "PENDING_CASHIER") {
    if (row.payment_uploaded_initial || row.payment_proof_initial) {
      return "WAITING FOR PAYMENT CONFIRMATION";
    }
    return "WAITING FOR ORDER CONFIRMATION";
  }
  if (os === "IN_PREPARATION" || os === "OUT_FOR_DELIVERY") {
    const change = Number(row.change_given ?? 0);
    if (change > 0.01 || paid + supplemental > total + 0.01) {
      return "ORDER CONFIRMED WITH OVERPAYMENT";
    }
    return "ORDER CONFIRMED";
  }
  if (os === "DELIVERED") return "DELIVERED";
  return (row.order_status || "UNKNOWN").toUpperCase();
}

function parseItems(raw) {
  if (Array.isArray(raw)) return raw;
  if (typeof raw === "string" && raw.trim()) {
    try {
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  return [];
}

function normalizeLineItems(items) {
  return parseItems(items).map((it) => {
    const m = it && typeof it === "object" ? it : {};
    return {
      item_name: String(m.item_name ?? m.name ?? m.dishName ?? m.dish_name ?? "Item"),
      dip: String(m.dip ?? ""),
      dip_qty: Number(m.dip_qty ?? m.dipQty ?? 0) || 0,
      qty: Math.max(1, Number(m.qty ?? m.quantity ?? 1) || 1),
      price: Number(m.price ?? 0) || 0,
    };
  });
}

export function mapRestaurantOrderRowForPosApi(row, customerName = null) {
  const items = normalizeLineItems(parseRestaurantOrderTrayItems(row));
  const total = Number(row.total_amount ?? row.total_cost ?? 0);
  const proof = row.payment_proof_initial ?? null;
  const refInitial = row.payment_reference_initial ?? row.payment_reference ?? "";
  return {
    id: row.id,
    order_no: row.order_id,
    order_id: row.order_id,
    status: posStatusLabel(row),
    fulfillment_stage: fulfillmentStageFromRow(row),
    total,
    total_cost: total,
    payment_mode: (row.payment_method || "GCASH").toUpperCase(),
    payment_uploaded: row.payment_uploaded === true || Boolean(proof && String(proof).trim()),
    payment_proof: row.payment_proof ?? proof,
    payment_proof_initial: proof,
    supplemental_payment_proof: row.payment_proof_balance ?? null,
    payment_proof_balance: row.payment_proof_balance ?? null,
    payment_reference_initial: refInitial,
    payment_references_initial: refInitial,
    payment_reference_balance: row.payment_reference_balance ?? "",
    cashier_amount_received:
      row.cashier_amount_received_initial != null
        ? Number(row.cashier_amount_received_initial)
        : row.amount_paid != null
          ? Number(row.amount_paid)
          : null,
    cashier_secondary_amount_received:
      row.cashier_amount_received_balance != null
        ? Number(row.cashier_amount_received_balance)
        : null,
    balance_proof_pending_review: row.balance_proof_pending_review === true,
    pos_customer_label: row.pos_customer_label ?? "",
    order_source: row.order_source ?? "ONLINE",
    customer_display_name: customerName ?? row.full_name ?? "",
    guest_contact_email: row.user_email ?? "",
    delivery_name: row.full_name ?? "",
    delivery_contact: row.contact_number ?? "",
    delivery_address: row.delivery_address ?? "",
    delivery_time: row.delivery_time,
    delivery_tracking_url: row.delivery_tracking_url ?? "",
    order_lines_snapshot: items,
    tray_items: items,
    loyalty_points_earned: Number(row.loyalty_points_restaurant_obtained ?? 0),
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

async function verifyPosStaff(pool, email, password) {
  const normalized = String(email || "").trim().toLowerCase();
  if (!normalized || !password) return null;
  const r = await pool.query(
    `SELECT id, email, password_hash, role, archived
     FROM users
     WHERE lower(trim(email)) = $1
     LIMIT 1`,
    [normalized],
  );
  if (!r.rowCount) return null;
  const u = r.rows[0];
  if (u.archived) return null;
  const role = String(u.role || "").toLowerCase();
  if (!["cashier", "manager", "admin", "super_admin", "supervisor"].includes(role)) {
    return null;
  }
  const ok = await bcrypt.compare(String(password), u.password_hash);
  return ok ? u : null;
}

function extractCashierCreds(body) {
  return {
    email: body?.cashier_email ?? body?.cashierEmail,
    password: body?.cashier_password ?? body?.cashierPassword,
  };
}

async function resolvePosAuth(pool, req) {
  if (req.user?.id) {
    const role = String(req.user.role || "").toLowerCase();
    if (["cashier", "manager", "admin", "super_admin", "supervisor"].includes(role)) {
      return { staff: req.user, mode: "jwt" };
    }
    return null;
  }
  const { email, password } = extractCashierCreds(req.body || {});
  const staff = await verifyPosStaff(pool, email, password);
  if (!staff) return null;
  return { staff, mode: "password" };
}

function posAuthMiddleware(pool) {
  return async (req, res, next) => {
    try {
      const auth = await resolvePosAuth(pool, req);
      if (!auth) {
        return res.status(401).json({ error: "Invalid cashier credentials" });
      }
      req.posStaff = auth.staff;
      next();
    } catch (e) {
      console.error("[pos] auth", e);
      res.status(500).json({ error: "Authentication failed" });
    }
  };
}

const CASHIER_ONLINE_ORDER_WHERE = `
  (COALESCE(order_source, 'WEB_APP') IN ('WEB_APP', 'MOBILE_APP'))
  AND (
    user_email IS NOT NULL AND trim(user_email) <> ''
    OR customer_id IS NOT NULL
  )
`;

async function listOnlineOrders(pool) {
  const selectSql = await restaurantOrderSelectSql();
  const r = await pool.query(
    `SELECT ${selectSql}
     FROM restaurant_orders
     WHERE ${CASHIER_ONLINE_ORDER_WHERE}
     ORDER BY created_at DESC
     LIMIT 500`,
  );
  return r.rows.map((row) => mapRestaurantOrderRowForPosApi(row));
}

async function getOrderById(pool, orderId) {
  const id = String(orderId || "").trim();
  if (!id) return null;
  const selectSql = await restaurantOrderSelectSql();
  const roCols = await getTableColumnNames('restaurant_orders');
  const idMatch = restaurantOrderLookupWhereSql(roCols, 1);
  const r = await pool.query(
    `SELECT ${selectSql} FROM restaurant_orders WHERE ${idMatch} LIMIT 1`,
    [id],
  );
  return r.rows[0] || null;
}

export function registerPosRoutes(app, {
  pool,
  authRequired,
  restaurantOrderWhereClause,
  allocateRestaurantOrderNo,
  sendCustomerNotificationEmail,
  resolveRestaurantOrderEmail,
  restaurantFeedbackLink,
}) {
  const posAuth = posAuthMiddleware(pool);
  const staffPos = [authRequired, posAuth];

  const register = (method, path, handler) => {
    app[method](path, posAuth, handler);
    if (path.startsWith("/api/mobile/pos/")) {
      const staffPath = path.replace("/api/mobile/pos/", "/api/cashier/pos/");
      app[method](staffPath, authRequired, posAuth, handler);
    }
  };

  register("post", "/api/mobile/pos/online-orders/list", async (_req, res) => {
    try {
      const orders = await listOnlineOrders(pool);
      res.json(orders);
    } catch (e) {
      console.error("[pos] online-orders/list", e);
      res.status(500).json({ error: "Failed to load orders" });
    }
  });

  register("patch", "/api/mobile/pos/online-orders/:orderId/review", async (req, res) => {
    try {
      const order = await getOrderById(pool, req.params.orderId);
      if (!order) return res.status(404).json({ error: "Order not found" });

      const action = String(req.body?.action || "").toLowerCase();
      const amountReceived = Number(req.body?.amount_received);
      const supplemental = Number(req.body?.supplemental_amount_received);
      const total = Number(order.total_cost || order.total_amount || 0);

      if (action === "confirm") {
        const primary = Number.isFinite(amountReceived) ? amountReceived : total;
        const secondary = Number.isFinite(supplemental) ? supplemental : 0;
        const paid = primary + secondary;
        if (paid < total - 0.01) {
          await pool.query(
            `UPDATE restaurant_orders
             SET cashier_amount_received_initial = $2,
                 balance_proof_pending_review = FALSE,
                 updated_at = now()
             WHERE id = $1`,
            [order.id, primary],
          );
          return res.json({ ok: true, status: "PAYMENT INSUFFICIENT" });
        }
        const change = Number((paid - total).toFixed(2));
        await pool.query(
          `UPDATE restaurant_orders
           SET payment_confirmed_initial = TRUE,
               payment_confirmed_balance = CASE WHEN $3::numeric > 0 THEN TRUE ELSE payment_confirmed_balance END,
               order_status = 'IN_PREPARATION',
               cashier_amount_received_initial = $2,
               cashier_amount_received_balance = $3,
               amount_paid = $2,
               change_given = $4,
               balance_proof_pending_review = FALSE,
               updated_at = now()
           WHERE id = $1`,
          [order.id, primary, secondary, change > 0 ? change : 0],
        );
        const email = await resolveRestaurantOrderEmail(order);
        if (email) {
          await sendCustomerNotificationEmail({
            to: email,
            subject: "Curatering: Payment confirmed",
            text: `Your payment for order ${order.order_id ?? order.order_no} was confirmed. Your order is being prepared.\n\n- Curatering Team`,
          });
        }
        return res.json({ ok: true, status: "ORDER CONFIRMED" });
      }

      if (action === "insufficient") {
        await pool.query(
          `UPDATE restaurant_orders
           SET cashier_amount_received_initial = $2,
               updated_at = now()
           WHERE id = $1`,
          [order.id, Number.isFinite(amountReceived) ? amountReceived : 0],
        );
        return res.json({ ok: true, status: "PAYMENT INSUFFICIENT" });
      }

      if (action === "overpayment") {
        const paid = Number.isFinite(amountReceived) ? amountReceived : total;
        const change = Number((paid - total).toFixed(2));
        await pool.query(
          `UPDATE restaurant_orders
           SET payment_confirmed_initial = TRUE,
               order_status = 'IN_PREPARATION',
               cashier_amount_received_initial = $2,
               amount_paid = $2,
               change_given = $3,
               updated_at = now()
           WHERE id = $1`,
          [order.id, paid, change > 0 ? change : 0],
        );
        return res.json({ ok: true, status: "ORDER CONFIRMED WITH OVERPAYMENT" });
      }

      return res.status(400).json({ error: "Invalid action" });
    } catch (e) {
      console.error("[pos] review", e);
      res.status(500).json({ error: "Failed to review order" });
    }
  });

  register("post", "/api/mobile/pos/online-orders/:orderId/remind-balance", async (req, res) => {
    try {
      const order = await getOrderById(pool, req.params.orderId);
      if (!order) return res.status(404).json({ error: "Order not found" });
      const email = await resolveRestaurantOrderEmail(order);
      if (!email) return res.status(400).json({ error: "No customer email on order" });
      const total = Number(order.total_cost || order.total_amount || 0);
      const paid = Number(order.cashier_amount_received_initial ?? order.amount_paid ?? 0);
      await sendCustomerNotificationEmail({
        to: email,
        subject: "Curatering: Balance payment required",
        text:
          `Hello,\n\nYour order ${order.order_id ?? order.order_no} has an outstanding balance.\n` +
          `Order total: PHP ${total.toFixed(2)}\nAmount received: PHP ${paid.toFixed(2)}\n` +
          `Please submit the remaining payment.\n\n- Curatering Team`,
      });
      res.json({ ok: true });
    } catch (e) {
      console.error("[pos] remind-balance", e);
      res.status(500).json({ error: "Failed to send reminder" });
    }
  });

  register("patch", "/api/mobile/pos/online-orders/:orderId/fulfillment", async (req, res) => {
    try {
      const order = await getOrderById(pool, req.params.orderId);
      if (!order) return res.status(404).json({ error: "Order not found" });

      const stage = String(req.body?.fulfillment_stage || "").toUpperCase();
      const tracking = String(req.body?.delivery_tracking_url || "").trim();
      const orderStatus = orderStatusFromFulfillmentStage(stage);

      const fields = ["order_status = $2", "updated_at = now()"];
      const vals = [order.id, orderStatus];
      if (tracking) {
        fields.push(`delivery_tracking_url = $${fields.length + 1}`);
        vals.push(tracking);
      }

      await pool.query(
        `UPDATE restaurant_orders SET ${fields.join(", ")} WHERE id = $1`,
        vals,
      );

      if (orderStatus === "DELIVERED") {
        const total = Number(order.total_cost || order.total_amount || 0);
        if (total >= 100) {
          const points = Math.floor((total * 2) / 100);
          await pool.query(
            `UPDATE restaurant_orders
             SET loyalty_points_restaurant_obtained = $2
             WHERE id = $1`,
            [order.id, points],
          );
          if (order.customer_id) {
            await pool.query(
              `UPDATE customer_accounts
               SET restaurant_loyalty_points = COALESCE(restaurant_loyalty_points, 0) + $2,
                   updated_at = now()
               WHERE id = $1`,
              [order.customer_id, points],
            );
          }
        }
        const email = await resolveRestaurantOrderEmail(order);
        if (email) {
          await sendCustomerNotificationEmail({
            to: email,
            subject: "Curatering: Order delivered",
            text:
              `Your order ${order.order_id ?? order.order_no} has been delivered.\n\n` +
              `Share your feedback: ${restaurantFeedbackLink(order)}\n\n` +
              `- Curatering Team`,
          });
        }
      }

      res.json({ ok: true });
    } catch (e) {
      console.error("[pos] fulfillment", e);
      res.status(500).json({ error: "Failed to update fulfillment" });
    }
  });

  register("post", "/api/mobile/pos/walkin-order", async (req, res) => {
    try {
      const items = normalizeLineItems(req.body?.items);
      if (!items.length) return res.status(400).json({ error: "items are required" });

      const paymentMethod = String(req.body?.payment_method || "CASH").toUpperCase();
      const amountReceived = Number(req.body?.amount_received ?? 0);
      const total = items.reduce((s, it) => s + it.price * it.qty, 0);
      const proof = req.body?.payment_proof ? String(req.body.payment_proof) : null;
      if (paymentMethod === "GCASH" && !proof) {
        return res.status(400).json({ error: "payment_proof required for GCASH" });
      }

      const orderNo = await allocateRestaurantOrderNo();
      const roCols = await ensureRestaurantOrdersCanonicalColumns();
      const orderIdCol = restaurantOrderIdInsertColumn(roCols);
      const itemsInsert = restaurantOrderItemsInsertSql(roCols);
      const itemsJson = JSON.stringify(items);
      const itemsSql = itemsInsert.placeholders.replace(/\$ITEM\$/g, "$3::jsonb");
      const change =
        amountReceived > total ? Number((amountReceived - total).toFixed(2)) : 0;

      const r = await pool.query(
        `INSERT INTO restaurant_orders (
           ${orderIdCol}, full_name, contact_number, ${itemsInsert.columns}, total_cost,
           delivery_address, delivery_lat, delivery_lng,
           order_status, payment_method,
           order_source, pos_customer_label, payment_proof,
           payment_uploaded, cashier_amount_received_initial, amount_paid,
           change_given, pos_claimed_at, note
         ) VALUES (
           $1, $2, '', ${itemsSql}, $4,
           'Walk-in', NULL, NULL,
           'IN_PREPARATION', $5,
           'POS_WEB', $6, $7,
           $10, $8, $8, $9, now(), $11
         )
         RETURNING *`,
        [
          orderNo,
          String(req.body?.pos_customer_label || "Walk-in").trim() || "Walk-in",
          itemsJson,
          total,
          paymentMethod,
          String(req.body?.pos_customer_label || "").trim(),
          proof,
          amountReceived,
          change,
          Boolean(proof),
          String(req.body?.note || "").trim(),
        ],
      );

      res.status(201).json({
        id: r.rows[0].id,
        order_no: orderNo,
        total,
        change: change > 0 ? change : null,
      });
    } catch (e) {
      console.error("[pos] walkin-order", e);
      res.status(500).json({ error: "Failed to create walk-in order" });
    }
  });

  register("post", "/api/mobile/pos/walkin-queue", async (req, res) => {
    try {
      const filter = String(req.body?.filter || "preparing").toLowerCase();
      let where = `COALESCE(order_source, '') = 'POS'`;
      where = `COALESCE(order_source, '') IN ('POS_MOBILE', 'POS_WEB')`;
      if (filter === "preparing") {
        where += ` AND order_status = 'IN_PREPARATION' AND pos_claimed = FALSE`;
      } else if (filter === "claimed") {
        where += ` AND pos_claimed = TRUE AND order_status <> 'CANCELLED'`;
      } else if (filter === "cancelled") {
        where += ` AND order_status = 'CANCELLED'`;
      }

      const selectSql = await restaurantOrderSelectSql();
      const r = await pool.query(
        `SELECT ${selectSql}
         FROM restaurant_orders
         WHERE ${where}
         ORDER BY created_at DESC
         LIMIT 200`,
      );
      res.json(r.rows.map((row) => mapRestaurantOrderRowForPosApi(row)));
    } catch (e) {
      console.error("[pos] walkin-queue", e);
      res.status(500).json({ error: "Failed to load walk-in queue" });
    }
  });

  register("patch", "/api/mobile/pos/walkin-orders/:orderId/claim", async (req, res) => {
    try {
      const order = await getOrderById(pool, req.params.orderId);
      if (!order) return res.status(404).json({ error: "Order not found" });
      await pool.query(
        `UPDATE restaurant_orders
         SET pos_claimed_at = COALESCE(pos_claimed_at, now()),
             pos_claimed = TRUE,
             order_status = 'DELIVERED',
             updated_at = now()
         WHERE id = $1`,
        [order.id],
      );
      res.json({ ok: true });
    } catch (e) {
      console.error("[pos] walkin claim", e);
      res.status(500).json({ error: "Failed to claim order" });
    }
  });

  register("patch", "/api/mobile/pos/walkin-orders/:orderId/cancel", async (req, res) => {
    try {
      const order = await getOrderById(pool, req.params.orderId);
      if (!order) return res.status(404).json({ error: "Order not found" });
      await pool.query(
        `UPDATE restaurant_orders
         SET order_status = 'CANCELLED', updated_at = now()
         WHERE id = $1`,
        [order.id],
      );
      res.json({ ok: true });
    } catch (e) {
      console.error("[pos] walkin cancel", e);
      res.status(500).json({ error: "Failed to cancel order" });
    }
  });

  register("post", "/api/mobile/pos/order-history", async (_req, res) => {
    try {
      const selectSql = await restaurantOrderSelectSql();
      const r = await pool.query(
        `SELECT ${selectSql}
         FROM restaurant_orders
         WHERE order_status = 'DELIVERED'
            OR (COALESCE(order_source, '') IN ('POS_MOBILE', 'POS_WEB') AND pos_claimed = TRUE)
         ORDER BY updated_at DESC
         LIMIT 250`,
      );
      res.json(r.rows.map((row) => mapRestaurantOrderRowForPosApi(row)));
    } catch (e) {
      console.error("[pos] order-history", e);
      res.status(500).json({ error: "Failed to load order history" });
    }
  });

  app.get("/api/mobile/menu", async (_req, res) => {
    try {
      const r = await pool.query(
        `SELECT id, name, price, category, pax_options, sauces, ingredients, image_base64, type, meal_type, available
         FROM menu_dishes
         WHERE available = TRUE
         ORDER BY category, name`,
      );
      res.json({ dishes: r.rows });
    } catch (e) {
      console.error("[pos] menu", e);
      res.status(500).json({ error: "Failed to load menu" });
    }
  });
}
