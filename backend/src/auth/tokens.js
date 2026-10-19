import jwt from 'jsonwebtoken';

/** JWT payload is `{ sub: userId, role }` (API.md). The role claim is informational only. */
export function signToken(user, config) {
  return jwt.sign({ sub: user.id, role: user.role }, config.jwtSecret, {
    algorithm: 'HS256',
    expiresIn: config.jwtExpiresIn,
  });
}

/** Returns the user id from a valid token, or null for anything invalid/expired. */
export function verifyToken(token, config) {
  try {
    const payload = jwt.verify(token, config.jwtSecret, { algorithms: ['HS256'] });
    return typeof payload === 'object' && typeof payload.sub === 'string' ? payload.sub : null;
  } catch {
    return null;
  }
}
