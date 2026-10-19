import crypto from 'node:crypto';
import express from 'express';
import { query, withTransaction } from '../db.js';
import { CAMPUS_ID, CATEGORIES, LIMITS, canTransition, isUuid } from '../domain.js';
import { conflict, forbidden, invalidTransition, notFound, validation } from '../errors.js';
import { authenticate, requireAdmin } from '../middleware/auth.js';
import { parse, validateBody, validateQuery } from '../middleware/validate.js';
import {
  movePhoto,
  newPhotoPath,
  photoUpload,
  removeEmptyIssueDirs,
  removeFiles,
  removePhotos,
  verifyImages,
} from '../photos/storage.js';
import {
  assignSchema,
  createIssueSchema,
  feedbackSchema,
  listIssuesQuery,
  priorityChangeSchema,
  statsQuery,
  statusChangeSchema,
} from './schemas.js';
import {
  FEEDBACK_COLUMNS,
  issueColumns,
  UPDATE_COLUMNS,
  toFeedback,
  toIssue,
  toIssueUpdate,
  toStats,
} from './serialize.js';

const ISSUE_NOT_FOUND = 'This issue could not be found.';
const OPEN_STATUSES_SQL = "status IN ('reported', 'inProgress', 'reopened')";

/** Escapes LIKE metacharacters so user input only ever matches literally (backslash is the escape). */
export const escapeLike = (s) => s.replace(/[\\%_]/g, (c) => '\\' + c);

/**
 * Issue number a search term refers to, or null: strips a leading "FMC-" (any case) and leading
 * zeros; the remainder must be 1-9 digits (fits an integer). "FMC-0483", "0483", "483" -> 483.
 */
export function searchNumber(q) {
  const rest = q.replace(/^fmc-/i, '').replace(/^0+/, '');
  return /^\d{1,9}$/.test(rest) ? Number.parseInt(rest, 10) : null;
}

async function getIssue(id, viewerId, client = { query }, { forUpdate = false } = {}) {
  const { rows } = await client.query(
    `SELECT ${issueColumns('$3')} FROM issues WHERE id = $1 AND campus_id = $2${forUpdate ? ' FOR UPDATE' : ''}`,
    [id, CAMPUS_ID, viewerId],
  );
  if (!rows[0]) throw notFound(ISSUE_NOT_FOUND);
  return rows[0];
}

