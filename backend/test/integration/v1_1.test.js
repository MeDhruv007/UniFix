// API.md "v1.1 additions": number/code/assignedToName/actorName, search + filters + sort,
// extended stats, GET /staff, assign to other/unassign, and the 002 migration backfill.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { closePool, getPool, query } from '../../src/db.js';
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

const MIGRATIONS = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'migrations');
const CATEGORY_ZEROS = { electrical: 0, plumbing: 0, cleanliness: 0, furniture: 0, it: 0, safety: 0, other: 0 };

describeDb('v1.1', () => {
  let app;
  let student;
  let admin;
  let admin2;
  beforeAll(async () => {
    ({ app } = await setupTestApp());
  });
  beforeEach(async () => {
    await resetDb();
    student = await registerUser(app, { displayName: 'Asha Patel' });
    admin = await registerAdmin(app, { displayName: 'Ravi Admin' });
    admin2 = await registerAdmin(app, { displayName: 'Meera Staff' });
  });
  afterAll(closePool);

  const list = (qs, token = student.token) => request(app).get(`${API}/issues${qs}`).set(auth(token));
  const ids = (res) => res.body.items.map((i) => i.id);
  const updatesOf = async (id) => (await request(app).get(`${API}/issues/${id}/updates`).set(auth(student.token))).body;
  const assign = (id, body, token = admin.token) => {
    const req = request(app).post(`${API}/issues/${id}/assign`).set(auth(token));
    return body === undefined ? req : req.send(body);
  };
  const stats = (qs = '', token = admin.token) => request(app).get(`${API}/issues/stats${qs}`).set(auth(token));
  const setCreated = (id, ago) => query(`UPDATE issues SET created_at = now() - $2::interval WHERE id = $1`, [id, ago]);

  // ---- Object fields ------------------------------------------------------------------------
  describe('number, code, assignedToName, actorName', () => {
    it('numbers issues sequentially from 1 and derives the code', async () => {
      const a = await createIssue(app, student.token);
      const b = await createIssue(app, student.token);
      const c = await createIssue(app, admin.token);
      expect([a.number, b.number, c.number]).toEqual([1, 2, 3]);
      expect([a.code, b.code, c.code]).toEqual(['FMC-0001', 'FMC-0002', 'FMC-0003']);
      expect(a).toMatchObject({ assignedTo: null, assignedToName: null });

      await query('UPDATE issues SET number = 12345 WHERE id = $1', [b.id]);
      const big = await request(app).get(`${API}/issues/${b.id}`).set(auth(student.token));
      expect(big.body).toMatchObject({ number: 12345, code: 'FMC-12345' });
      const listed = await list('');
      expect(listed.body.items.find((i) => i.id === b.id).code).toBe('FMC-12345');
    });

    it('rejects duplicate numbers at the database level', async () => {
      const a = await createIssue(app, student.token);
      const b = await createIssue(app, student.token);
      await expect(query('UPDATE issues SET number = $2 WHERE id = $1', [b.id, a.number])).rejects.toThrow(/issues_number_key/);
    });

    it('returns assignedToName on every issue response and actorName (read-time) on updates', async () => {
      const issue = await createIssue(app, student.token);
      const assigned = await assign(issue.id, { assigneeId: admin2.user.id });
      expect(assigned.body).toMatchObject({ assignedTo: admin2.user.id, assignedToName: 'Meera Staff' });

      const got = await request(app).get(`${API}/issues/${issue.id}`).set(auth(student.token));
      expect(got.body.assignedToName).toBe('Meera Staff');
      expect((await list('')).body.items[0].assignedToName).toBe('Meera Staff');

      const prio = await request(app)
        .patch(`${API}/issues/${issue.id}/priority`)
        .set(auth(admin.token))
        .send({ from: 'medium', to: 'high' });
      expect(prio.body.assignedToName).toBe('Meera Staff');

      let updates = await updatesOf(issue.id);
      expect(updates.map((u) => [u.action, u.actorName])).toEqual([
        ['created', 'Asha Patel'],
        ['assigned', 'Ravi Admin'],
        ['priorityChanged', 'Ravi Admin'],
      ]);

      // Names are read at read time, so a rename shows up everywhere.
      await request(app).patch(`${API}/me`).set(auth(admin2.token)).send({ displayName: 'Meera S.' });
      await request(app).patch(`${API}/me`).set(auth(admin.token)).send({ displayName: 'Ravi K.' });
      expect((await request(app).get(`${API}/issues/${issue.id}`).set(auth(student.token))).body.assignedToName).toBe('Meera S.');
      updates = await updatesOf(issue.id);
      expect(updates[1].actorName).toBe('Ravi K.');
    });
  });

  // ---- Search -------------------------------------------------------------------------------
  describe('GET /issues?q=', () => {
    let fan;
    let tap;
    let wifi;
    let pct;
    let quote;
    beforeEach(async () => {
      fan = await createIssue(app, student.token, { title: 'Ceiling FAN broken', locationDetail: 'Room 204' });
      tap = await createIssue(app, student.token, {
        title: 'Leaking tap in washroom',
        category: 'plumbing',
        buildingId: 'hostel',
        locationDetail: 'Block B ground floor',
      });
      wifi = await createIssue(app, student.token, { title: 'WiFi down 100_mbps', category: 'it', locationDetail: 'Lab 3' });
      pct = await createIssue(app, student.token, { title: 'Projector at 50% brightness', locationDetail: 'Seminar hall' });
      quote = await createIssue(app, student.token, { title: "Principal's office door", locationDetail: 'Back\\slash wing' });
      await query('UPDATE issues SET number = 483 WHERE id = $1', [tap.id]);
    });

    it('matches title, locationDetail and buildingId case-insensitively', async () => {
      expect(ids(await list('?q=fan'))).toEqual([fan.id]);
      expect(ids(await list('?q=CEILING%20fan'))).toEqual([fan.id]);
      expect(ids(await list('?q=room%20204'))).toEqual([fan.id]);
      expect(ids(await list('?q=HOSTEL'))).toEqual([tap.id]);
      expect(ids(await list('?q=%20%20lab%203%20%20'))).toEqual([wifi.id]); // trimmed
      const none = await list('?q=nothing-like-this');
      expect(none.body).toEqual({ items: [], total: 0 });
    });

    it.each(['FMC-0483', 'fmc-0483', 'FMC-483', '0483', '483', '000483'])('finds issue 483 by code form %s', async (q) => {
      const res = await list(`?q=${encodeURIComponent(q)}`);
      expect(res.status).toBe(200);
      expect(ids(res)).toEqual([tap.id]);
      expect(res.body.items[0].code).toBe('FMC-0483');
    });

    it('does not do partial number matches and handles code-like non-numbers', async () => {
      expect(ids(await list('?q=48'))).toEqual([]);
      expect(ids(await list('?q=FMC-'))).toEqual([]);
      expect(ids(await list('?q=000'))).toEqual([]); // all zeros: no number, no text match
      expect(ids(await list('?q=FMC-48x'))).toEqual([]);
      expect((await list('?q=99999999999999999999')).status).toBe(200);
      // "100" matches issue number 100 (none) and the title text "100_mbps".
      expect(ids(await list('?q=100'))).toEqual([wifi.id]);
    });

    it('treats LIKE wildcards, quotes and backslashes literally (no injection)', async () => {
      expect(ids(await list(`?q=${encodeURIComponent('%')}`))).toEqual([pct.id]);
      expect(ids(await list(`?q=${encodeURIComponent('50%')}`))).toEqual([pct.id]);
      expect(ids(await list(`?q=${encodeURIComponent('_')}`))).toEqual([wifi.id]);
      expect(ids(await list(`?q=${encodeURIComponent("'")}`))).toEqual([quote.id]);
      expect(ids(await list(`?q=${encodeURIComponent('\\')}`))).toEqual([quote.id]);
      for (const evil of ["' OR '1'='1", "'; DROP TABLE issues; --", '%%', '%_%', '") OR 1=1 --']) {
        const res = await list(`?q=${encodeURIComponent(evil)}`);
        expect(res.status, evil).toBe(200);
        expect(res.body.total, evil).toBe(0);
      }
      const { rows } = await query('SELECT count(*)::int AS n FROM issues');
      expect(rows[0].n).toBe(5);
    });

    it('validates q: blank = no search, over 100 chars or repeated → 400', async () => {
      expect((await list('?q=')).body.total).toBe(5);
      expect((await list('?q=%20%20%20')).body.total).toBe(5);
      expect((await list(`?q=${'a'.repeat(100)}`)).status).toBe(200);
      const long = await list(`?q=${'a'.repeat(101)}`);
      expect(long.status).toBe(400);
      expect(long.body.error.code).toBe('VALIDATION');
      expect((await list('?q=a&q=b')).status).toBe(400);
    });

    it('combines q with other filters and paginates with the right total', async () => {
      expect(ids(await list('?q=204&category=plumbing'))).toEqual([]);
      expect(ids(await list('?q=o&category=plumbing'))).toEqual([tap.id]);
      const page = await list('?q=o&limit=1&sort=oldest');
      expect(page.body.total).toBe(5);
      expect(ids(page)).toEqual([fan.id]);
    });
  });

  // ---- Filters & sort -------------------------------------------------------------------------
  describe('GET /issues filters and sort', () => {
    let a; // reported, urgent, assigned
    let b; // inProgress, medium, unassigned
    let c; // resolved, urgent, assigned
    let d; // reopened, low, unassigned
    beforeEach(async () => {
      a = await createIssue(app, student.token, { title: 'Issue number A' });
      b = await createIssue(app, student.token, { title: 'Issue number B' });
      c = await createIssue(app, admin.token, { title: 'Issue number C' });
      d = await createIssue(app, student.token, { title: 'Issue number D' });
      await setCreated(a.id, '4 minutes');
      await setCreated(b.id, '3 minutes');
      await setCreated(c.id, '2 minutes');
      await setCreated(d.id, '1 minute');
      await query(`UPDATE issues SET priority = 'urgent', assigned_to = $2 WHERE id = $1`, [a.id, admin.user.id]);
      await query(`UPDATE issues SET status = 'inProgress' WHERE id = $1`, [b.id]);
      await query(
        `UPDATE issues SET status = 'resolved', resolved_at = now(), priority = 'urgent', assigned_to = $2 WHERE id = $1`,
        [c.id, admin2.user.id],
      );
      await query(`UPDATE issues SET status = 'reopened', priority = 'low' WHERE id = $1`, [d.id]);
    });

    it('filters by open, priority and assigned, alone and combined', async () => {
      expect(ids(await list('?open=true'))).toEqual([d.id, b.id, a.id]);
      expect((await list('?open=true')).body.total).toBe(3);
      expect(ids(await list('?open=false'))).toEqual([d.id, c.id, b.id, a.id]);
      expect(ids(await list('?open=true&status=inProgress'))).toEqual([b.id]);
      expect(ids(await list('?open=true&status=resolved'))).toEqual([]);
      expect(ids(await list('?priority=urgent'))).toEqual([c.id, a.id]);
      expect(ids(await list('?priority=urgent&open=true'))).toEqual([a.id]);
      expect(ids(await list('?assigned=true'))).toEqual([c.id, a.id]);
      expect(ids(await list('?assigned=false'))).toEqual([d.id, b.id]);
      expect(ids(await list('?assigned=false&open=true&priority=low'))).toEqual([d.id]);
      expect(ids(await list('?assigned=true&mine=true'))).toEqual([a.id]);
      expect(ids(await list('?open=true&priority=&assigned=&sort='))).toEqual([d.id, b.id, a.id]);
      // assignedToMe: only the caller's assignments.
      expect(ids(await list('?assignedToMe=true', admin.token))).toEqual([a.id]);
      expect(ids(await list('?assignedToMe=true', admin2.token))).toEqual([c.id]);
      expect(ids(await list('?assignedToMe=true&open=true', admin2.token))).toEqual([]);
    });

    it('sorts newest (default) or oldest', async () => {
      expect(ids(await list(''))).toEqual([d.id, c.id, b.id, a.id]);
      expect(ids(await list('?sort=newest'))).toEqual([d.id, c.id, b.id, a.id]);
      expect(ids(await list('?sort=oldest'))).toEqual([a.id, b.id, c.id, d.id]);
      expect(ids(await list('?sort=oldest&open=true&limit=2&offset=1'))).toEqual([b.id, d.id]);
    });

    it('rejects bad filter values with 400', async () => {
      for (const bad of ['?open=yes', '?open=1', '?priority=critical', '?assigned=maybe', '?sort=random', '?sort=NEWEST']) {
        const res = await list(bad);
        expect(res.status, bad).toBe(400);
        expect(res.body.error.code).toBe('VALIDATION');
      }
    });
  });

  // ---- Stats ----------------------------------------------------------------------------------
  describe('GET /issues/stats (extended)', () => {
    it('returns zeros and avgResolutionHours null when there is nothing', async () => {
      const res = await stats();
      expect(res.status).toBe(200);
      expect(res.body).toEqual({
        reported: 0, inProgress: 0, resolved: 0, reopened: 0, total: 0,
        open: 0, urgent: 0, unassigned: 0, assignedToMe: 0, createdLast24h: 0, resolvedThisWeek: 0,
        avgResolutionHours: null, openByCategory: CATEGORY_ZEROS,
      });
    });

    it('computes campus-wide numbers for admins', async () => {
      const mk = (fields) => createIssue(app, student.token, fields);
      const e1 = await mk({ category: 'electrical' });        // open, urgent, unassigned
      const e2 = await mk({ category: 'electrical' });        // open (inProgress), assigned
      const p1 = await mk({ category: 'plumbing' });          // open (reopened), created 2 days ago
      const r1 = await createIssue(app, admin.token, { category: 'it' }); // resolved 10h after creation, 2 days ago
      const r2 = await mk({ category: 'it' });                // resolved 5h15m after creation, 8 days ago (urgent: ignored)
      await query(`UPDATE issues SET priority = 'urgent' WHERE id = ANY($1)`, [[e1.id, r2.id]]);
      await setStatus(app, admin.token, e2.id, { from: 'reported', to: 'inProgress' });
      await assign(e2.id);
      await query(`UPDATE issues SET status = 'reopened', reopen_count = 1, created_at = now() - interval '2 days' WHERE id = $1`, [p1.id]);
      await query(
        `UPDATE issues SET status = 'resolved', created_at = now() - interval '2 days 10 hours',
                resolved_at = now() - interval '2 days' WHERE id = $1`,
        [r1.id],
      );
      await query(
        `UPDATE issues SET status = 'resolved', created_at = now() - interval '8 days 5 hours 15 minutes',
                resolved_at = now() - interval '8 days' WHERE id = $1`,
        [r2.id],
      );

      const res = await stats();
      expect(res.status).toBe(200);
      expect(res.body).toEqual({
        reported: 1, inProgress: 1, resolved: 2, reopened: 1, total: 5,
        open: 3, urgent: 1, unassigned: 2, assignedToMe: 1, createdLast24h: 2, resolvedThisWeek: 1,
        avgResolutionHours: 7.6, // (10 + 5.25) / 2 = 7.625 → 7.6
        openByCategory: { ...CATEGORY_ZEROS, electrical: 2, plumbing: 1 },
      });
      expect((await stats('?mine=false')).body.total).toBe(5);

      // mine=true is limited to the caller's own reports, for admins too.
      const mineAdmin = await stats('?mine=true');
      expect(mineAdmin.body).toMatchObject({
        total: 1, resolved: 1, open: 0, avgResolutionHours: 10, openByCategory: CATEGORY_ZEROS,
      });
      const mineStudent = await stats('?mine=true', student.token);
      expect(mineStudent.status).toBe(200);
      expect(mineStudent.body).toMatchObject({
        total: 4, open: 3, resolved: 1, urgent: 1, unassigned: 2, createdLast24h: 2, resolvedThisWeek: 0,
        avgResolutionHours: 5.3, // 5.25 rounded to 1 decimal
        openByCategory: { ...CATEGORY_ZEROS, electrical: 2, plumbing: 1 },
      });
    });

    it('requires mine=true for students (403 otherwise) and validates mine', async () => {
      await createIssue(app, student.token);
      for (const qs of ['', '?mine=false', '?mine=']) {
        const res = await stats(qs, student.token);
        expect(res.status, qs).toBe(403);
        expect(res.body.error.code).toBe('FORBIDDEN');
      }
      const other = await registerUser(app);
      const empty = await stats('?mine=true', other.token);
      expect(empty.status).toBe(200);
      expect(empty.body).toMatchObject({ total: 0, avgResolutionHours: null });
      expect((await stats('?mine=yes', student.token)).status).toBe(400);
    });
  });

  // ---- Staff ----------------------------------------------------------------------------------
  describe('GET /staff', () => {
    it('lists active admins sorted by name, admin only', async () => {
      const zed = await registerAdmin(app, { displayName: 'zed admin' });
      const gone = await registerAdmin(app, { displayName: 'Anil Former' });
      await query('UPDATE users SET is_active = false WHERE id = $1', [gone.user.id]);

      const res = await request(app).get(`${API}/staff`).set(auth(admin.token));
      expect(res.status).toBe(200);
      expect(res.body).toEqual([
        { id: admin2.user.id, displayName: 'Meera Staff' },
        { id: admin.user.id, displayName: 'Ravi Admin' },
        { id: zed.user.id, displayName: 'zed admin' },
      ]);

      const denied = await request(app).get(`${API}/staff`).set(auth(student.token));
      expect(denied.status).toBe(403);
      expect(denied.body.error.code).toBe('FORBIDDEN');
      expect((await request(app).get(`${API}/staff`)).status).toBe(401);
    });
  });

  // ---- Assign ---------------------------------------------------------------------------------
  describe('POST /issues/:id/assign with assigneeId', () => {
    let issue;
    beforeEach(async () => {
      issue = await createIssue(app, student.token);
    });

    it('assigns to another admin, reassigns, unassigns, with history and no-ops', async () => {
      const toOther = await assign(issue.id, { assigneeId: admin2.user.id });
      expect(toOther.status).toBe(200);
      expect(toOther.body).toMatchObject({ assignedTo: admin2.user.id, assignedToName: 'Meera Staff' });

      const same = await assign(issue.id, { assigneeId: admin2.user.id }, admin2.token);
      expect(same.status).toBe(200);
      expect(same.body.assignedTo).toBe(admin2.user.id);

      const toSelf = await assign(issue.id, {});
      expect(toSelf.body).toMatchObject({ assignedTo: admin.user.id, assignedToName: 'Ravi Admin' });
      expect((await assign(issue.id)).body.assignedTo).toBe(admin.user.id); // no body: still the caller, no-op

      const unassigned = await assign(issue.id, { assigneeId: null }, admin2.token);
      expect(unassigned.status).toBe(200);
      expect(unassigned.body).toMatchObject({ assignedTo: null, assignedToName: null });
      expect((await assign(issue.id, { assigneeId: null })).status).toBe(200); // already unassigned: no-op

      const updates = await updatesOf(issue.id);
      expect(updates.map((u) => [u.action, u.actorId, u.note])).toEqual([
        ['created', student.user.id, null],
        ['assigned', admin.user.id, 'Assigned to Meera Staff'],
        ['assigned', admin.user.id, 'Assigned to Ravi Admin'],
        ['assigned', admin2.user.id, 'Unassigned'],
      ]);
    });

    it('rejects assignees that are not active admins with 400 and changes nothing', async () => {
      const gone = await registerAdmin(app, { displayName: 'Anil Former' });
      await query('UPDATE users SET is_active = false WHERE id = $1', [gone.user.id]);
      const bad = [
        { assigneeId: student.user.id },
        { assigneeId: gone.user.id },
        { assigneeId: '7d7c0a3e-4b6e-4c1f-9a4f-2f0c7b6c9d11' },
        { assigneeId: 'not-a-uuid' },
        { assigneeId: 42 },
        { assigneeId: '' },
        [admin2.user.id],
      ];
      for (const body of bad) {
        const res = await assign(issue.id, body);
        expect(res.status, JSON.stringify(body)).toBe(400);
        expect(res.body.error.code).toBe('VALIDATION');
      }
      const after = await request(app).get(`${API}/issues/${issue.id}`).set(auth(student.token));
      expect(after.body.assignedTo).toBeNull();
      expect(await updatesOf(issue.id)).toHaveLength(1);
    });

    it('still checks role and issue existence', async () => {
      expect((await assign(issue.id, { assigneeId: admin.user.id }, student.token)).status).toBe(403);
      const missing = await assign('7d7c0a3e-4b6e-4c1f-9a4f-2f0c7b6c9d11', { assigneeId: admin2.user.id });
      expect(missing.status).toBe(404);
    });
  });

  // ---- Migration 002 backfill -----------------------------------------------------------------
  describe('migration 002 backfill', () => {
    it('numbers existing rows in created_at order without touching updated_at', async () => {
      const sql001 = fs.readFileSync(path.join(MIGRATIONS, '001_init.sql'), 'utf8');
      const sql002 = fs.readFileSync(path.join(MIGRATIONS, '002_v1_1.sql'), 'utf8');
      const client = await getPool().connect();
      try {
        await client.query('DROP SCHEMA IF EXISTS backfill_test CASCADE; CREATE SCHEMA backfill_test');
        await client.query('SET search_path TO backfill_test, public');
        await client.query(sql001);
        const { rows: [u] } = await client.query(
          `INSERT INTO users (email, password_hash, display_name) VALUES ('b@adit.ac.in', 'x', 'Backfill') RETURNING id`,
        );
        // Inserted in an order different from created_at order.
        const ages = ['1 day', '3 days', '2 days'];
        const inserted = [];
        for (const [i, age] of ages.entries()) {
          const { rows } = await client.query(
            `INSERT INTO issues (title, description, category, building_id, location_detail, reporter_id,
                                 reporter_display_name, created_at, updated_at)
             VALUES ($1, 'Long enough description', 'other', 'library', 'Desk', $2, 'Backfill',
                     now() - $3::interval, '2020-01-01T00:00:00Z')
             RETURNING id`,
            [`Backfill issue ${i}`, u.id, age],
          );
          inserted.push(rows[0].id);
        }
        await client.query(sql002);

        const { rows } = await client.query('SELECT id, number, updated_at FROM issues ORDER BY number');
        expect(rows.map((r) => r.id)).toEqual([inserted[1], inserted[2], inserted[0]]);
        expect(rows.map((r) => r.number)).toEqual([1, 2, 3]);
        for (const r of rows) expect(r.updated_at.toISOString()).toBe('2020-01-01T00:00:00.000Z');

        const { rows: [next] } = await client.query(
          `INSERT INTO issues (title, description, category, building_id, location_detail, reporter_id,
                               reporter_display_name)
           VALUES ('After migration', 'Long enough description', 'other', 'library', 'Desk', $1, 'Backfill')
           RETURNING number`,
          [u.id],
        );
        expect(next.number).toBe(4);

        // The updated_at trigger is re-enabled after the backfill.
        await client.query(`UPDATE issues SET title = 'Touched issue' WHERE number = 1`);
        const { rows: [touched] } = await client.query('SELECT updated_at FROM issues WHERE number = 1');
        expect(touched.updated_at.getUTCFullYear()).toBeGreaterThan(2020);
      } finally {
        await client.query('DROP SCHEMA IF EXISTS backfill_test CASCADE');
        await client.query('RESET search_path');
        client.release();
      }
    });
  });
});
