import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import multer from 'multer';
import { LIMITS } from '../domain.js';
import { AppError, payloadTooLarge, validation } from '../errors.js';

export const PHOTO_FIELD = 'photos';

/** Only server-generated paths of exactly this shape are ever stored or served. */
export const PHOTO_PATH_RE =
  /^issues\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\/(report|resolution)\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$/;

export const CONTENT_TYPES = { jpg: 'image/jpeg', png: 'image/png', webp: 'image/webp' };

export const tmpDir = (uploadsDir) => path.join(uploadsDir, '.tmp');

export async function ensureUploadDirs(uploadsDir) {
  await fs.mkdir(tmpDir(uploadsDir), { recursive: true });
}

/**
 * Detects the image type from the file signature (magic bytes), ignoring the client's
 * filename and Content-Type. Returns 'jpg' | 'png' | 'webp' | null.
 */
export function detectImageType(buf) {
  if (!buf || buf.length < 3) return null;
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'jpg';
  if (
    buf.length >= 8 &&
    buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
  ) {
    return 'png';
  }
  if (
    buf.length >= 12 &&
    buf.subarray(0, 4).toString('latin1') === 'RIFF' &&
    buf.subarray(8, 12).toString('latin1') === 'WEBP'
  ) {
    return 'webp';
  }
  return null;
}

export async function detectFileImageType(filePath) {
  const handle = await fs.open(filePath, 'r');
  try {
    const buf = Buffer.alloc(12);
    const { bytesRead } = await handle.read(buf, 0, 12, 0);
    return detectImageType(buf.subarray(0, bytesRead));
  } finally {
    await handle.close();
  }
}

/** Verifies every uploaded file is a real JPEG/PNG/WebP; returns [{ file, ext }]. */
export async function verifyImages(files) {
  const out = [];
  for (const file of files) {
    const ext = await detectFileImageType(file.path);
    if (!ext) throw validation('Photos must be JPEG, PNG or WebP images.');
    out.push({ file, ext });
  }
  return out;
}

/** Relative storage path for a new photo; the file name is a server-generated UUID. */
export function newPhotoPath(issueId, kind, ext) {
  return `issues/${issueId}/${kind}/${crypto.randomUUID()}.${ext}`;
}

/**
 * Resolves a relative photo path to an absolute path inside uploadsDir, or returns null if
 * the path is not a well-formed photo path or would escape the uploads root.
 */
export function resolvePhotoPath(uploadsDir, relPath) {
  if (typeof relPath !== 'string' || !PHOTO_PATH_RE.test(relPath)) return null;
  const root = path.resolve(uploadsDir);
  const abs = path.resolve(root, relPath);
  if (!abs.startsWith(root + path.sep)) return null;
  return abs;
}

/** Moves a temp upload to its final relative path (same volume, so rename is atomic). */
export async function movePhoto(uploadsDir, tmpPath, relPath) {
  const abs = resolvePhotoPath(uploadsDir, relPath);
  if (!abs) throw new Error(`Refusing to write outside uploads root: ${relPath}`);
  await fs.mkdir(path.dirname(abs), { recursive: true });
  await fs.rename(tmpPath, abs);
}

/** Best-effort deletion of absolute paths (missing files are fine). */
export async function removeFiles(absPaths) {
  await Promise.all(absPaths.map((p) => fs.rm(p, { force: true }).catch(() => {})));
}

/** Best-effort deletion of stored photos by relative path. */
export async function removePhotos(uploadsDir, relPaths) {
  await removeFiles(relPaths.map((p) => resolvePhotoPath(uploadsDir, p)).filter(Boolean));
}

/** Best-effort removal of an issue's photo directory if it is empty (e.g. after a rollback). */
export async function removeEmptyIssueDirs(uploadsDir, issueId) {
  const issueDir = path.join(path.resolve(uploadsDir), 'issues', issueId);
  for (const dir of [path.join(issueDir, 'report'), path.join(issueDir, 'resolution'), issueDir]) {
    await fs.rmdir(dir).catch(() => {});
  }
}

function mapMulterError(err) {
  if (err instanceof multer.MulterError) {
    switch (err.code) {
      case 'LIMIT_FILE_SIZE':
        return payloadTooLarge('Each photo must be 5 MB or smaller.');
      case 'LIMIT_FILE_COUNT':
        return validation(`You can attach at most ${LIMITS.photosPerIssue} photos.`);
      case 'LIMIT_UNEXPECTED_FILE':
        return err.field === PHOTO_FIELD
          ? validation(`You can attach at most ${LIMITS.photosPerIssue} photos.`)
          : validation(`Photos must be sent in the "${PHOTO_FIELD}" field.`);
      default:
        return validation('The upload could not be processed.');
    }
  }
  if (err instanceof AppError) return err;
  // Filesystem errors (ENOSPC, EACCES, ...) are server faults; anything else is a malformed body.
  if (typeof err?.errno === 'number' || err?.syscall) return err;
  return validation('The upload could not be read.');
}

/**
 * Multer middleware that accepts up to `maxFiles` files in field `photos`, each ≤ 5 MB,
 * written to <uploads>/.tmp with random names. Errors become contract errors; multer itself
 * removes any partially written files when it aborts.
 */
export function photoUpload(uploadsDir, maxFiles = LIMITS.photosPerIssue) {
  const upload = multer({
    storage: multer.diskStorage({
      destination: tmpDir(uploadsDir),
      filename: (_req, _file, cb) => cb(null, crypto.randomUUID()),
    }),
    limits: {
      fileSize: LIMITS.photoBytes,
      files: maxFiles,
      fields: 20,
      fieldSize: 16 * 1024,
      parts: 30,
    },
  }).array(PHOTO_FIELD, maxFiles);

  return (req, res, next) => {
    upload(req, res, (err) => {
      if (err) return next(mapMulterError(err));
      next();
    });
  };
}
