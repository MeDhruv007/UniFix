import path from 'node:path';

function int(name, fallback) {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return fallback;
  const n = Number.parseInt(raw, 10);
  if (!Number.isFinite(n)) throw new Error(`Environment variable ${name} must be an integer.`);
  return n;
}

/**
 * Reads configuration from the environment. Evaluated lazily (per call) so tests can
 * set env vars before the app is built.
 */
export function loadConfig() {
  const env = process.env.NODE_ENV ?? 'development';
  return {
    env,
    port: int('PORT', 3000),
    jwtSecret: process.env.JWT_SECRET ?? '',
    jwtExpiresIn: '7d',
    bcryptRounds: int('BCRYPT_ROUNDS', 12),
    uploadsDir: path.resolve(process.env.UPLOADS_DIR ?? './uploads'),
    // Max requests per 15 minutes per IP on /auth/*. 0 disables the limiter.
    authRateLimit: int('AUTH_RATE_LIMIT', 50),
    logLevel: process.env.LOG_LEVEL ?? (env === 'test' ? 'silent' : 'info'),
    campusId: 'adit-main',
  };
}

export function assertConfig(config) {
  if (!config.jwtSecret || config.jwtSecret.length < 32) {
    throw new Error('JWT_SECRET must be set and at least 32 characters long.');
  }
}
