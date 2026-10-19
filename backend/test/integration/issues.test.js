import fs from 'node:fs';
import path from 'node:path';
import request from 'supertest';
import { afterAll, beforeAll, beforeEach, expect, it } from 'vitest';
import { closePool, query } from '../../src/db.js';
import { tmpDir } from '../../src/photos/storage.js';
import {
  API,
  JPEG,
  NOT_AN_IMAGE,
  PNG,
  WEBP,
  auth,
  createIssue,
  describeDb,
  postIssue,
  registerUser,
  resetDb,
  setupTestApp,
  validIssue,
} from '../helpers.js';

const ISSUE_KEYS = [
  'id', 'campusId', 'title', 'description', 'category', 'buildingId', 'locationDetail', 'photoPaths',
  'reporterId', 'reporterDisplayName', 'status', 'priority', 'assignedTo', 'resolutionNote',
  'resolutionPhotoPaths', 'createdAt', 'updatedAt', 'resolvedAt', 'reopenCount',
  // v1.1
  'number', 'code', 'assignedToName',
  // v1.3
  'upvoteCount', 'upvotedByMe',
].sort();

const listTmp = (config) => (fs.existsSync(tmpDir(config.uploadsDir)) ? fs.readdirSync(tmpDir(config.uploadsDir)) : []);

