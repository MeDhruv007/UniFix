// API.md "v1.3 additions": "Me too" upvotes.
import request from 'supertest';
import { beforeAll, beforeEach, expect, it } from 'vitest';
import { query } from '../../src/db.js';
import {
  API,
  auth,
  createIssue,
  describeDb,
  registerAdmin,
  registerUser,
  resetDb,
  setStatus,
  setupTestApp,
} from '../helpers.js';

describeDb('v1.3 upvotes', () => {
  let app;
  let reporter;
  let a;
  let b;
  let admin;
  beforeAll(async () => {
    ({ app } = await setupTestApp());
  });
  beforeEach(async () => {
    await resetDb();
    reporter = await registerUser(app);
    a = await registerUser(app);
    b = await registerUser(app);
    admin = await registerAdmin(app);
  });

  const up = (u, id) => request(app).post(`${API}/issues/${id}/upvote`).set(auth(u.token));
  const down = (u, id) => request(app).delete(`${API}/issues/${id}/upvote`).set(auth(u.token));
  const get = (u, id) => request(app).get(`${API}/issues/${id}`).set(auth(u.token));
  const list = (u, qs = '') => request(app).get(`${API}/issues${qs}`).set(auth(u.token));

  it('new issues start at 0 / false', async () => {
    const issue = await createIssue(app, reporter.token);
    expect(issue).toMatchObject({ upvoteCount: 0, upvotedByMe: false });
  });

  it('upvotes, is idempotent, and removes (also idempotent)', async () => {
    const issue = await createIssue(app, reporter.token);
    const r1 = await up(a, issue.id);
    expect(r1.status).toBe(200);
    expect(r1.body).toMatchObject({ id: issue.id, upvoteCount: 1, upvotedByMe: true });
    const r2 = await up(a, issue.id);
    expect(r2.status).toBe(200);
    expect(r2.body).toMatchObject({ upvoteCount: 1, upvotedByMe: true });

    const d1 = await down(a, issue.id);
    expect(d1.status).toBe(200);
    expect(d1.body).toMatchObject({ upvoteCount: 0, upvotedByMe: false });
    const d2 = await down(a, issue.id);
    expect(d2.status).toBe(200);
    expect(d2.body).toMatchObject({ upvoteCount: 0, upvotedByMe: false });
  });

  it('counts per issue and reports upvotedByMe per caller (get and list)', async () => {
    const issue = await createIssue(app, reporter.token);
    await up(a, issue.id);
    await up(b, issue.id);
    await up(admin, issue.id); // admins may upvote too

    expect((await get(a, issue.id)).body).toMatchObject({ upvoteCount: 3, upvotedByMe: true });
    expect((await get(reporter, issue.id)).body).toMatchObject({ upvoteCount: 3, upvotedByMe: false });
    const other = await registerUser(app);
    expect((await list(other)).body.items[0]).toMatchObject({ upvoteCount: 3, upvotedByMe: false });
    expect((await list(b)).body.items[0]).toMatchObject({ upvoteCount: 3, upvotedByMe: true });
    await down(b, issue.id);
    expect((await list(b)).body.items[0]).toMatchObject({ upvoteCount: 2, upvotedByMe: false });
  });

  it('blocks the reporter (400) and does not count them', async () => {
    const issue = await createIssue(app, reporter.token);
    const res = await up(reporter, issue.id);
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION');
    expect(res.body.error.message).toBe('You reported this issue.');
    expect((await get(reporter, issue.id)).body.upvoteCount).toBe(0);
  });

  it('blocks upvoting a resolved issue (409) but still allows removal', async () => {
    const issue = await createIssue(app, reporter.token);
    await up(a, issue.id);
    expect((await setStatus(app, admin.token, issue.id, { from: 'reported', to: 'inProgress' })).status).toBe(200);
    const done = await setStatus(app, admin.token, issue.id, { from: 'inProgress', to: 'resolved', note: 'Fixed' });
    expect(done.status).toBe(200);
    expect(done.body).toMatchObject({ upvoteCount: 1, upvotedByMe: false });

    const blocked = await up(b, issue.id);
    expect(blocked.status).toBe(409);
    expect(blocked.body.error.code).toBe('CONFLICT');
    const removed = await down(a, issue.id);
    expect(removed.status).toBe(200);
    expect(removed.body.upvoteCount).toBe(0);
  });

  it('returns 404 for unknown and malformed ids', async () => {
    for (const id of ['00000000-0000-4000-8000-000000000000', 'nope']) {
      expect((await up(a, id)).status).toBe(404);
      expect((await down(a, id)).status).toBe(404);
    }
  });

  it('requires authentication and an active account', async () => {
    const issue = await createIssue(app, reporter.token);
    expect((await request(app).post(`${API}/issues/${issue.id}/upvote`)).status).toBe(401);
    await query('UPDATE users SET is_active = false WHERE id = $1', [a.user.id]);
    const res = await up(a, issue.id);
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('ACCOUNT_DISABLED');
  });

  it('sort=popular orders by upvotes, then newest, with stable paging', async () => {
    const i1 = await createIssue(app, reporter.token, { title: 'Issue one' });
    const i2 = await createIssue(app, reporter.token, { title: 'Issue two' });
    const i3 = await createIssue(app, reporter.token, { title: 'Issue three' });
    const i4 = await createIssue(app, reporter.token, { title: 'Issue four' });
    await up(a, i1.id);
    await up(b, i1.id);
    await up(a, i3.id);

    const res = await list(a, '?sort=popular');
    expect(res.status).toBe(200);
    // i1 (2), i3 (1), then zero-vote issues newest first: i4, i2.
    expect(res.body.items.map((i) => i.id)).toEqual([i1.id, i3.id, i4.id, i2.id]);
    expect(res.body.total).toBe(4);

    const p1 = await list(a, '?sort=popular&limit=2&offset=0');
    const p2 = await list(a, '?sort=popular&limit=2&offset=2');
    expect([...p1.body.items, ...p2.body.items].map((i) => i.id)).toEqual([i1.id, i3.id, i4.id, i2.id]);

    // newest is unchanged; bad values still 400
    expect((await list(a)).body.items.map((i) => i.id)).toEqual([i4.id, i3.id, i2.id, i1.id]);
    expect((await list(a, '?sort=bogus')).status).toBe(400);
  });

  it('admin write responses carry the counts', async () => {
    const issue = await createIssue(app, reporter.token);
    await up(a, issue.id);
    await up(admin, issue.id);

    const prio = await request(app)
      .patch(`${API}/issues/${issue.id}/priority`)
      .set(auth(admin.token))
      .send({ from: 'medium', to: 'high' });
    expect(prio.body).toMatchObject({ upvoteCount: 2, upvotedByMe: true });
    const assign = await request(app).post(`${API}/issues/${issue.id}/assign`).set(auth(admin.token)).send({});
    expect(assign.body).toMatchObject({ upvoteCount: 2, upvotedByMe: true });
    const noop = await request(app).post(`${API}/issues/${issue.id}/assign`).set(auth(admin.token)).send({});
    expect(noop.body).toMatchObject({ upvoteCount: 2, upvotedByMe: true });
    const status = await setStatus(app, admin.token, issue.id, { from: 'reported', to: 'inProgress' });
    expect(status.body).toMatchObject({ upvoteCount: 2, upvotedByMe: true });
  });
});
