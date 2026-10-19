import { createApp } from './app.js';
import { assertConfig, loadConfig } from './config.js';
import { closePool, query } from './db.js';
import { logger } from './logger.js';
import { migrate } from './migrate.js';
import { ensureUploadDirs } from './photos/storage.js';

async function waitForDb(attempts = 30) {
  for (let i = 1; ; i++) {
    try {
      await query('SELECT 1');
      return;
    } catch (err) {
      if (i >= attempts) throw err;
      logger.warn({ attempt: i }, 'Database not reachable yet, retrying in 1s');
      await new Promise((r) => setTimeout(r, 1000));
    }
  }
}

async function main() {
  const config = loadConfig();
  assertConfig(config);
  await waitForDb();
  await migrate();
  await ensureUploadDirs(config.uploadsDir);

  const app = createApp(config);
  const server = app.listen(config.port, () => {
    logger.info({ port: config.port }, 'UniFix API listening');
  });

  const shutdown = (signal) => {
    logger.info({ signal }, 'Shutting down');
    server.close(() => {
      closePool().finally(() => process.exit(0));
    });
    setTimeout(() => process.exit(1), 10_000).unref();
  };
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}

main().catch((err) => {
  logger.fatal({ err }, 'Failed to start');
  process.exit(1);
});
