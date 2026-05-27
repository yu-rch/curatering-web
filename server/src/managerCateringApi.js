import {
  listStaffCateringOrders,
  getStaffCateringOrder,
  patchCateringOrder,
  createStaffCateringOrder,
  normalizeMobileCateringStage,
} from "./posApi.js";
import { getTableColumnNames } from "./db.js";

/**
 * Web manager routes for catering/event orders — same data layer as mobile POS catering API.
 */
export function registerManagerCateringRoutes(app, { pool, authRequired, requireRoles }) {
  const managerRoles = new Set(["manager", "admin", "super_admin"]);
  const staffRoles = new Set(["manager", "supervisor", "admin", "super_admin"]);

  app.post(
    "/api/manager/catering/list",
    authRequired,
    (req, res, next) => requireRoles(req, res, next, staffRoles),
    async (req, res) => {
      try {
        const stage = normalizeMobileCateringStage(req.body?.stage);
        const orders = await listStaffCateringOrders(pool, stage, {
          compact: Boolean(req.body?.compact || req.body?.summary),
        });
        res.json({ orders });
      } catch (e) {
        console.error("[manager] catering/list", e);
        res.status(500).json({ error: "Failed to load catering orders" });
      }
    },
  );

  app.post(
    "/api/manager/catering/item",
    authRequired,
    (req, res, next) => requireRoles(req, res, next, staffRoles),
    async (req, res) => {
      try {
        const id = String(req.body?.id || "").trim();
        const orderKind = String(req.body?.order_kind || req.body?.orderKind || "").trim().toLowerCase();
        if (!id) return res.status(400).json({ error: "id is required" });
        const order = await getStaffCateringOrder(pool, id, orderKind);
        if (!order) return res.status(404).json({ error: "Order not found" });
        res.json({ order });
      } catch (e) {
        console.error("[manager] catering/item", e);
        res.status(500).json({ error: "Failed to load catering order" });
      }
    },
  );

  app.post(
    "/api/manager/catering/new-event",
    authRequired,
    (req, res, next) => requireRoles(req, res, next, managerRoles),
    async (req, res) => {
      try {
        const created = await createStaffCateringOrder(pool, req.body || {});
        res.status(201).json({
          id: created.id,
          transaction_no: created.transaction_no,
          order_kind: created.order_kind,
        });
      } catch (e) {
        console.error("[manager] catering/new-event", e);
        res.status(500).json({ error: "Failed to create catering event" });
      }
    },
  );

  app.patch(
    "/api/manager/catering/:orderId/stage",
    authRequired,
    (req, res, next) => requireRoles(req, res, next, staffRoles),
    async (req, res) => {
      const role = String(req.user?.role || "").trim().toLowerCase();
      const nextStatus = normalizeMobileCateringStage(req.body?.status);
      if (role === "supervisor" && nextStatus === "completed") {
        return res.status(403).json({ error: "supervisor cannot complete orders" });
      }
      try {
        const result = await patchCateringOrder(
          pool,
          req.params.orderId,
          req.body?.order_kind || req.body?.orderKind,
          req.body,
          { requireStatus: true },
        );
        if (!result) return res.status(404).json({ error: "Order not found" });
        if (result.error) return res.status(400).json({ error: result.error });
        res.json({ ok: true });
      } catch (e) {
        console.error("[manager] catering/stage", e);
        res.status(500).json({ error: "Failed to update catering stage" });
      }
    },
  );

  app.patch(
    "/api/manager/catering/:orderId/draft",
    authRequired,
    (req, res, next) => requireRoles(req, res, next, staffRoles),
    async (req, res) => {
      try {
        const result = await patchCateringOrder(
          pool,
          req.params.orderId,
          req.body?.order_kind || req.body?.orderKind,
          req.body,
        );
        if (!result) return res.status(404).json({ error: "Order not found" });
        res.json({ ok: true });
      } catch (e) {
        console.error("[manager] catering/draft", e);
        res.status(500).json({ error: "Failed to save catering draft" });
      }
    },
  );

  app.patch(
    "/api/manager/catering/:orderId/post-analysis-patch",
    authRequired,
    (req, res, next) => requireRoles(req, res, next, staffRoles),
    async (req, res) => {
      try {
        const id = String(req.params.orderId || "").trim();
        const orderKind = String(req.body?.order_kind || req.body?.orderKind || "").trim().toLowerCase();
        const patch = req.body?.patch;
        if (!patch || typeof patch !== "object" || Array.isArray(patch)) {
          return res.status(400).json({ error: "patch object is required" });
        }
        const table =
          orderKind === "catering"
            ? "catering_orders"
            : orderKind === "event"
              ? "event_orders"
              : null;
        let resolvedTable = table;
        if (!resolvedTable) {
          for (const t of ["event_orders", "catering_orders"]) {
            const r = await pool.query(`SELECT 1 FROM ${t} WHERE id::text = $1 LIMIT 1`, [id]);
            if (r.rowCount > 0) {
              resolvedTable = t;
              break;
            }
          }
        }
        if (!resolvedTable) return res.status(404).json({ error: "Order not found" });
        const cols = await getTableColumnNames(resolvedTable);

        // Apply patch to stage metadata (stored in post_analysis column for now).
        if (cols.has("post_analysis")) {
          await pool.query(
            `UPDATE ${resolvedTable}
             SET post_analysis = COALESCE(post_analysis, '{}'::jsonb) || $2::jsonb,
                 updated_at = now()
             WHERE id::text = $1`,
            [id, JSON.stringify(patch)],
          );
        }

        // Normalize + persist pax_buffer if the table has it.
        const paxBufferRaw = patch?.pax_buffer ?? patch?.paxBuffer;
        if (cols.has("pax_buffer") && paxBufferRaw != null) {
          await pool.query(
            `UPDATE ${resolvedTable}
             SET pax_buffer = $2,
                 updated_at = now()
             WHERE id::text = $1`,
            [id, Number(paxBufferRaw) || 0],
          );
        }

        // Recompute authoritative total_cost to avoid client-side drift.
        // Formula: (guest_count + pax_buffer) * 500 + menu add-ons + theme + labor + travel + additional costs
        if (cols.has("total_cost") && cols.has("guest_count")) {
          const r = await pool.query(
            `SELECT guest_count, COALESCE(pax_buffer, 0) AS pax_buffer,
                    COALESCE(menu, '[]'::jsonb) AS menu,
                    COALESCE(theme_design, '{}'::jsonb) AS theme_design,
                    COALESCE(post_analysis, '{}'::jsonb) AS post_analysis
             FROM ${resolvedTable}
             WHERE id::text = $1
             LIMIT 1`,
            [id],
          );
          if (r.rowCount) {
            const row = r.rows[0] || {};
            const guestCount = Number(row.guest_count || 0) || 0;
            const paxBuffer = Number(row.pax_buffer || 0) || 0;

            let menuAddOns = 0;
            const menu = Array.isArray(row.menu) ? row.menu : [];
            for (const m of menu) {
              if (m && typeof m === "object") {
                menuAddOns += Number(
                  m.additionalChargeAmount ??
                  m.additional_charge_amount ??
                  m.menu_dishes_additional_charge_amount ??
                  0,
                ) || 0;
              }
            }

            const theme = row.theme_design && typeof row.theme_design === "object"
              ? row.theme_design
              : {};
            const costBreakdown = theme.costBreakdown && typeof theme.costBreakdown === "object"
              ? theme.costBreakdown
              : {};
            const laborCost = Number(theme.laborCost ?? theme.labor_cost ?? costBreakdown.laborCost ?? costBreakdown.labor_cost ?? 0) || 0;
            const travelCost = Number(theme.travelCost ?? theme.travel_cost ?? costBreakdown.travelCost ?? costBreakdown.travel_cost ?? 0) || 0;
            const themeDesignCost = Number(
              row.post_analysis?.theme_design_cost ??
              row.post_analysis?.themeDesignCost ??
              0,
            ) || 0;

            let additionalCosts = 0;
            const pa = row.post_analysis && typeof row.post_analysis === "object" ? row.post_analysis : {};
            const flat = Array.isArray(pa.additional_costs) ? pa.additional_costs : [];
            for (const item of flat) {
              if (item && typeof item === "object") {
                additionalCosts += Number(item.amount ?? item.cost ?? 0) || 0;
              }
            }

            const base = (guestCount + paxBuffer) * 500;
            const nextTotal = base + menuAddOns + themeDesignCost + laborCost + travelCost + additionalCosts;
            await pool.query(
              `UPDATE ${resolvedTable}
               SET total_cost = $2,
                   updated_at = now()
               WHERE id::text = $1`,
              [id, nextTotal],
            );
          }
        }

        res.json({ ok: true });
      } catch (e) {
        console.error("[manager] catering/post-analysis-patch", e);
        res.status(500).json({ error: "Failed to update stage data" });
      }
    },
  );

  // Alias endpoint with updated terminology (no "post-analysis" wording).
  app.patch(
    "/api/manager/catering/:orderId/stage-data-patch",
    authRequired,
    (req, res, next) => requireRoles(req, res, next, staffRoles),
    async (req, res) => {
      // Delegate by rewriting path expectations (same handler semantics).
      req.params.orderId = req.params.orderId;
      // Call through by reusing the same implementation block above via HTTP would be wasteful;
      // instead, simply fall through by invoking the same code path:
      // We re-run the same logic here by calling next handler style.
      // eslint-disable-next-line no-unused-vars
      try {
        const id = String(req.params.orderId || "").trim();
        const orderKind = String(req.body?.order_kind || req.body?.orderKind || "").trim().toLowerCase();
        const patch = req.body?.patch;
        if (!patch || typeof patch !== "object" || Array.isArray(patch)) {
          return res.status(400).json({ error: "patch object is required" });
        }
        const table =
          orderKind === "catering"
            ? "catering_orders"
            : orderKind === "event"
              ? "event_orders"
              : null;
        let resolvedTable = table;
        if (!resolvedTable) {
          for (const t of ["event_orders", "catering_orders"]) {
            const r = await pool.query(`SELECT 1 FROM ${t} WHERE id::text = $1 LIMIT 1`, [id]);
            if (r.rowCount > 0) {
              resolvedTable = t;
              break;
            }
          }
        }
        if (!resolvedTable) return res.status(404).json({ error: "Order not found" });
        const cols = await getTableColumnNames(resolvedTable);

        if (cols.has("post_analysis")) {
          await pool.query(
            `UPDATE ${resolvedTable}
             SET post_analysis = COALESCE(post_analysis, '{}'::jsonb) || $2::jsonb,
                 updated_at = now()
             WHERE id::text = $1`,
            [id, JSON.stringify(patch)],
          );
        }

        const paxBufferRaw = patch?.pax_buffer ?? patch?.paxBuffer;
        if (cols.has("pax_buffer") && paxBufferRaw != null) {
          await pool.query(
            `UPDATE ${resolvedTable}
             SET pax_buffer = $2,
                 updated_at = now()
             WHERE id::text = $1`,
            [id, Number(paxBufferRaw) || 0],
          );
        }

        if (cols.has("total_cost") && cols.has("guest_count")) {
          const r = await pool.query(
            `SELECT guest_count, COALESCE(pax_buffer, 0) AS pax_buffer,
                    COALESCE(menu, '[]'::jsonb) AS menu,
                    COALESCE(theme_design, '{}'::jsonb) AS theme_design,
                    COALESCE(post_analysis, '{}'::jsonb) AS post_analysis
             FROM ${resolvedTable}
             WHERE id::text = $1
             LIMIT 1`,
            [id],
          );
          if (r.rowCount) {
            const row = r.rows[0] || {};
            const guestCount = Number(row.guest_count || 0) || 0;
            const paxBuffer = Number(row.pax_buffer || 0) || 0;

            let menuAddOns = 0;
            const menu = Array.isArray(row.menu) ? row.menu : [];
            for (const m of menu) {
              if (m && typeof m === "object") {
                menuAddOns += Number(
                  m.additionalChargeAmount ??
                  m.additional_charge_amount ??
                  m.menu_dishes_additional_charge_amount ??
                  0,
                ) || 0;
              }
            }

            const theme = row.theme_design && typeof row.theme_design === "object"
              ? row.theme_design
              : {};
            const costBreakdown = theme.costBreakdown && typeof theme.costBreakdown === "object"
              ? theme.costBreakdown
              : {};
            const laborCost = Number(theme.laborCost ?? theme.labor_cost ?? costBreakdown.laborCost ?? costBreakdown.labor_cost ?? 0) || 0;
            const travelCost = Number(theme.travelCost ?? theme.travel_cost ?? costBreakdown.travelCost ?? costBreakdown.travel_cost ?? 0) || 0;
            const themeDesignCost = Number(
              row.post_analysis?.theme_design_cost ??
              row.post_analysis?.themeDesignCost ??
              0,
            ) || 0;

            let additionalCosts = 0;
            const pa = row.post_analysis && typeof row.post_analysis === "object" ? row.post_analysis : {};
            const flat = Array.isArray(pa.additional_costs) ? pa.additional_costs : [];
            for (const item of flat) {
              if (item && typeof item === "object") {
                additionalCosts += Number(item.amount ?? item.cost ?? 0) || 0;
              }
            }

            const base = (guestCount + paxBuffer) * 500;
            const nextTotal = base + menuAddOns + themeDesignCost + laborCost + travelCost + additionalCosts;
            await pool.query(
              `UPDATE ${resolvedTable}
               SET total_cost = $2,
                   updated_at = now()
               WHERE id::text = $1`,
              [id, nextTotal],
            );
          }
        }

        return res.json({ ok: true });
      } catch (e) {
        console.error("[manager] catering/stage-data-patch", e);
        return res.status(500).json({ error: "Failed to update stage data" });
      }
    },
  );
}
