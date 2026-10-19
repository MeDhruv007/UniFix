import bcrypt from 'bcryptjs';
import crypto from 'node:crypto';

export function hashPassword(password, rounds) {
  return bcrypt.hash(password, rounds);
}

export function verifyPassword(password, hash) {
  return bcrypt.compare(password, hash);
}

let dummyHash;
/**
 * A hash to compare against when the email is unknown, so "no such user" and
 * "wrong password" take roughly the same time.
 */
export function getDummyHash(rounds) {
  dummyHash ??= bcrypt.hash(crypto.randomBytes(16).toString('hex'), rounds);
  return dummyHash;
}

/** Random URL-safe reset token and its SHA-256 hash (only the hash is stored). */
export function newResetToken() {
  const token = crypto.randomBytes(32).toString('base64url');
  return { token, tokenHash: hashResetToken(token) };
}

export function hashResetToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}
