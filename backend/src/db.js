import pg from 'pg';
import { logger } from './logger.js';

// Return BIGINT/COUNT as JS numbers (counts here are far below 2^53).
pg.types.setTypeParser(20, (v) => Number.parseInt(v, 10));

let pool;

/**
 * Lazily created pool. Uses DATABASE_URL when set, otherwise the standard libpq
 * env vars (PGHOST, PGUSER, PGPASSWORD, PGDATABASE, PGPORT) which `pg` reads itself.
 */
export function getPool() {
  if (!pool) {
    pool = new pg.Pool({
      connectionString: process.env.DATABASE_URL || undefined,
      max: Number.parseInt(process.env.PG_POOL_MAX ?? '10', 10),
    });
    pool.on('error', (err) => logger.error({ err }, 'Idle PostgreSQL client error'));
  }
  return pool;
}

export function query(text, params) {
  return getPool().query(text, params);
}

/** Runs fn(client) inside BEGIN/COMMIT; rolls back and rethrows on any error. */
export async function withTransaction(fn) {
  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch (rollbackErr) {
      logger.error({ err: rollbackErr }, 'Rollback failed');
    }
    throw err;
  } finally {
    client.release();
  }
}

export async function closePool() {
  if (pool) {
    const p = pool;
    pool = undefined;
    await p.end();
  }
}
