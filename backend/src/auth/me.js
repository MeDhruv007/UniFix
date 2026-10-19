import express from 'express';
import { query } from '../db.js';
import { AVATARS, LIMITS } from '../domain.js';
import { z } from 'zod';
import { body, optionalText, requiredText, validateBody } from '../middleware/validate.js';
import { authenticate } from '../middleware/auth.js';
import { USER_COLUMNS, toUser } from '../users.js';

// Only displayName, department and avatar are editable; other keys are stripped.
const patchMeSchema = body({
  displayName: requiredText('Display name', LIMITS.displayName).optional(),
  department: optionalText('Department', LIMITS.department),
  avatar: z
    .enum(AVATARS, { error: 'Unknown avatar.' })
    .nullable()
    .optional(),
});

export function meRouter(config) {
  const router = express.Router();
  router.use(authenticate(config));

  router.get('/', (req, res) => {
    res.json(toUser(req.user));
  });

  router.patch('/', validateBody(patchMeSchema), async (req, res) => {
    const { displayName, department, avatar } = req.body;
    const sets = [];
    const params = [];
    if (displayName !== undefined) {
      params.push(displayName);
      sets.push(`display_name = $${params.length}`);
    }
    if (department !== undefined) {
      params.push(department);
      sets.push(`department = $${params.length}`);
    }
    if (avatar !== undefined) {
      params.push(avatar);
      sets.push(`avatar = $${params.length}`);
    }
    if (sets.length === 0) return res.json(toUser(req.user));
    params.push(req.user.id);
    const { rows } = await query(
      `UPDATE users SET ${sets.join(', ')} WHERE id = $${params.length} RETURNING ${USER_COLUMNS}`,
      params,
    );
    res.json(toUser(rows[0]));
  });

  return router;
}
