import express from 'express';
import { rateLimit } from 'express-rate-limit';
import { z } from 'zod';
import { query, withTransaction } from '../db.js';
import { LIMITS } from '../domain.js';
import { AppError, accountDisabled, conflict, unauthenticated, validation } from '../errors.js';
import { logger } from '../logger.js';
import { body, emailField, optionalText, parse, requiredText, validateBody } from '../middleware/validate.js';
import { USER_COLUMNS, toUser } from '../users.js';
import { getDummyHash, hashPassword, hashResetToken, newResetToken, verifyPassword } from './passwords.js';
import { signToken } from './tokens.js';

const RESET_TOKEN_TTL_MINUTES = 30;
const BAD_CREDENTIALS = 'Incorrect email or password.';

const newPassword = (label) =>
  z
    .string({ error: (iss) => (iss.input == null ? `${label} is required.` : `${label} must be text.`) })
    .min(LIMITS.passwordMin, `${label} must be at least ${LIMITS.passwordMin} characters.`)
    .refine((p) => Buffer.byteLength(p, 'utf8') <= LIMITS.passwordMaxBytes, `${label} is too long.`);

const registerSchema = body({
  displayName: requiredText('Display name', LIMITS.displayName),
  email: emailField,
  password: newPassword('Password'),
  department: optionalText('Department', LIMITS.department),
  // Any other key (notably `role`) is stripped by zod and never reaches the DB.
});

const loginSchema = body({
  email: emailField,
  password: z.string({ error: 'Password is required.' }).min(1, 'Password is required.'),
});

const resetConfirmSchema = body({
  token: z.string({ error: 'Reset token is required.' }).trim().min(1, 'Reset token is required.').max(200),
  newPassword: newPassword('New password'),
});

export function authRouter(config) {
  const router = express.Router();

  if (config.authRateLimit > 0) {
    router.use(
      rateLimit({
        windowMs: 15 * 60 * 1000,
        limit: config.authRateLimit,
        standardHeaders: 'draft-8',
        legacyHeaders: false,
        handler: (_req, _res, next) =>
          next(new AppError(429, 'RATE_LIMITED', 'Too many attempts. Please wait a few minutes and try again.')),
      }),
    );
  }

  router.post('/register', validateBody(registerSchema), async (req, res) => {
    const { displayName, email, password, department } = req.body;
    const passwordHash = await hashPassword(password, config.bcryptRounds);
    // role and campus_id come from column defaults ('student', 'adit-main'), never from the client.
    const { rows } = await query(
      `INSERT INTO users (email, password_hash, display_name, department)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (email) DO NOTHING
       RETURNING ${USER_COLUMNS}`,
      [email, passwordHash, displayName, department ?? null],
    );
    if (rows.length === 0) throw conflict('An account with this email already exists.');
    const user = rows[0];
    res.status(201).json({ token: signToken(user, config), user: toUser(user) });
  });

  router.post('/login', validateBody(loginSchema), async (req, res) => {
    const { email, password } = req.body;
    const { rows } = await query(`SELECT ${USER_COLUMNS}, password_hash FROM users WHERE email = $1`, [email]);
    const user = rows[0];
    const ok = await verifyPassword(password, user?.password_hash ?? (await getDummyHash(config.bcryptRounds)));
    if (!user || !ok) throw unauthenticated(BAD_CREDENTIALS);
    if (!user.is_active) throw accountDisabled();
    res.json({ token: signToken(user, config), user: toUser(user) });
  });

  // Always 204 so the response never reveals whether an account exists.
  router.post('/password-reset', async (req, res) => {
    let email;
    try {
      ({ email } = parse(body({ email: emailField }), req.body ?? {}));
    } catch {
      return res.status(204).end();
    }
    const { rows } = await query('SELECT id FROM users WHERE email = $1 AND is_active', [email]);
    if (rows[0]) {
      const { token, tokenHash } = newResetToken();
      const { rows: inserted } = await query(
        `INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
         VALUES ($1, $2, now() + make_interval(mins => $3))
         RETURNING expires_at`,
        [rows[0].id, tokenHash, RESET_TOKEN_TTL_MINUTES],
      );
      // v1 has no mail server (API.md): the token is written to stdout on purpose.
      // Logged via console, not the request logger, so it is not subject to log redaction.
      if (config.env !== 'test') {
        console.log(
          `[password-reset] userId=${rows[0].id} resetToken=${token} expiresAt=${inserted[0].expires_at.toISOString()}`,
        );
      }
      logger.info({ userId: rows[0].id }, 'Password reset token issued');
    }
    res.status(204).end();
  });

  // Extension (not in API.md v1): redeem a logged reset token. 204 on success.
  router.post('/password-reset/confirm', validateBody(resetConfirmSchema), async (req, res) => {
    const { token, newPassword: password } = req.body;
    const passwordHash = await hashPassword(password, config.bcryptRounds);
    const updated = await withTransaction(async (client) => {
      const { rows } = await client.query(
        `UPDATE password_reset_tokens SET used_at = now()
         WHERE token_hash = $1 AND used_at IS NULL AND expires_at > now()
         RETURNING user_id`,
        [hashResetToken(token)],
      );
      if (!rows[0]) return false;
      await client.query('UPDATE users SET password_hash = $1 WHERE id = $2', [passwordHash, rows[0].user_id]);
      // Invalidate any other outstanding tokens for this user.
      await client.query(
        'UPDATE password_reset_tokens SET used_at = now() WHERE user_id = $1 AND used_at IS NULL',
        [rows[0].user_id],
      );
      return true;
    });
    if (!updated) throw validation('This reset code is invalid or has expired.');
    res.status(204).end();
  });

  return router;
}
