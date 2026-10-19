/** Error that maps 1:1 onto the API error body `{ error: { code, message } }`. */
export class AppError extends Error {
  constructor(status, code, message) {
    super(message);
    this.name = 'AppError';
    this.status = status;
    this.code = code;
  }
}

export const validation = (message) => new AppError(400, 'VALIDATION', message);
export const unauthenticated = (message = 'Please sign in again.') =>
  new AppError(401, 'UNAUTHENTICATED', message);
export const forbidden = (message = 'You do not have permission to do that.') =>
  new AppError(403, 'FORBIDDEN', message);
export const accountDisabled = () =>
  new AppError(403, 'ACCOUNT_DISABLED', 'This account has been deactivated. Contact the campus administrator.');
export const notFound = (message = 'Not found.') => new AppError(404, 'NOT_FOUND', message);
export const conflict = (message) => new AppError(409, 'CONFLICT', message);
export const payloadTooLarge = (message = 'Each photo must be 5 MB or smaller.') =>
  new AppError(413, 'PAYLOAD_TOO_LARGE', message);
export const invalidTransition = (message) => new AppError(422, 'INVALID_TRANSITION', message);
