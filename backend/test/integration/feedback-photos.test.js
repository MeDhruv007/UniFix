import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import request from 'supertest';
import { afterAll, beforeAll, beforeEach, expect, it } from 'vitest';
import { closePool } from '../../src/db.js';
import {
  API,
  JPEG,
  auth,
  createIssue,
  describeDb,
  registerAdmin,
  registerUser,
  resetDb,
  setStatus,
  setupTestApp,
} from '../helpers.js';

/** Sends a raw request path without client-side URL normalisation. */
function rawGet(app, rawPath, headers) {
  return new Promise((resolve, reject) => {
    const server = app.listen(0, () => {
      const req = http.request(
        { host: '127.0.0.1', port: server.address().port, path: rawPath, headers },
        (res) => {
          const chunks = [];
          res.on('data', (c) => chunks.push(c));
          res.on('end', () => {
            server.close();
            resolve({ status: res.statusCode, body: Buffer.concat(chunks).toString() });
          });
        },
      );
      req.on('error', (e) => {
        server.close();
        reject(e);
      });
      req.end();
    });
  });
}

describeDb('feedback', () => {
  let app;
  let reporter;
  let other;
  let admin;
  let issue;
  beforeAll(async () => {
    ({ app } = await setupTestApp());
  });
  beforeEach(async () => {
    await resetDb();
    reporter = await registerUser(app);
    other = await registerUser(app);
    admin = await registerAdmin(app);
    issue = await createIssue(app, reporter.token);
  });
  afterAll(closePool);

  const resolve = async () => {
    await setStatus(app, admin.token, issue.id, { from: 'reported', to: 'inProgress' });
    await setStatus(app, admin.token, issue.id, { from: 'inProgress', to: 'resolved', note: 'Fixed' });
  };
  const give = (token, body = { stillExists: false, comment: ' Works now ' }) =>
    request(app).post(`${API}/issues/${issue.id}/feedback`).set(auth(token)).send(body);

  it('only allows feedback once the issue is resolved', async () => {
    const res = await give(reporter.token);
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('CONFLICT');
  });

  it('only the reporter can give or read feedback', async () => {
    await resolve();
    expect((await give(other.token)).status).toBe(403);
    expect((await give(admin.token)).status).toBe(403);
    const read = await request(app).get(`${API}/issues/${issue.id}/feedback/me`).set(auth(other.token));
    expect(read.status).toBe(403);
  });

  it('accepts exactly one feedback per reporter and returns it from /feedback/me', async () => {
    await resolve();
    const none = await request(app).get(`${API}/issues/${issue.id}/feedback/me`).set(auth(reporter.token));
    expect(none.status).toBe(404);

    const res = await give(reporter.token);
    expect(res.status).toBe(201);
    expect(res.body).toEqual({
      issueId: issue.id,
      reporterId: reporter.user.id,
      stillExists: false,
      comment: 'Works now',
      createdAt: expect.any(String),
    });

    const again = await give(reporter.token, { stillExists: true });
    expect(again.status).toBe(409);

    const mine = await request(app).get(`${API}/issues/${issue.id}/feedback/me`).set(auth(reporter.token));
    expect(mine.status).toBe(200);
    expect(mine.body).toEqual(res.body);
  });

  it('"still exists" reopens the issue and logs it; "fixed" leaves it resolved', async () => {
    await resolve();
    const res = await give(reporter.token, { stillExists: true, comment: 'Still wobbling' });
    expect(res.status).toBe(201);
    const got = await request(app).get(`${API}/issues/${issue.id}`).set(auth(reporter.token));
    expect(got.body).toMatchObject({ status: 'reopened', resolvedAt: null, reopenCount: 1 });
    const ups = await request(app).get(`${API}/issues/${issue.id}/updates`).set(auth(reporter.token));
    const last = ups.body.at(-1);
    expect(last).toMatchObject({ action: 'reopened', newStatus: 'reopened', note: 'Still wobbling' });
  });

  it('"fixed" feedback does not change the status', async () => {
    await resolve();
    expect((await give(reporter.token)).status).toBe(201);
    const got = await request(app).get(`${API}/issues/${issue.id}`).set(auth(reporter.token));
    expect(got.body).toMatchObject({ status: 'resolved', reopenCount: 0 });
  });

  it('validates the feedback body', async () => {
    await resolve();
    expect((await give(reporter.token, { comment: 'missing flag' })).status).toBe(400);
    expect((await give(reporter.token, { stillExists: true, comment: 'x'.repeat(501) })).status).toBe(400);
  });
});

describeDb('photo access', () => {
  let app;
  let config;
  let user;
  let photoPath;
  beforeAll(async () => {
    ({ app, config } = await setupTestApp());
    await resetDb();
    user = await registerUser(app);
    const issue = await createIssue(app, user.token, {}, [{ buf: JPEG, name: 'x.jpg' }]);
    photoPath = issue.photoPaths[0];
    // A file just outside the photo tree that traversal attempts would try to reach.
    fs.writeFileSync(path.join(config.uploadsDir, 'secret.txt'), 'top secret');
  });
  afterAll(closePool);

  it('requires authentication', async () => {
    const res = await request(app).get(`${API}/photos/${photoPath}`);
    expect(res.status).toBe(401);
  });

  it('streams the photo to any authenticated user', async () => {
    const other = await registerUser(app);
    const res = await request(app).get(`${API}/photos/${photoPath}`).set(auth(other.token));
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toBe('image/jpeg');
  });

  it('returns 404 for a well-formed path that does not exist', async () => {
    const res = await request(app)
      .get(`${API}/photos/${photoPath.replace(/[0-9a-f]{8}-/, '00000000-')}`)
      .set(auth(user.token));
    expect(res.status).toBe(404);
  });

  it.each([
    '/photos/../secret.txt',
    '/photos/%2e%2e/secret.txt',
    '/photos/..%2fsecret.txt',
    '/photos/issues/..%2f..%2fsecret.txt',
    '/photos/%2e%2e%2f%2e%2e%2fetc%2fpasswd',
    '/photos/issues/%2e%2e/%2e%2e/secret.txt',
    '/photos/.tmp/anything',
    '/photos/secret.txt',
  ])('rejects traversal attempt %s', async (p) => {
    const res = await rawGet(app, `${API}${p}`, auth(user.token));
    expect([400, 404]).toContain(res.status);
    expect(res.body).not.toContain('top secret');
  });
});
