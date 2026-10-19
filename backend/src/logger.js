import pino from 'pino';
import { loadConfig } from './config.js';

export const logger = pino({
  level: loadConfig().logLevel,
  redact: {
    paths: [
      'req.headers.authorization',
      'req.headers.cookie',
      'res.headers["set-cookie"]',
      '*.password',
      '*.passwordHash',
      '*.password_hash',
      '*.token',
    ],
    censor: '[redacted]',
  },
});
