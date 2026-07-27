/**
 * Website CMS: published/draft content, revisions, and media library.
 */
import crypto from "node:crypto";
import fs from "fs/promises";

export const WEBSITE_CONTENT_ROW_ID = "00000000-0000-0000-0000-000000000001";
const MAX_REVISIONS = 30;
const MAX_MEDIA_BYTES = 4 * 1024 * 1024; // 4MB per asset

export function isNonEmptyWebsiteContent(content) {
  return (
    content &&
    typeof content === "object" &&
    !Array.isArray(content) &&
    Object.keys(content).length > 0
  );
}

export async function ensureWebsiteCmsSchema(pool) {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS website_content (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      content JSONB NOT NULL DEFAULT '{}',
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
  await pool.query(
    `ALTER TABLE website_content ADD COLUMN IF NOT EXISTS draft_content JSONB`,
  );
  await pool.query(
    `ALTER TABLE website_content ADD COLUMN IF NOT EXISTS draft_updated_at TIMESTAMPTZ`,
  );
  await pool.query(
    `ALTER TABLE website_content ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ`,
  );
  await pool.query(
    `ALTER TABLE website_content ADD COLUMN IF NOT EXISTS published_by TEXT`,
  );

  await pool.query(`
    CREATE TABLE IF NOT EXISTS website_content_revisions (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      content JSONB NOT NULL,
      note TEXT,
      published_by TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_website_content_revisions_created
    ON website_content_revisions (created_at DESC)
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS website_media (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL DEFAULT '',
      mime TEXT NOT NULL DEFAULT 'image/jpeg',
      data_base64 TEXT NOT NULL,
      byte_size INT NOT NULL DEFAULT 0,
      tags TEXT[] NOT NULL DEFAULT '{}',
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      created_by TEXT
    )
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_website_media_created
    ON website_media (created_at DESC)
  `);
}

function stripDataUrl(b64) {
  if (typeof b64 !== "string") return "";
  const i = b64.indexOf("base64,");
  return i >= 0 ? b64.slice(i + 7) : b64;
}

function estimateBytes(b64) {
  const s = stripDataUrl(b64);
  return Math.floor((s.length * 3) / 4);
}

async function insertMedia(pool, { name, mime, dataBase64, tags, createdBy }) {
  const data = stripDataUrl(dataBase64);
  if (!data) throw new Error("media data is required");
  const byteSize = estimateBytes(data);
  if (byteSize > MAX_MEDIA_BYTES) {
    throw new Error(`media exceeds ${MAX_MEDIA_BYTES} byte limit`);
  }
  const id = crypto.randomUUID();
  await pool.query(
    `INSERT INTO website_media (id, name, mime, data_base64, byte_size, tags, created_by)
     VALUES ($1::uuid, $2, $3, $4, $5, $6::text[], $7)`,
    [
      id,
      (name || "image").toString().slice(0, 200),
      (mime || "image/jpeg").toString().slice(0, 80),
      data,
      byteSize,
      Array.isArray(tags) ? tags.map(String) : [],
      createdBy || null,
    ],
  );
  return id;
}

/**
 * Extract inline base64 strings into website_media; replace with mediaId refs.
 * Mutates a deep clone of content.
 */
async function extractInlineImagesToMedia(pool, content, createdBy) {
  if (!isNonEmptyWebsiteContent(content)) return content;
  const out = JSON.parse(JSON.stringify(content));

  const maybeExtract = async (value, nameHint) => {
    if (typeof value === "string" && value.length > 200) {
      // Heuristic: looks like base64 / data URL
      if (
        value.startsWith("data:image") ||
        /^[A-Za-z0-9+/=\s]{200,}$/.test(value.slice(0, 400))
      ) {
        try {
          const id = await insertMedia(pool, {
            name: nameHint,
            mime: value.startsWith("data:image/png")
              ? "image/png"
              : "image/jpeg",
            dataBase64: value,
            tags: ["migrated"],
            createdBy,
          });
          return { mediaId: id };
        } catch (e) {
          console.warn("[website-cms] media extract skipped:", e.message);
          return value;
        }
      }
    }
    if (value && typeof value === "object" && value.mediaId) return value;
    return value;
  };

  if (typeof out.homeHeroImageBase64 === "string") {
    out.homeHeroImageBase64 = await maybeExtract(
      out.homeHeroImageBase64,
      "home-hero",
    );
  }

  for (const key of [
    "latestEventCollageBase64",
    "popularDishImageBase64",
    "eventDesignImageBase64",
  ]) {
    if (!Array.isArray(out[key])) continue;
    const next = [];
    for (let i = 0; i < out[key].length; i++) {
      next.push(await maybeExtract(out[key][i], `${key}-${i}`));
    }
    out[key] = next;
  }

  if (Array.isArray(out.galleryCategories)) {
    for (const cat of out.galleryCategories) {
      if (!cat || !Array.isArray(cat.images)) continue;
      for (const img of cat.images) {
        if (!img || typeof img !== "object") continue;
        if (typeof img.imageBase64 === "string" && img.imageBase64.length > 200) {
          const replaced = await maybeExtract(
            img.imageBase64,
            `gallery-${cat.id || "cat"}`,
          );
          if (replaced && typeof replaced === "object" && replaced.mediaId) {
            img.mediaId = replaced.mediaId;
            img.imageBase64 = "";
          }
        }
      }
    }
  }

  return out;
}

export function createWebsiteCmsHandlers({
  pool,
  websiteContentPath,
  logAction,
}) {
  async function migrateWebsiteContentIfNeeded() {
    try {
      const canonical = await pool.query(
        `SELECT content, updated_at FROM website_content WHERE id = $1::uuid LIMIT 1`,
        [WEBSITE_CONTENT_ROW_ID],
      );
      const canonicalRow = canonical.rows[0] || null;
      const canonicalHasContent = isNonEmptyWebsiteContent(canonicalRow?.content);

      const latestLegacy = await pool.query(
        `
        SELECT content, updated_at FROM website_content
        WHERE id <> $1::uuid
          AND content IS NOT NULL
          AND content::text NOT IN ('{}', 'null')
        ORDER BY updated_at DESC NULLS LAST, created_at DESC
        LIMIT 1
      `,
        [WEBSITE_CONTENT_ROW_ID],
      );

      const legacyRow = latestLegacy.rows[0] || null;
      if (legacyRow && isNonEmptyWebsiteContent(legacyRow.content)) {
        const canonicalUpdated = canonicalRow?.updated_at
          ? new Date(canonicalRow.updated_at).getTime()
          : 0;
        const legacyUpdated = legacyRow.updated_at
          ? new Date(legacyRow.updated_at).getTime()
          : 0;
        if (!canonicalHasContent || legacyUpdated > canonicalUpdated) {
          await writePublished(legacyRow.content, { skipRevision: true });
          console.log(
            "[website-content] Migrated latest legacy DB row → canonical id",
          );
        }
      }

      const row = await getCanonicalRow();
      if (!isNonEmptyWebsiteContent(row?.content)) {
        try {
          const raw = await fs.readFile(websiteContentPath, "utf8");
          const parsed = JSON.parse(raw);
          if (isNonEmptyWebsiteContent(parsed)) {
            await writePublished(parsed, { skipRevision: true });
            console.log(
              "[website-content] Seeded canonical row from website-content.json",
            );
          }
        } catch {
          /* optional seed file */
        }
      }

      await seedDraftIfEmpty();
    } catch (error) {
      console.warn("[website-content] migration skipped:", error.message);
    }
  }

  async function getCanonicalRow() {
    const result = await pool.query(
      `SELECT content, draft_content, draft_updated_at, published_at, published_by, updated_at
       FROM website_content WHERE id = $1::uuid LIMIT 1`,
      [WEBSITE_CONTENT_ROW_ID],
    );
    return result.rows[0] || null;
  }

  async function seedDraftIfEmpty() {
    const row = await getCanonicalRow();
    if (!row) return;
    if (
      isNonEmptyWebsiteContent(row.draft_content) ||
      !isNonEmptyWebsiteContent(row.content)
    ) {
      return;
    }
    await pool.query(
      `UPDATE website_content
       SET draft_content = content,
           draft_updated_at = COALESCE(updated_at, NOW())
       WHERE id = $1::uuid`,
      [WEBSITE_CONTENT_ROW_ID],
    );
  }

  async function writePublished(content, { publishedBy, skipRevision } = {}) {
    if (!isNonEmptyWebsiteContent(content)) {
      throw new Error("website content must be a non-empty object");
    }
    await pool.query(
      `
      INSERT INTO website_content (id, content, draft_content, created_at, updated_at, published_at, published_by, draft_updated_at)
      VALUES ($1::uuid, $2::jsonb, $2::jsonb, NOW(), NOW(), NOW(), $3, NOW())
      ON CONFLICT (id)
      DO UPDATE SET
        content = EXCLUDED.content,
        updated_at = NOW(),
        published_at = NOW(),
        published_by = EXCLUDED.published_by
    `,
      [WEBSITE_CONTENT_ROW_ID, content, publishedBy || null],
    );
    try {
      await fs.writeFile(
        websiteContentPath,
        JSON.stringify(content, null, 2),
        "utf8",
      );
    } catch (fileErr) {
      console.warn(
        "[website-content] could not update JSON backup:",
        fileErr.message,
      );
    }
    if (!skipRevision) {
      await pool.query(
        `INSERT INTO website_content_revisions (content, note, published_by)
         VALUES ($1::jsonb, $2, $3)`,
        [content, "publish", publishedBy || null],
      );
      await trimRevisions();
    }
  }

  async function writeDraft(content) {
    if (!isNonEmptyWebsiteContent(content)) {
      throw new Error("website content must be a non-empty object");
    }
    await pool.query(
      `
      INSERT INTO website_content (id, content, draft_content, created_at, updated_at, draft_updated_at)
      VALUES ($1::uuid, '{}'::jsonb, $2::jsonb, NOW(), NOW(), NOW())
      ON CONFLICT (id)
      DO UPDATE SET
        draft_content = EXCLUDED.draft_content,
        draft_updated_at = NOW()
    `,
      [WEBSITE_CONTENT_ROW_ID, content],
    );
  }

  async function trimRevisions() {
    await pool.query(
      `
      DELETE FROM website_content_revisions
      WHERE id IN (
        SELECT id FROM website_content_revisions
        ORDER BY created_at DESC
        OFFSET $1
      )
    `,
      [MAX_REVISIONS],
    );
  }

  async function readPublished() {
    await migrateWebsiteContentIfNeeded();
    const row = await getCanonicalRow();
    if (row && isNonEmptyWebsiteContent(row.content)) return row.content;
    return {};
  }

  async function readDraft() {
    await migrateWebsiteContentIfNeeded();
    await seedDraftIfEmpty();
    const row = await getCanonicalRow();
    if (row && isNonEmptyWebsiteContent(row.draft_content)) {
      return {
        content: row.draft_content,
        draftUpdatedAt: row.draft_updated_at,
        publishedAt: row.published_at,
        publishedBy: row.published_by,
      };
    }
    if (row && isNonEmptyWebsiteContent(row.content)) {
      return {
        content: row.content,
        draftUpdatedAt: row.draft_updated_at || row.updated_at,
        publishedAt: row.published_at,
        publishedBy: row.published_by,
      };
    }
    return {
      content: {},
      draftUpdatedAt: null,
      publishedAt: null,
      publishedBy: null,
    };
  }

  function register(app, { authRequired, requireRoles }) {
    const cmsRoles = (req, res, next) =>
      requireRoles(req, res, next, new Set(["super_admin"]));

    app.get("/api/website-content", async (req, res) => {
      try {
        res.set("Cache-Control", "no-store, no-cache, must-revalidate");
        const content = await readPublished();
        const row = await getCanonicalRow();
        return res.json({
          content,
          updatedAt: Date.now(),
          publishedAt: row?.published_at || null,
        });
      } catch (e) {
        console.error(e);
        return res.status(500).json({ message: "Failed to load website content" });
      }
    });

    // Legacy PUT still publishes (kept for older clients) — prefer draft + publish.
    app.put(
      "/api/website-content",
      authRequired,
      cmsRoles,
      async (req, res) => {
        try {
          const { content } = req.body || {};
          if (!content || typeof content !== "object" || Array.isArray(content)) {
            return res
              .status(400)
              .json({ message: "content object is required" });
          }
          await writeDraft(content);
          await writePublished(content, { publishedBy: req.user?.id });
          try {
            await logAction({
              userId: req.user.id,
              feature: "Website Content",
              action: "published website content (legacy put)",
            });
          } catch (logError) {
            console.warn(
              "[website-content] content saved, but audit log failed:",
              logError.message,
            );
          }
          return res.json({ ok: true, content });
        } catch (e) {
          console.error(e);
          if (/quota|too large|payload|exceeds/i.test(String(e?.message || e))) {
            return res.status(507).json({
              message:
                "Website content save exceeded storage quota. Use the media library with compressed images.",
              code: "website_content_quota_exceeded",
            });
          }
          return res
            .status(500)
            .json({ message: "Failed to save website content" });
        }
      },
    );

    app.get(
      "/api/website-content/draft",
      authRequired,
      cmsRoles,
      async (req, res) => {
        try {
          const draft = await readDraft();
          return res.json(draft);
        } catch (e) {
          console.error(e);
          return res.status(500).json({ message: "Failed to load draft" });
        }
      },
    );

    app.put(
      "/api/website-content/draft",
      authRequired,
      cmsRoles,
      async (req, res) => {
        try {
          const { content } = req.body || {};
          if (!content || typeof content !== "object" || Array.isArray(content)) {
            return res
              .status(400)
              .json({ message: "content object is required" });
          }
          await writeDraft(content);
          try {
            await logAction({
              userId: req.user.id,
              feature: "Website Content",
              action: "saved website content draft",
            });
          } catch (_) {}
          const draft = await readDraft();
          return res.json({ ok: true, ...draft });
        } catch (e) {
          console.error(e);
          if (/quota|too large|payload|exceeds/i.test(String(e?.message || e))) {
            return res.status(507).json({
              message: "Draft save exceeded storage quota.",
              code: "website_content_quota_exceeded",
            });
          }
          return res.status(500).json({ message: "Failed to save draft" });
        }
      },
    );

    app.post(
      "/api/website-content/publish",
      authRequired,
      cmsRoles,
      async (req, res) => {
        try {
          const note = (req.body?.note || "publish").toString().slice(0, 200);
          let draft = await readDraft();
          let content = draft.content;
          if (!isNonEmptyWebsiteContent(content)) {
            return res.status(400).json({ message: "Draft is empty" });
          }
          // Extract large inline images into media library before publish.
          content = await extractInlineImagesToMedia(
            pool,
            content,
            req.user?.id,
          );
          await writeDraft(content);
          await writePublished(content, { publishedBy: req.user?.id });
          // Update latest revision note if custom
          if (note && note !== "publish") {
            await pool.query(
              `UPDATE website_content_revisions
               SET note = $1
               WHERE id = (
                 SELECT id FROM website_content_revisions
                 ORDER BY created_at DESC LIMIT 1
               )`,
              [note],
            );
          }
          try {
            await logAction({
              userId: req.user.id,
              feature: "Website Content",
              action: "published website content",
            });
          } catch (_) {}
          const row = await getCanonicalRow();
          return res.json({
            ok: true,
            content,
            publishedAt: row?.published_at,
          });
        } catch (e) {
          console.error(e);
          return res.status(500).json({ message: "Failed to publish" });
        }
      },
    );

    app.get(
      "/api/website-content/revisions",
      authRequired,
      cmsRoles,
      async (req, res) => {
        try {
          const r = await pool.query(
            `SELECT id, note, published_by, created_at,
                    (content IS NOT NULL) AS has_content
             FROM website_content_revisions
             ORDER BY created_at DESC
             LIMIT $1`,
            [MAX_REVISIONS],
          );
          return res.json({ revisions: r.rows });
        } catch (e) {
          console.error(e);
          return res.status(500).json({ message: "Failed to list revisions" });
        }
      },
    );

    app.post(
      "/api/website-content/revisions/:id/restore",
      authRequired,
      cmsRoles,
      async (req, res) => {
        try {
          const r = await pool.query(
            `SELECT content FROM website_content_revisions WHERE id = $1::uuid`,
            [req.params.id],
          );
          if (!r.rows[0]) {
            return res.status(404).json({ message: "Revision not found" });
          }
          const content = r.rows[0].content;
          await writeDraft(content);
          try {
            await logAction({
              userId: req.user.id,
              feature: "Website Content",
              action: `restored revision ${req.params.id} to draft`,
            });
          } catch (_) {}
          return res.json({ ok: true, content });
        } catch (e) {
          console.error(e);
          return res.status(500).json({ message: "Failed to restore revision" });
        }
      },
    );

    app.get(
      "/api/website-media",
      authRequired,
      cmsRoles,
      async (req, res) => {
        try {
          const q = (req.query.q || "").toString().trim().toLowerCase();
          const r = await pool.query(
            `SELECT id, name, mime, byte_size, tags, created_at, created_by
             FROM website_media
             ORDER BY created_at DESC
             LIMIT 500`,
          );
          let rows = r.rows;
          if (q) {
            rows = rows.filter((row) => {
              const hay = [
                row.name,
                row.mime,
                ...(row.tags || []),
              ]
                .join(" ")
                .toLowerCase();
              return hay.includes(q);
            });
          }
          return res.json({ media: rows });
        } catch (e) {
          console.error(e);
          return res.status(500).json({ message: "Failed to list media" });
        }
      },
    );

    app.get(
      "/api/website-media/:id",
      authRequired,
      cmsRoles,
      async (req, res) => {
        try {
          const r = await pool.query(
            `SELECT id, name, mime, data_base64, byte_size, tags, created_at, created_by
             FROM website_media WHERE id = $1::uuid`,
            [req.params.id],
          );
          if (!r.rows[0]) {
            return res.status(404).json({ message: "Media not found" });
          }
          return res.json({ media: r.rows[0] });
        } catch (e) {
          console.error(e);
          return res.status(500).json({ message: "Failed to load media" });
        }
      },
    );

    // Public thumbnail/content fetch for published pages that reference mediaId
    app.get("/api/website-media/:id/public", async (req, res) => {
      try {
        const r = await pool.query(
          `SELECT id, mime, data_base64 FROM website_media WHERE id = $1::uuid`,
          [req.params.id],
        );
        if (!r.rows[0]) {
          return res.status(404).json({ message: "Media not found" });
        }
        res.set("Cache-Control", "public, max-age=86400");
        return res.json({
          id: r.rows[0].id,
          mime: r.rows[0].mime,
          dataBase64: r.rows[0].data_base64,
        });
      } catch (e) {
        console.error(e);
        return res.status(500).json({ message: "Failed to load media" });
      }
    });

    app.post(
      "/api/website-media",
      authRequired,
      cmsRoles,
      async (req, res) => {
        try {
          const { name, mime, dataBase64, tags } = req.body || {};
          if (!dataBase64) {
            return res.status(400).json({ message: "dataBase64 is required" });
          }
          const id = await insertMedia(pool, {
            name,
            mime,
            dataBase64,
            tags,
            createdBy: req.user?.id,
          });
          try {
            await logAction({
              userId: req.user.id,
              feature: "Website Content",
              action: `uploaded website media ${id}`,
            });
          } catch (_) {}
          return res.json({
            ok: true,
            media: {
              id,
              name: name || "image",
              mime: mime || "image/jpeg",
              tags: tags || [],
            },
          });
        } catch (e) {
          console.error(e);
          return res.status(400).json({ message: e.message || "Upload failed" });
        }
      },
    );

    app.delete(
      "/api/website-media/:id",
      authRequired,
      cmsRoles,
      async (req, res) => {
        try {
          await pool.query(`DELETE FROM website_media WHERE id = $1::uuid`, [
            req.params.id,
          ]);
          try {
            await logAction({
              userId: req.user.id,
              feature: "Website Content",
              action: `deleted website media ${req.params.id}`,
            });
          } catch (_) {}
          return res.json({ ok: true });
        } catch (e) {
          console.error(e);
          return res.status(500).json({ message: "Failed to delete media" });
        }
      },
    );
  }

  return {
    migrateWebsiteContentIfNeeded,
    ensureWebsiteCmsSchema: (p) => ensureWebsiteCmsSchema(p || pool),
    register,
    readPublished,
    readDraft,
  };
}
