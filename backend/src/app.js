import express from 'express';
import helmet from 'helmet';
import { pinoHttp } from 'pino-http';
import { authRouter } from './auth/routes.js';
import { meRouter } from './auth/me.js';
import { assertConfig, loadConfig } from './config.js';
import { query } from './db.js';
import { AppError } from './errors.js';
import { issuesRouter } from './issues/routes.js';
import { logger } from './logger.js';
import { errorHandler, notFoundHandler } from './middleware/errors.js';
import { photosRouter } from './photos/routes.js';
import { staffRouter } from './staff/routes.js';

export const API_PREFIX = '/api/v1';

// Only local browser origins (the Flutter web dev server) are allowed; the
// Android app does not use CORS. Auth is a bearer header, not cookies.
const LOCAL_ORIGIN = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d{1,5})?$/;

function devCors(req, res, next) {
  const origin = req.headers.origin;
  if (origin && LOCAL_ORIGIN.test(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, OPTIONS');
    res.setHeader('Access-Control-Max-Age', '600');
    if (req.method === 'OPTIONS') return res.status(204).end();
  }
  next();
}

/** Builds the Express app. Does not listen, migrate or touch the filesystem (see server.js). */
export function createApp(config = loadConfig()) {
  assertConfig(config);

  const app = express();
  app.disable('x-powered-by');
  // Photos are fetched cross-origin by the web build (localhost:<port>).
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  app.use(devCors);
  app.use(
    pinoHttp({
      logger,
      customLogLevel: (_req, res, err) => (err || res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info'),
      // Log only method/url/status: never headers (Authorization) or bodies (passwords).
      serializers: {
        req: (req) => ({ id: req.id, method: req.method, url: req.url }),
        res: (res) => ({ statusCode: res.statusCode }),
      },
    }),
  );
  app.use(express.json({ limit: '100kb' }));

  const api = express.Router();

  api.get('/health', async (_req, res) => {
    try {
      await query('SELECT 1');
    } catch {
      throw new AppError(503, 'INTERNAL', 'The service is temporarily unavailable.');
    }
    res.json({ status: 'ok' });
  });

  api.use('/auth', authRouter(config));
  api.use('/me', meRouter(config));
  api.use('/issues', issuesRouter(config));
  api.use('/photos', photosRouter(config));
  api.use('/staff', staffRouter(config));

  app.use(API_PREFIX, api);
  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}