async function insertUpdate(client, u) {
  await client.query(
    `INSERT INTO issue_updates
       (issue_id, actor_id, action, old_status, new_status, old_priority, new_priority, note)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
    [
      u.issueId,
      u.actorId,
      u.action,
      u.oldStatus ?? null,
      u.newStatus ?? null,
      u.oldPriority ?? null,
      u.newPriority ?? null,
      u.note ?? null,
    ],
  );
}

export function issuesRouter(config) {
  const router = express.Router();
  const { uploadsDir } = config;

  router.use(authenticate(config));

  // Unknown or malformed ids are simply "not found".
  router.param('id', (_req, _res, next, id) => {
    next(isUuid(id) ? undefined : notFound(ISSUE_NOT_FOUND));
  });

  // ---- List -------------------------------------------------------------------------------
  router.get('/', validateQuery(listIssuesQuery), async (req, res) => {
    const { status, category, mine, q, open, priority, assigned, assignedToMe, sort, limit, offset } =
      req.validatedQuery;
    const where = ['campus_id = $1'];
    const params = [CAMPUS_ID];
    if (status) {
      params.push(status);
      where.push(`status = $${params.length}`);
    }
    if (category) {
      params.push(category);
      where.push(`category = $${params.length}`);
    }
    if (mine) {
      params.push(req.user.id);
      where.push(`reporter_id = $${params.length}`);
    }
    if (open) where.push(OPEN_STATUSES_SQL);
    if (priority) {
      params.push(priority);
      where.push(`priority = $${params.length}`);
    }
    if (assigned !== undefined) where.push(assigned ? 'assigned_to IS NOT NULL' : 'assigned_to IS NULL');
    if (assignedToMe) {
      params.push(req.user.id);
      where.push(`assigned_to = $${params.length}`);
    }
    if (q) {
      // Parameterized: the term is only ever a bound value, with LIKE wildcards escaped.
      params.push(`%${escapeLike(q)}%`);
      const p = `$${params.length}`;
      const ors = [`title ILIKE ${p}`, `location_detail ILIKE ${p}`, `building_id ILIKE ${p}`];
      const n = searchNumber(q);
      if (n !== null) {
        params.push(n);
        ors.push(`number = $${params.length}`);
      }
      where.push(`(${ors.join(' OR ')})`);
    }
    const whereSql = where.join(' AND ');
    const order =
      sort === 'oldest'
        ? 'created_at ASC, number ASC'
        : sort === 'popular'
          ? 'upvote_count DESC, created_at DESC, id DESC'
          : 'created_at DESC, number DESC';
    const [items, count] = await Promise.all([
      query(
        `SELECT ${issueColumns(`$${params.length + 3}`)} FROM issues WHERE ${whereSql}
         ORDER BY ${order}
         LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
        [...params, limit, offset, req.user.id],
      ),
      query(`SELECT count(*)::int AS total FROM issues WHERE ${whereSql}`, params),
    ]);
    res.json({ items: items.rows.map(toIssue), total: count.rows[0].total });
  });

  // ---- Stats (must be registered before /:id) ---------------------------------------------
  // Admin: whole campus. Anyone with mine=true: only the caller's reports. Student without mine -> 403.
  router.get('/stats', validateQuery(statsQuery), async (req, res) => {
    const { mine } = req.validatedQuery;
    if (!mine && req.user.role !== 'admin') throw forbidden('Only facilities admins can do that.');
    const params = [CAMPUS_ID];
    let whereSql = 'campus_id = $1';
    if (mine) {
      params.push(req.user.id);
      whereSql += ' AND reporter_id = $2';
    }
    const [agg, byCategory] = await Promise.all([
      query(
        `SELECT
           count(*) FILTER (WHERE status = 'reported')::int   AS reported,
           count(*) FILTER (WHERE status = 'inProgress')::int AS in_progress,
           count(*) FILTER (WHERE status = 'resolved')::int   AS resolved,
           count(*) FILTER (WHERE status = 'reopened')::int   AS reopened,
           count(*)::int                                      AS total,
           count(*) FILTER (WHERE ${OPEN_STATUSES_SQL})::int AS open,
           count(*) FILTER (WHERE ${OPEN_STATUSES_SQL} AND priority = 'urgent')::int AS urgent,
           count(*) FILTER (WHERE ${OPEN_STATUSES_SQL} AND assigned_to IS NULL)::int AS unassigned,
           count(*) FILTER (WHERE ${OPEN_STATUSES_SQL} AND assigned_to = $${params.length + 1})::int AS assigned_to_me,
           count(*) FILTER (WHERE created_at >= now() - interval '24 hours')::int    AS created_last_24h,
           count(*) FILTER (WHERE resolved_at >= now() - interval '7 days')::int     AS resolved_this_week,
           round((avg(extract(epoch FROM resolved_at - created_at))
                    FILTER (WHERE status = 'resolved') / 3600)::numeric, 1)         AS avg_resolution_hours
         FROM issues WHERE ${whereSql}`,
        [...params, req.user.id],
      ),
      query(
        `SELECT category, count(*)::int AS n FROM issues
         WHERE ${whereSql} AND ${OPEN_STATUSES_SQL} GROUP BY category`,
        params,
      ),
    ]);
    res.json(toStats(agg.rows[0], byCategory.rows, CATEGORIES));
  });

  // ---- Create -----------------------------------------------------------------------------
  router.post('/', photoUpload(uploadsDir, LIMITS.photosPerIssue), async (req, res) => {
    const files = req.files ?? [];
    const issueId = crypto.randomUUID();
    const moved = [];
    try {
      const input = parse(createIssueSchema, req.body ?? {});
      const images = await verifyImages(files);
      const row = await withTransaction(async (client) => {
        for (const { file, ext } of images) {
          const rel = newPhotoPath(issueId, 'report', ext);
          await movePhoto(uploadsDir, file.path, rel);
          moved.push(rel);
        }
        const { rows } = await client.query(
          `INSERT INTO issues (id, campus_id, title, description, category, building_id, location_detail,
                               photo_paths, reporter_id, reporter_display_name, status, priority)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'reported', 'medium')
           RETURNING ${issueColumns('$9')}`,
          [
            issueId,
            CAMPUS_ID,
            input.title,
            input.description,
            input.category,
            input.buildingId,
            input.locationDetail,
            moved,
            req.user.id,
            req.user.display_name,
          ],
        );
        await insertUpdate(client, {
          issueId,
          actorId: req.user.id,
          action: 'created',
          newStatus: 'reported',
          newPriority: 'medium',
        });
        return rows[0];
      });
      res.status(201).json(toIssue(row));
    } catch (err) {
      if (moved.length) {
        await removePhotos(uploadsDir, moved);
        await removeEmptyIssueDirs(uploadsDir, issueId);
      }
      throw err;
    } finally {
      // Temp uploads that were never moved (validation failure, rejected type, ...).
      await removeFiles(files.map((f) => f.path));
    }
  });

  // ---- Read -------------------------------------------------------------------------------
  router.get('/:id', async (req, res) => {
    res.json(toIssue(await getIssue(req.params.id, req.user.id)));
  });

  router.get('/:id/updates', async (req, res) => {
    await getIssue(req.params.id, req.user.id);
    const { rows } = await query(
      `SELECT ${UPDATE_COLUMNS} FROM issue_updates WHERE issue_id = $1 ORDER BY created_at ASC, seq ASC`,
      [req.params.id],
    );
    res.json(rows.map(toIssueUpdate));
  });

  // ---- Admin: status ----------------------------------------------------------------------
  router.patch('/:id/status', requireAdmin, validateBody(statusChangeSchema), async (req, res) => {
    const { from, to, note } = req.body;
    // Transition first (422), then note (400), then staleness (409) — docs/API.md.
    if (!canTransition(from, to)) {
      throw invalidTransition(`An issue cannot move from "${from}" to "${to}".`);
    }
    if (to === 'resolved' && !note) throw validation('A resolution note is required to resolve an issue.');
    const row = await withTransaction(async (client) => {
      const current = await getIssue(req.params.id, req.user.id, client, { forUpdate: true });
      if (current.status !== from) {
        throw conflict('This issue was updated by someone else. Refresh and try again.');
      }
      let sql;
      if (to === 'resolved') {
        sql = `UPDATE issues SET status = $2, resolved_at = now(), resolution_note = $3 WHERE id = $1`;
      } else if (to === 'reopened') {
        sql = `UPDATE issues SET status = $2, resolved_at = NULL, reopen_count = reopen_count + 1 WHERE id = $1`;
      } else {
        sql = `UPDATE issues SET status = $2 WHERE id = $1`;
      }
      const params = to === 'resolved' ? [current.id, to, note] : [current.id, to];
      params.push(req.user.id);
      const { rows } = await client.query(`${sql} RETURNING ${issueColumns(`$${params.length}`)}`, params);
      await insertUpdate(client, {
        issueId: current.id,
        actorId: req.user.id,
        action: to === 'reopened' ? 'reopened' : 'statusChanged',
        oldStatus: from,
        newStatus: to,
        note,
      });
      return rows[0];
    });
    res.json(toIssue(row));
  });

  // ---- Admin: priority --------------------------------------------------------------------
  router.patch('/:id/priority', requireAdmin, validateBody(priorityChangeSchema), async (req, res) => {
    const { from, to } = req.body;
    if (from === to) throw validation('The new priority must be different from the current one.');
    const row = await withTransaction(async (client) => {
      const current = await getIssue(req.params.id, req.user.id, client, { forUpdate: true });
      if (current.priority !== from) {
        throw conflict('This issue was updated by someone else. Refresh and try again.');
      }
      const { rows } = await client.query(
        `UPDATE issues SET priority = $2 WHERE id = $1 RETURNING ${issueColumns('$3')}`,
        [current.id, to, req.user.id],
      );
      await insertUpdate(client, {
        issueId: current.id,
        actorId: req.user.id,
        action: 'priorityChanged',
        oldPriority: from,
        newPriority: to,
      });
      return rows[0];
    });
    res.json(toIssue(row));
  });

  // ---- Admin: assign / reassign / unassign ------------------------------------------------
  // Body optional: no assigneeId -> the caller; an active admin's id -> them; null -> unassign.
  router.post('/:id/assign', requireAdmin, validateBody(assignSchema), async (req, res) => {
    const { assigneeId } = req.body;
    const row = await withTransaction(async (client) => {
      const current = await getIssue(req.params.id, req.user.id, client, { forUpdate: true });
      let assignee = null;
      if (assigneeId === undefined) {
        assignee = { id: req.user.id, display_name: req.user.display_name };
      } else if (assigneeId !== null) {
        const { rows } = await client.query(
          `SELECT id, display_name FROM users
           WHERE id = $1 AND campus_id = $2 AND role = 'admin' AND is_active FOR SHARE`,
          [assigneeId, CAMPUS_ID],
        );
        if (!rows[0]) throw validation('Issues can only be assigned to an active facilities admin.');
        assignee = rows[0];
      }
      const newId = assignee?.id ?? null;
      if (current.assigned_to === newId) return current; // nothing changes: no update, no history
      const { rows } = await client.query(
        `UPDATE issues SET assigned_to = $2 WHERE id = $1 RETURNING ${issueColumns('$3')}`,
        [current.id, newId, req.user.id],
      );
      await insertUpdate(client, {
        issueId: current.id,
        actorId: req.user.id,
        action: 'assigned',
        note: assignee ? `Assigned to ${assignee.display_name}` : 'Unassigned',
      });
      return rows[0];
    });
    res.json(toIssue(row));
  });

  // ---- Admin: resolution photos -----------------------------------------------------------
  router.post(
    '/:id/resolution-photos',
    requireAdmin,
    async (req, _res, next) => {
      await getIssue(req.params.id, req.user.id); // 404 before accepting any upload bytes
      next();
    },
    photoUpload(uploadsDir, LIMITS.resolutionPhotos),
    async (req, res) => {
      const files = req.files ?? [];
      const moved = [];
      try {
        if (files.length === 0) throw validation('Attach at least one photo.');
        const images = await verifyImages(files);
        const row = await withTransaction(async (client) => {
          const current = await getIssue(req.params.id, req.user.id, client, { forUpdate: true });
          if (current.resolution_photo_paths.length + images.length > LIMITS.resolutionPhotos) {
            throw validation(`An issue can have at most ${LIMITS.resolutionPhotos} resolution photos.`);
          }
          for (const { file, ext } of images) {
            const rel = newPhotoPath(current.id, 'resolution', ext);
            await movePhoto(uploadsDir, file.path, rel);
            moved.push(rel);
          }
          const { rows } = await client.query(
            `UPDATE issues SET resolution_photo_paths = resolution_photo_paths || $2::text[]
             WHERE id = $1 RETURNING ${issueColumns('$3')}`,
            [current.id, moved, req.user.id],
          );
          await insertUpdate(client, {
            issueId: current.id,
            actorId: req.user.id,
            action: 'commented',
            note: `Added ${moved.length} resolution photo${moved.length === 1 ? '' : 's'}.`,
          });
          return rows[0];
        });
        res.json(toIssue(row));
      } catch (err) {
        if (moved.length) await removePhotos(uploadsDir, moved);
        throw err;
      } finally {
        await removeFiles(files.map((f) => f.path));
      }
    },
  );

  // ---- Upvotes ("me too") -----------------------------------------------------------------
  router.post('/:id/upvote', async (req, res) => {
    const issue = await getIssue(req.params.id, req.user.id);
    if (issue.reporter_id === req.user.id) throw validation('You reported this issue.');
    if (issue.status === 'resolved') throw conflict('This issue is already resolved.');
    await query(
      `INSERT INTO issue_upvotes (issue_id, user_id) VALUES ($1, $2) ON CONFLICT (issue_id, user_id) DO NOTHING`,
      [issue.id, req.user.id],
    );
    res.json(toIssue(await getIssue(issue.id, req.user.id)));
  });

  router.delete('/:id/upvote', async (req, res) => {
    const issue = await getIssue(req.params.id, req.user.id);
    await query('DELETE FROM issue_upvotes WHERE issue_id = $1 AND user_id = $2', [issue.id, req.user.id]);
    res.json(toIssue(await getIssue(issue.id, req.user.id)));
  });

  // ---- Reporter feedback ------------------------------------------------------------------
  router.get('/:id/feedback/me', async (req, res) => {
    const issue = await getIssue(req.params.id, req.user.id);
    if (issue.reporter_id !== req.user.id) throw forbidden('Only the reporter can view feedback for this issue.');
    const { rows } = await query(
      `SELECT ${FEEDBACK_COLUMNS} FROM issue_feedback WHERE issue_id = $1 AND reporter_id = $2`,
      [issue.id, req.user.id],
    );
    if (!rows[0]) throw notFound('No feedback has been given for this issue yet.');
    res.json(toFeedback(rows[0]));
  });

  router.post('/:id/feedback', validateBody(feedbackSchema), async (req, res) => {
    const { stillExists, comment } = req.body;
    const issue = await getIssue(req.params.id, req.user.id);
    if (issue.reporter_id !== req.user.id) throw forbidden('Only the reporter can give feedback on this issue.');
    if (issue.status !== 'resolved') throw conflict('Feedback can only be given once the issue is resolved.');
    // "Still exists" also reopens the issue (same transaction) so facilities sees it back in the queue.
    const row = await withTransaction(async (client) => {
      const { rows } = await client.query(
        `INSERT INTO issue_feedback (issue_id, reporter_id, still_exists, comment)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (issue_id, reporter_id) DO NOTHING
         RETURNING ${FEEDBACK_COLUMNS}`,
        [issue.id, req.user.id, stillExists, comment ?? null],
      );
      if (!rows[0]) throw conflict('You have already given feedback on this issue.');
      if (stillExists) {
        await client.query(
          `UPDATE issues SET status = 'reopened', resolved_at = NULL, reopen_count = reopen_count + 1 WHERE id = $1`,
          [issue.id],
        );
        await insertUpdate(client, {
          issueId: issue.id,
          actorId: req.user.id,
          action: 'reopened',
          oldStatus: 'resolved',
          newStatus: 'reopened',
          note: comment || 'Reporter says the problem is still there.',
        });
      }
      return rows[0];
    });
    res.status(201).json(toFeedback(row));
  });

  return router;
}
