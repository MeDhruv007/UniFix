import express from 'express';
import { query } from '../db.js';
import { CAMPUS_ID } from '../domain.js';
import { STAFF_COLUMNS, toStaff } from '../issues/serialize.js';
import { authenticate, requireAdmin } from '../middleware/auth.js';

/** GET /staff (admin): active admins of the campus, sorted by name (API.md v1.1 "Staff"). */
export function staffRouter(config) {
  const router = express.Router();
  router.use(authenticate(config), requireAdmin);

  router.get('/', async (_req, res) => {
    const { rows } = await query(
      `SELECT ${STAFF_COLUMNS} FROM users
       WHERE campus_id = $1 AND role = 'admin' AND is_active
       ORDER BY lower(display_name), display_name, id`,
      [CAMPUS_ID],
    );
    res.json(rows.map(toStaff));
  });

  return router;
}
