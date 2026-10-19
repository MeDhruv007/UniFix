import request from 'supertest';
import { afterAll, beforeAll, beforeEach, expect, it } from 'vitest';
import { closePool, query } from '../../src/db.js';
import {
  API,
  JPEG,
  NOT_AN_IMAGE,
  PNG,
  auth,
  createIssue,
  describeDb,
  registerAdmin,
  registerUser,
  resetDb,
  setStatus,
  setupTestApp,
} from '../helpers.js';

const updatesOf = async (app, token, id) =>
  (await request(app).get(`${API}/issues/${id}/updates`).set(auth(token))).body;

describeDb('admin workflows', () => {
  let app;
  let student;
  let admin;
  let issue;
  beforeAll(async () => {
    ({ app } = await setupTestApp());
  });
  beforeEach(async () => {
    await resetDb();
    student = await registerUser(app);
    admin = await registerAdmin(app, { displayName: 'Ravi Admin' });
    issue = await createIssue(app, student.token);
  });
  afterAll(closePool);

  it('applies a valid transition and appends a statusChanged row', async () => {
    const res = await setStatus(app, admin.token, issue.id, { from: 'reported', to: 'inProgress', note: ' Electrician assigned ' });
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('inProgress');
    expect(new Date(res.body.updatedAt) >= new Date(issue.updatedAt)).toBe(true);

    const updates = await updatesOf(app, student.token, issue.id);
    expect(updates.map((u) => u.action)).toEqual(['created', 'statusChanged']);
    expect(updates[1]).toMatchObject({
      actorId: admin.user.id,
      oldStatus: 'reported',
      newStatus: 'inProgress',
      oldPriority: null,
      newPriority: null,
      note: 'Electrician assigned',
    });
  });

  it('returns 422 for a transition that is not allowed', async () => {
    const res = await setStatus(app, admin.token, issue.id, { from: 'reported', to: 'resolved', note: 'done' });
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('INVALID_TRANSITION');
    const same = await setStatus(app, admin.token, issue.id, { from: 'reported', to: 'reported' });
    expect(same.status).toBe(422);
    expect((await updatesOf(app, admin.token, issue.id)).length).toBe(1);
  });

  it('returns 409 when `from` is stale', async () => {
    await setStatus(app, admin.token, issue.id, { from: 'reported', to: 'inProgress' });
    const stale = await setStatus(app, admin.token, issue.id, { from: 'reported', to: 'inProgress' });
    expect(stale.status).toBe(409);
    expect(stale.body.error.code).toBe('CONFLICT');
    expect((await updatesOf(app, admin.token, issue.id)).length).toBe(2);
  });

  it('requires a resolution note to resolve, sets resolvedAt, and reopen increments reopenCount', async () => {
    await setStatus(app, admin.token, issue.id, { from: 'reported', to: 'inProgress' });

    const noNote = await setStatus(app, admin.token, issue.id, { from: 'inProgress', to: 'resolved', note: '  ' });
    expect(noNote.status).toBe(400);
    expect(noNote.body.error.code).toBe('VALIDATION');

    const resolved = await setStatus(app, admin.token, issue.id, { from: 'inProgress', to: 'resolved', note: 'Replaced capacitor' });
    expect(resolved.status).toBe(200);
    expect(resolved.body).toMatchObject({ status: 'resolved', resolutionNote: 'Replaced capacitor', reopenCount: 0 });
    expect(resolved.body.resolvedAt).toEqual(expect.any(String));

    const reopened = await setStatus(app, admin.token, issue.id, { from: 'resolved', to: 'reopened', note: 'Still broken' });
    expect(reopened.status).toBe(200);
    expect(reopened.body).toMatchObject({ status: 'reopened', resolvedAt: null, reopenCount: 1 });

    const again = await setStatus(app, admin.token, issue.id, { from: 'reopened', to: 'resolved', note: 'Fixed properly' });
    expect(again.body).toMatchObject({ status: 'resolved', resolutionNote: 'Fixed properly' });
    await setStatus(app, admin.token, issue.id, { from: 'resolved', to: 'reopened' });
    const r2 = await setStatus(app, admin.token, issue.id, { from: 'reopened', to: 'inProgress' });
    expect(r2.body).toMatchObject({ status: 'inProgress', reopenCount: 2 });

    const actions = (await updatesOf(app, admin.token, issue.id)).map((u) => u.action);
    expect(actions).toEqual(['created', 'statusChanged', 'statusChanged', 'reopened', 'statusChanged', 'reopened', 'statusChanged']);
  });

  it('changes priority with stale detection and history', async () => {
    const res = await request(app)
      .patch(`${API}/issues/${issue.id}/priority`)
      .set(auth(admin.token))
      .send({ from: 'medium', to: 'urgent' });
    expect(res.status).toBe(200);
    expect(res.body.priority).toBe('urgent');

    const stale = await request(app)
      .patch(`${API}/issues/${issue.id}/priority`)
      .set(auth(admin.token))
      .send({ from: 'medium', to: 'high' });
    expect(stale.status).toBe(409);

    const bad = await request(app)
      .patch(`${API}/issues/${issue.id}/priority`)
      .set(auth(admin.token))
      .send({ from: 'urgent', to: 'critical' });
    expect(bad.status).toBe(400);

    const updates = await updatesOf(app, admin.token, issue.id);
    expect(updates[1]).toMatchObject({ action: 'priorityChanged', oldPriority: 'medium', newPriority: 'urgent', oldStatus: null });
    expect(updates).toHaveLength(2);
  });

  it('assigns the issue to the calling admin', async () => {
    const res = await request(app).post(`${API}/issues/${issue.id}/assign`).set(auth(admin.token));
    expect(res.status).toBe(200);
    expect(res.body.assignedTo).toBe(admin.user.id);
    const updates = await updatesOf(app, admin.token, issue.id);
    expect(updates[1]).toMatchObject({ action: 'assigned', note: 'Assigned to Ravi Admin', actorId: admin.user.id });
  });

  it('adds resolution photos (max 3 in total) with a commented history row', async () => {
    const first = await request(app)
      .post(`${API}/issues/${issue.id}/resolution-photos`)
      .set(auth(admin.token))
      .attach('photos', JPEG, 'a.jpg')
      .attach('photos', PNG, 'b.png');
    expect(first.status).toBe(200);
    expect(first.body.resolutionPhotoPaths).toHaveLength(2);
    expect(first.body.resolutionPhotoPaths[0]).toMatch(new RegExp(`^issues/${issue.id}/resolution/[0-9a-f-]{36}\\.jpg$`));

    const tooMany = await request(app)
      .post(`${API}/issues/${issue.id}/resolution-photos`)
      .set(auth(admin.token))
      .attach('photos', JPEG, 'c.jpg')
      .attach('photos', JPEG, 'd.jpg');
    expect(tooMany.status).toBe(400);

    const none = await request(app).post(`${API}/issues/${issue.id}/resolution-photos`).set(auth(admin.token)).field('x', 'y');
    expect(none.status).toBe(400);

    const notImage = await request(app)
      .post(`${API}/issues/${issue.id}/resolution-photos`)
      .set(auth(admin.token))
      .attach('photos', NOT_AN_IMAGE, 'e.jpg');
    expect(notImage.status).toBe(400);

    const missing = await request(app)
      .post(`${API}/issues/7d7c0a3e-4b6e-4c1f-9a4f-2f0c7b6c9d11/resolution-photos`)
      .set(auth(admin.token))
      .attach('photos', JPEG, 'f.jpg');
    expect(missing.status).toBe(404);

    const current = await request(app).get(`${API}/issues/${issue.id}`).set(auth(student.token));
    expect(current.body.resolutionPhotoPaths).toHaveLength(2);
    const updates = await updatesOf(app, admin.token, issue.id);
    expect(updates.map((u) => u.action)).toEqual(['created', 'commented']);
  });

  it('returns campus-wide stats', async () => {
    const b = await createIssue(app, student.token);
    await createIssue(app, student.token);
    await setStatus(app, admin.token, b.id, { from: 'reported', to: 'inProgress' });
    await setStatus(app, admin.token, issue.id, { from: 'reported', to: 'inProgress' });
    await setStatus(app, admin.token, issue.id, { from: 'inProgress', to: 'resolved', note: 'Done' });
    const res = await request(app).get(`${API}/issues/stats`).set(auth(admin.token));
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ reported: 1, inProgress: 1, resolved: 1, reopened: 0, total: 3 });
  });

  it('keeps issue_updates append-only at the database level', async () => {
    await expect(query("UPDATE issue_updates SET note = 'tampered'")).rejects.toThrow(/append-only/);
    await expect(query('DELETE FROM issue_updates')).rejects.toThrow(/append-only/);
  });
});
