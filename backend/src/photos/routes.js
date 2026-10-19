import express from 'express';
import fs from 'node:fs/promises';
import { notFound, validation } from '../errors.js';
import { authenticate } from '../middleware/auth.js';
import { CONTENT_TYPES, resolvePhotoPath } from './storage.js';

/** GET /photos/<photoPath> — any authenticated user; only well-formed paths inside the uploads root. */
export function photosRouter(config) {
  const router = express.Router();
  router.use(authenticate(config));

  router.get('/*photoPath', async (req, res) => {
    const segments = req.params.photoPath;
    const rel = Array.isArray(segments) ? segments.join('/') : String(segments ?? '');
    const abs = resolvePhotoPath(config.uploadsDir, rel);
    if (!abs) throw validation('Invalid photo path.');

    const stat = await fs.stat(abs).catch(() => null);
    if (!stat?.isFile()) throw notFound('Photo not found.');

    const ext = rel.slice(rel.lastIndexOf('.') + 1);
    res.set({
      'Content-Type': CONTENT_TYPES[ext],
      'Cache-Control': 'private, max-age=86400, immutable',
      'X-Content-Type-Options': 'nosniff',
    });
    await new Promise((resolve, reject) => {
      // `root` makes send() re-check containment; rel has already passed the strict regex.
      res.sendFile(rel, { root: config.uploadsDir, dotfiles: 'deny' }, (err) => {
        if (err && !res.headersSent) reject(err.code === 'ENOENT' ? notFound('Photo not found.') : err);
        else resolve();
      });
    });
  });

  return router;
}
