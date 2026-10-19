import { verifyToken } from '../auth/tokens.js';
import { accountDisabled, forbidden, unauthenticated } from '../errors.js';
import { isUuid } from '../domain.js';
import { findUserById } from '../users.js';

/**
 * Requires `Authorization: Bearer <JWT>`. The token only identifies the user; the user row
 * (role, isActive) is re-read from the DB on every request and is authoritative.
 */
export function authenticate(config) {
  return async (req, _res, next) => {
    const header = req.get('authorization') ?? '';
    const match = /^Bearer\s+(\S+)$/i.exec(header);
    if (!match) throw unauthenticated('Please sign in to continue.');
    const userId = verifyToken(match[1], config);
    if (!userId || !isUuid(userId)) throw unauthenticated('Your session has expired. Please sign in again.');
    const user = await findUserById(userId);
    if (!user) throw unauthenticated('Your session has expired. Please sign in again.');
    if (!user.is_active) throw accountDisabled();
    req.user = user;
    next();
  };
}

export function requireAdmin(req, _res, next) {
  if (req.user?.role !== 'admin') throw forbidden('Only facilities admins can do that.');
  next();
}
