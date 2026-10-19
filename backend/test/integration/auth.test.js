import request from 'supertest';
import { afterAll, beforeAll, beforeEach, expect, it } from 'vitest';
import { newResetToken } from '../../src/auth/passwords.js';
import { closePool, query } from '../../src/db.js';
import { API, auth, describeDb, registerUser, resetDb, setupTestApp } from '../helpers.js';

const ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;

describeDb('auth & profile', () => {
  let app;
  beforeAll(async () => {
    ({ app } = await setupTestApp());
  });
  beforeEach(resetDb);
  afterAll(closePool);

  it('registers, logs in and returns /me with the exact User shape', async () => {
    const reg = await request(app).post(`${API}/auth/register`).send({
      displayName: '  Asha Patel ',
      email: ' Asha@ADIT.ac.in ',
      password: 'correct-horse-battery',
      department: 'Computer',
    });
    expect(reg.status).toBe(201);
    expect(typeof reg.body.token).toBe('string');
    expect(Object.keys(reg.body.user).sort()).toEqual(
      ['avatar', 'campusId', 'createdAt', 'department', 'displayName', 'email', 'id', 'isActive', 'role', 'updatedAt'].sort(),
    );
    expect(reg.body.user).toMatchObject({
      displayName: 'Asha Patel',
      email: 'asha@adit.ac.in',
      role: 'student',
      campusId: 'adit-main',
      department: 'Computer',
      isActive: true,
    });
    expect(reg.body.user.createdAt).toMatch(ISO);

    const login = await request(app)
      .post(`${API}/auth/login`)
      .send({ email: 'ASHA@adit.ac.in', password: 'correct-horse-battery' });
    expect(login.status).toBe(200);
    expect(login.body.user.id).toBe(reg.body.user.id);

    const me = await request(app).get(`${API}/me`).set(auth(login.body.token));
    expect(me.status).toBe(200);
    expect(me.body).toEqual(reg.body.user);
  });

  it('stores an empty department as null', async () => {
    const { user } = await registerUser(app, { department: '   ' });
    expect(user.department).toBeNull();
  });

  it('ignores a role in the registration body', async () => {
    const { user, token } = await registerUser(app, { role: 'admin', campusId: 'other', isActive: false });
    expect(user.role).toBe('student');
    expect(user.campusId).toBe('adit-main');
    expect(user.isActive).toBe(true);
    const stats = await request(app).get(`${API}/issues/stats`).set(auth(token));
    expect(stats.status).toBe(403);
  });

  it('rejects duplicate emails (case-insensitive) with 409', async () => {
    await registerUser(app, { email: 'dup@adit.ac.in' });
    const res = await request(app)
      .post(`${API}/auth/register`)
      .send({ displayName: 'Other', email: 'DUP@adit.ac.in', password: 'another-password' });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('CONFLICT');
  });

  it('uses one generic message for unknown email and wrong password', async () => {
    await registerUser(app, { email: 'known@adit.ac.in' });
    const wrong = await request(app).post(`${API}/auth/login`).send({ email: 'known@adit.ac.in', password: 'nope-nope-nope' });
    const unknown = await request(app).post(`${API}/auth/login`).send({ email: 'ghost@adit.ac.in', password: 'nope-nope-nope' });
    expect(wrong.status).toBe(401);
    expect(unknown.status).toBe(401);
    expect(wrong.body).toEqual(unknown.body);
    expect(wrong.body.error.code).toBe('UNAUTHENTICATED');
  });

  it('blocks a deactivated user on login and on existing tokens', async () => {
    const { user, token, password } = await registerUser(app);
    await query('UPDATE users SET is_active = false WHERE id = $1', [user.id]);

    const me = await request(app).get(`${API}/me`).set(auth(token));
    expect(me.status).toBe(403);
    expect(me.body.error.code).toBe('ACCOUNT_DISABLED');

    const login = await request(app).post(`${API}/auth/login`).send({ email: user.email, password });
    expect(login.status).toBe(403);
    expect(login.body.error.code).toBe('ACCOUNT_DISABLED');
  });

  it('re-reads the role from the DB on every request', async () => {
    const { user, token } = await registerUser(app);
    expect((await request(app).get(`${API}/issues/stats`).set(auth(token))).status).toBe(403);
    await query("UPDATE users SET role = 'admin' WHERE id = $1", [user.id]);
    expect((await request(app).get(`${API}/issues/stats`).set(auth(token))).status).toBe(200);
  });

  it('rejects a valid token for a user that no longer exists', async () => {
    const { token } = await registerUser(app);
    await resetDb();
    const res = await request(app).get(`${API}/me`).set(auth(token));
    expect(res.status).toBe(401);
  });

  it('PATCH /me updates only displayName/department; "" clears department', async () => {
    const { token, user } = await registerUser(app);
    const res = await request(app)
      .patch(`${API}/me`)
      .set(auth(token))
      .send({ displayName: ' New Name ', role: 'admin', email: 'x@y.z', isActive: false });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ displayName: 'New Name', role: 'student', email: user.email, isActive: true, department: 'Computer' });

    const cleared = await request(app).patch(`${API}/me`).set(auth(token)).send({ department: '' });
    expect(cleared.status).toBe(200);
    expect(cleared.body.department).toBeNull();
    expect(cleared.body.displayName).toBe('New Name');

    const bad = await request(app).patch(`${API}/me`).set(auth(token)).send({ displayName: 'x' });
    expect(bad.status).toBe(400);
    expect(bad.body.error.code).toBe('VALIDATION');
  });

  it('password reset always answers 204 and stores only a hashed token', async () => {
    const { user } = await registerUser(app);
    const known = await request(app).post(`${API}/auth/password-reset`).send({ email: user.email });
    const unknown = await request(app).post(`${API}/auth/password-reset`).send({ email: 'ghost@adit.ac.in' });
    expect(known.status).toBe(204);
    expect(unknown.status).toBe(204);
    const { rows } = await query('SELECT token_hash FROM password_reset_tokens WHERE user_id = $1', [user.id]);
    expect(rows).toHaveLength(1);
    expect(rows[0].token_hash).toMatch(/^[0-9a-f]{64}$/);
  });

  it('password-reset/confirm (extension) sets a new password once per token', async () => {
    const { user } = await registerUser(app);
    const { token, tokenHash } = newResetToken();
    await query(
      "INSERT INTO password_reset_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, now() + interval '10 minutes')",
      [user.id, tokenHash],
    );
    const ok = await request(app)
      .post(`${API}/auth/password-reset/confirm`)
      .send({ token, newPassword: 'brand-new-password' });
    expect(ok.status).toBe(204);
    const login = await request(app).post(`${API}/auth/login`).send({ email: user.email, password: 'brand-new-password' });
    expect(login.status).toBe(200);
    const reused = await request(app)
      .post(`${API}/auth/password-reset/confirm`)
      .send({ token, newPassword: 'another-new-password' });
    expect(reused.status).toBe(400);
  });
});