describeDb('issues: create, read, list', () => {
  let app;
  let config;
  let student;
  beforeAll(async () => {
    ({ app, config } = await setupTestApp());
  });
  beforeEach(async () => {
    await resetDb();
    student = await registerUser(app, { displayName: 'Asha Patel' });
  });
  afterAll(closePool);

  it('creates an issue without photos plus a "created" history row', async () => {
    const res = await postIssue(app, student.token, { ...validIssue, title: '  Fan not working in 204 ' });
    expect(res.status).toBe(201);
    expect(Object.keys(res.body).sort()).toEqual(ISSUE_KEYS);
    expect(res.body).toMatchObject({
      campusId: 'adit-main',
      title: 'Fan not working in 204',
      photoPaths: [],
      reporterId: student.user.id,
      reporterDisplayName: 'Asha Patel',
      status: 'reported',
      priority: 'medium',
      assignedTo: null,
      resolutionNote: null,
      resolutionPhotoPaths: [],
      resolvedAt: null,
      reopenCount: 0,
    });

    const updates = await request(app).get(`${API}/issues/${res.body.id}/updates`).set(auth(student.token));
    expect(updates.status).toBe(200);
    expect(updates.body).toEqual([
      {
        id: expect.any(String),
        actorId: student.user.id,
        actorName: 'Asha Patel',
        action: 'created',
        oldStatus: null,
        newStatus: 'reported',
        oldPriority: null,
        newPriority: 'medium',
        note: null,
        createdAt: expect.any(String),
      },
    ]);
  });

  it('ignores client-supplied status/priority/reporter fields', async () => {
    const res = await postIssue(app, student.token, {
      ...validIssue,
      status: 'resolved',
      priority: 'urgent',
      reporterId: '00000000-0000-4000-8000-000000000000',
      campusId: 'elsewhere',
    });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ status: 'reported', priority: 'medium', reporterId: student.user.id, campusId: 'adit-main' });
  });

  it('stores photos under server-generated paths and serves them with the right Content-Type', async () => {
    const res = await postIssue(app, student.token, validIssue, [
      { buf: JPEG, name: 'a.jpg' },
      { buf: PNG, name: 'evil.jpg', type: 'image/jpeg' }, // type is decided by magic bytes
      { buf: WEBP, name: 'c.webp', type: 'image/webp' },
    ]);
    expect(res.status).toBe(201);
    const id = res.body.id;
    expect(res.body.photoPaths).toHaveLength(3);
    expect(res.body.photoPaths[0]).toMatch(new RegExp(`^issues/${id}/report/[0-9a-f-]{36}\\.jpg$`));
    expect(res.body.photoPaths[1]).toMatch(/\.png$/);
    expect(res.body.photoPaths[2]).toMatch(/\.webp$/);

    const other = await registerUser(app);
    const photo = await request(app).get(`${API}/photos/${res.body.photoPaths[1]}`).set(auth(other.token));
    expect(photo.status).toBe(200);
    expect(photo.headers['content-type']).toBe('image/png');
    expect(Buffer.compare(photo.body, PNG)).toBe(0);
    expect(listTmp(config)).toEqual([]);
  });

  it('rejects a non-image upload with 400 and leaves no files behind', async () => {
    const before = fs.existsSync(path.join(config.uploadsDir, 'issues'))
      ? fs.readdirSync(path.join(config.uploadsDir, 'issues')).length
      : 0;
    const res = await postIssue(app, student.token, validIssue, [
      { buf: JPEG, name: 'ok.jpg' },
      { buf: NOT_AN_IMAGE, name: 'photo.jpg', type: 'image/jpeg' },
    ]);
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION');
    const { rows } = await query('SELECT count(*)::int AS n FROM issues');
    expect(rows[0].n).toBe(0);
    expect(listTmp(config)).toEqual([]);
    const after = fs.existsSync(path.join(config.uploadsDir, 'issues'))
      ? fs.readdirSync(path.join(config.uploadsDir, 'issues')).length
      : 0;
    expect(after).toBe(before);
  });

  it('rejects more than 3 photos', async () => {
    const res = await postIssue(app, student.token, validIssue, [
      { buf: JPEG }, { buf: JPEG }, { buf: JPEG }, { buf: JPEG },
    ]);
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION');
    expect(listTmp(config)).toEqual([]);
  });

  it('rejects photos over 5 MB with 413', async () => {
    const big = Buffer.concat([JPEG, Buffer.alloc(5 * 1024 * 1024)]);
    const res = await postIssue(app, student.token, validIssue, [{ buf: big }]);
    expect(res.status).toBe(413);
    expect(res.body.error.code).toBe('PAYLOAD_TOO_LARGE');
    expect(listTmp(config)).toEqual([]);
  });

  it.each([
    [{ title: 'abc' }, /Title/],
    [{ description: 'too short' }, /Description/],
    [{ category: 'aliens' }, /Category/],
    [{ buildingId: 'mars' }, /Building/],
    [{ locationDetail: ' ' }, /Location detail/],
  ])('validates fields %o', async (patch, msg) => {
    const res = await postIssue(app, student.token, { ...validIssue, ...patch }, [{ buf: JPEG }]);
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION');
    expect(res.body.error.message).toMatch(msg);
    expect(listTmp(config)).toEqual([]);
  });

  it('GET /issues/:id returns 404 for unknown and malformed ids', async () => {
    const unknown = await request(app)
      .get(`${API}/issues/7d7c0a3e-4b6e-4c1f-9a4f-2f0c7b6c9d11`)
      .set(auth(student.token));
    expect(unknown.status).toBe(404);
    expect(unknown.body.error.code).toBe('NOT_FOUND');
    const malformed = await request(app).get(`${API}/issues/not-a-uuid`).set(auth(student.token));
    expect(malformed.status).toBe(404);
  });

  it('lists newest first with filters, mine and pagination', async () => {
    const other = await registerUser(app);
    const a = await createIssue(app, student.token, { title: 'Issue number A', category: 'plumbing' });
    const b = await createIssue(app, other.token, { title: 'Issue number B', category: 'electrical' });
    const c = await createIssue(app, student.token, { title: 'Issue number C', category: 'electrical' });
    // Make created_at strictly ordered regardless of clock resolution.
    await query("UPDATE issues SET created_at = now() - interval '3 minutes' WHERE id = $1", [a.id]);
    await query("UPDATE issues SET created_at = now() - interval '2 minutes' WHERE id = $1", [b.id]);
    await query("UPDATE issues SET created_at = now() - interval '1 minutes' WHERE id = $1", [c.id]);
    await query("UPDATE issues SET status = 'inProgress' WHERE id = $1", [b.id]);

    const list = (qs) => request(app).get(`${API}/issues${qs}`).set(auth(student.token));

    const all = await list('');
    expect(all.status).toBe(200);
    expect(all.body.total).toBe(3);
    expect(all.body.items.map((i) => i.id)).toEqual([c.id, b.id, a.id]);

    const empties = await list('?status=&category=');
    expect(empties.body.total).toBe(3);

    const mine = await list('?mine=true');
    expect(mine.body.items.map((i) => i.id)).toEqual([c.id, a.id]);
    expect(mine.body.total).toBe(2);

    const elec = await list('?category=electrical');
    expect(elec.body.items.map((i) => i.id)).toEqual([c.id, b.id]);

    const prog = await list('?status=inProgress');
    expect(prog.body.items.map((i) => i.id)).toEqual([b.id]);

    const mineElec = await list('?mine=true&category=electrical');
    expect(mineElec.body.items.map((i) => i.id)).toEqual([c.id]);

    const page = await list('?limit=1&offset=1');
    expect(page.body.items.map((i) => i.id)).toEqual([b.id]);
    expect(page.body.total).toBe(3);

    const past = await list('?limit=10&offset=10');
    expect(past.body).toEqual({ items: [], total: 3 });

    for (const bad of ['?limit=0', '?limit=51', '?limit=x', '?offset=-1', '?status=closed', '?mine=yes']) {
      const res = await list(bad);
      expect(res.status, bad).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION');
    }
  });

  it('students cannot change status or priority, assign, add resolution photos or read stats', async () => {
    const issue = await createIssue(app, student.token);
    const s = await request(app)
      .patch(`${API}/issues/${issue.id}/status`)
      .set(auth(student.token))
      .send({ from: 'reported', to: 'inProgress' });
    expect(s.status).toBe(403);
    expect(s.body.error.code).toBe('FORBIDDEN');
    const p = await request(app)
      .patch(`${API}/issues/${issue.id}/priority`)
      .set(auth(student.token))
      .send({ from: 'medium', to: 'urgent' });
    expect(p.status).toBe(403);
    expect((await request(app).post(`${API}/issues/${issue.id}/assign`).set(auth(student.token))).status).toBe(403);
    const photos = await request(app)
      .post(`${API}/issues/${issue.id}/resolution-photos`)
      .set(auth(student.token))
      .attach('photos', JPEG, 'fix.jpg');
    expect(photos.status).toBe(403);
    expect((await request(app).get(`${API}/issues/stats`).set(auth(student.token))).status).toBe(403);

    const after = await request(app).get(`${API}/issues/${issue.id}`).set(auth(student.token));
    expect(after.body).toMatchObject({ status: 'reported', priority: 'medium', assignedTo: null, resolutionPhotoPaths: [] });
    const { rows } = await query('SELECT count(*)::int AS n FROM issue_updates WHERE issue_id = $1', [issue.id]);
    expect(rows[0].n).toBe(1);
  });
});
