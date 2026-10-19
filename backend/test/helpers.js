import { describe } from 'vitest';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { query } from '../src/db.js';
import { migrate } from '../src/migrate.js';
import { ensureUploadDirs } from '../src/photos/storage.js';

export const hasDb = Boolean(process.env.DATABASE_URL);

/** describe() that is skipped (with the setup.js warning) when no DATABASE_URL is configured. */
export const describeDb = describe.skipIf(!hasDb);

export const API = '/api/v1';

/** Migrates the test DB and builds an app. Refuses to run against a DB not named like a test DB. */
export async function setupTestApp() {
  const dbName = new URL(process.env.DATABASE_URL).pathname.slice(1);
  if (!/test/i.test(dbName) && process.env.ALLOW_DB_RESET !== '1') {
    throw new Error(
      `Refusing to truncate database "${dbName}": its name must contain "test" (or set ALLOW_DB_RESET=1).`,
    );
  }
  await migrate();
  const config = loadConfig();
  await ensureUploadDirs(config.uploadsDir);
  return { app: createApp(config), config };
}

export async function resetDb() {
  await query(
    'TRUNCATE issue_feedback, issue_updates, issues, password_reset_tokens, users RESTART IDENTITY CASCADE',
  );
}

let counter = 0;
export async function registerUser(app, overrides = {}) {
  counter += 1;
  const payload = {
    displayName: `Test User ${counter}`,
    email: `user${counter}-${Date.now()}@adit.ac.in`,
    password: 'correct-horse-battery',
    department: 'Computer',
    ...overrides,
  };
  const res = await request(app).post(`${API}/auth/register`).send(payload);
  if (res.status !== 201) throw new Error(`register failed: ${res.status} ${JSON.stringify(res.body)}`);
  return { token: res.body.token, user: res.body.user, password: payload.password };
}

export async function registerAdmin(app, overrides = {}) {
  const u = await registerUser(app, { displayName: 'Facilities Admin', ...overrides });
  await query("UPDATE users SET role = 'admin' WHERE id = $1", [u.user.id]);
  return u;
}

export const auth = (token) => ({ Authorization: `Bearer ${token}` });

// Minimal file signatures (only the magic bytes matter to the server).
export const JPEG = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(64, 1)]);
export const PNG = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  Buffer.alloc(64, 2),
]);
export const WEBP = Buffer.concat([
  Buffer.from('RIFF'),
  Buffer.from([0x24, 0, 0, 0]),
  Buffer.from('WEBPVP8 '),
  Buffer.alloc(64, 3),
]);
export const NOT_AN_IMAGE = Buffer.from('#!/bin/sh\necho definitely not an image\n');

export const validIssue = {
  title: 'Fan not working in Room 204',
  description: 'The ceiling fan does not start at all.',
  category: 'electrical',
  buildingId: 'engineering-block',
  locationDetail: 'Second floor, Room 204',
};

/** POST /issues as multipart with the given fields and photos ([{ buf, name }]). */
export function postIssue(app, token, fields = validIssue, photos = []) {
  let req = request(app).post(`${API}/issues`).set(auth(token));
  for (const [k, v] of Object.entries(fields)) req = req.field(k, v);
  for (const p of photos) {
    req = req.attach('photos', p.buf, { filename: p.name ?? 'photo.jpg', contentType: p.type ?? 'image/jpeg' });
  }
  return req;
}

export async function createIssue(app, token, fields = {}, photos = []) {
  const res = await postIssue(app, token, { ...validIssue, ...fields }, photos);
  if (res.status !== 201) throw new Error(`create issue failed: ${res.status} ${JSON.stringify(res.body)}`);
  return res.body;
}

export function setStatus(app, token, id, body) {
  return request(app).patch(`${API}/issues/${id}/status`).set(auth(token)).send(body);
}
