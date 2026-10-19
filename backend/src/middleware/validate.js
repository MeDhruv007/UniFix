import { z } from 'zod';
import { validation } from '../errors.js';

/** Parses `data` with `schema`; throws a 400 VALIDATION AppError with the first issue's message. */
export function parse(schema, data) {
  const result = schema.safeParse(data);
  if (!result.success) {
    const first = result.error.issues[0];
    throw validation(first?.message || 'Invalid request.');
  }
  return result.data;
}

/** Replaces req.body with the parsed (trimmed, stripped-of-unknown-keys) body. */
export const validateBody = (schema) => (req, _res, next) => {
  req.body = parse(schema, req.body ?? {});
  next();
};

/** Express 5 makes req.query read-only, so parsed queries go to req.validatedQuery. */
export const validateQuery = (schema) => (req, _res, next) => {
  req.validatedQuery = parse(schema, req.query ?? {});
  next();
};

const missing = (v) => v === undefined || v === null;

/** JSON object body; unknown keys are stripped (so e.g. `role` is silently ignored). */
export const body = (shape) => z.object(shape, { error: 'Request body must be a JSON object.' });

/** Required trimmed string with inclusive [min, max] character limits. */
export function requiredText(label, [min, max]) {
  return z
    .string({ error: (iss) => (missing(iss.input) ? `${label} is required.` : `${label} must be text.`) })
    .trim()
    .min(1, `${label} is required.`)
    .min(min, `${label} must be at least ${min} characters.`)
    .max(max, `${label} must be at most ${max} characters.`);
}

/**
 * Optional trimmed string up to `max` characters. Empty/blank strings and null become null;
 * an absent key stays undefined (so PATCH can tell "not sent" from "cleared").
 */
export function optionalText(label, max) {
  return z.preprocess(
    (v) => {
      if (typeof v !== 'string') return v;
      const t = v.trim();
      return t === '' ? null : t;
    },
    z
      .string({ error: `${label} must be text.` })
      .max(max, `${label} must be at most ${max} characters.`)
      .nullable()
      .optional(),
  );
}

/** Required enum value with a readable error message. */
export function requiredEnum(label, values) {
  return z.preprocess(
    (v) => (typeof v === 'string' ? v.trim() : v),
    z.enum(values, {
      error: (iss) =>
        missing(iss.input) || iss.input === ''
          ? `${label} is required.`
          : `${label} must be one of: ${values.join(', ')}.`,
    }),
  );
}

/** Optional enum for query strings; empty string (e.g. `?status=`) means "not set". */
export function optionalQueryEnum(label, values) {
  return z.preprocess(
    (v) => (v === '' ? undefined : v),
    z.enum(values, { error: `${label} must be one of: ${values.join(', ')}.` }).optional(),
  );
}

/** Optional integer query parameter within [min, max]. */
export function queryInt(label, { min, max, fallback }) {
  return z.preprocess(
    (v) => (v === undefined || v === '' ? String(fallback) : v),
    z
      .string({ error: `${label} must be a whole number.` })
      .regex(/^\d{1,9}$/, `${label} must be a whole number between ${min} and ${max}.`)
      .transform((s) => Number.parseInt(s, 10))
      .pipe(
        z
          .number()
          .min(min, `${label} must be between ${min} and ${max}.`)
          .max(max, `${label} must be between ${min} and ${max}.`),
      ),
  );
}

export const emailField = z
  .string({ error: (iss) => (missing(iss.input) ? 'Email is required.' : 'Email must be text.') })
  .trim()
  .toLowerCase()
  .min(1, 'Email is required.')
  .max(254, 'Email is too long.')
  .pipe(z.email('Enter a valid email address.'));
