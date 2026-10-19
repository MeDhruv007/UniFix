import { AppError, notFound, payloadTooLarge, validation } from '../errors.js';

export function notFoundHandler(_req, _res, next) {
  next(notFound('Route not found.'));
}

/** Converts any thrown value to an AppError (unknown errors → 500 INTERNAL). */
export function toAppError(err) {
  if (err instanceof AppError) return err;
  if (err?.type === 'entity.parse.failed') return validation('Request body is not valid JSON.');
  if (err?.type === 'entity.too.large') return payloadTooLarge('Request body is too large.');
  if (err?.type === 'charset.unsupported' || err?.type === 'encoding.unsupported') {
    return validation('Unsupported request encoding.');
  }
  return new AppError(500, 'INTERNAL', 'Something went wrong. Please try again.');
}

// Express identifies error middleware by arity, so all four parameters are required.
// eslint-disable-next-line no-unused-vars
export function errorHandler(err, req, res, next) {
  const appErr = toAppError(err);
  if (appErr.status >= 500) {
    req.log?.error({ err }, 'Unhandled error');
  }
  if (res.headersSent) {
    res.destroy();
    return;
  }
  res.status(appErr.status).json({ error: { code: appErr.code, message: appErr.message } });
}
