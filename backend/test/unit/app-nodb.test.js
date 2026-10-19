// HTTP-level checks that are answered before any database access.
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import jwt from 'jsonwebtoken';
import { createApp } from '../../src/app.js';
import { loadConfig } from '../../src/config.js';
import { API } from '../helpers.js';

const app = createApp(loadConfig());

describe('app without database', () => {
  it('refuses to start without a strong JWT secret', () => {
    expect(() => createApp({ ...loadConfig(), jwtSecret: 'short' })).toThrow(/JWT_SECRET/);
  });

  it('returns the contract error body for unknown routes', async () => {
    const res = await request(app).get(`${API}/does-not-exist`);
    expect(res.status).toBe(404);
    expect(res.body).toEqual({ error: { code: 'NOT_FOUND', message: expect.any(String) } });
  });

  it('rejects malformed JSON with 400 VALIDATION', async () => {
    const res = await request(app)
      .post(`${API}/auth/login`)
      .set('Content-Type', 'application/json')
      .send('{"email":');
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION');
  });

  it('validates registration input before touching the DB', async () => {
    const res = await request(app)
      .post(`${API}/auth/register`)
      .send({ displayName: 'Asha', email: 'not-an-email', password: 'longenough' });
    expect(res.status).toBe(400);
    expect(res.body.error).toEqual({ code: 'VALIDATION', message: 'Enter a valid email address.' });

    const short = await request(app)
      .post(`${API}/auth/register`)
      .send({ displayName: 'Asha', email: 'a@adit.ac.in', password: 'short' });
    expect(short.body.error.message).toBe('Password must be at least 8 characters.');
  });

  it.each(['/me', '/issues', '/issues/stats', `/photos/issues/x/report/y.jpg`])(
    'requires a bearer token for %s',
    async (p) => {
      const res = await request(app).get(`${API}${p}`);
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    },
  );

  it('rejects tokens with a bad signature, alg=none, or an expired exp', async () => {
    const config = loadConfig();
    const sub = '3f2a1b4c-5d6e-4f70-8a9b-0c1d2e3f4a5b';
    const tokens = [
      jwt.sign({ sub, role: 'admin' }, 'some-other-secret-some-other-secret-1234'),
      jwt.sign({ sub, role: 'admin' }, null, { algorithm: 'none' }),
      jwt.sign({ sub, role: 'admin', exp: Math.floor(Date.now() / 1000) - 10 }, config.jwtSecret),
    ];
    for (const t of tokens) {
      const res = await request(app).get(`${API}/me`).set('Authorization', `Bearer ${t}`);
      expect(res.status).toBe(401);
    }
  });

  it('never exposes x-powered-by and sets helmet headers', async () => {
    const res = await request(app).get(`${API}/nope`);
    expect(res.headers['x-powered-by']).toBeUndefined();
    expect(res.headers['x-content-type-options']).toBe('nosniff');
  });
});
