// Usage: npm run seed-demo   (inside the api container: docker compose exec api npm run seed-demo)
//
// Adds demo staff, students and ~30 realistic issues with consistent history
// and feedback. Safe to run more than once: it stops if the demo staff
// account already exists. All demo accounts use the password "password123".
import { loadConfig } from '../src/config.js';
import { closePool, withTransaction } from '../src/db.js';
import { hashPassword } from '../src/auth/passwords.js';

const PASSWORD = 'password123';
const MARKER_EMAIL = 'rohan.mehta@adit.ac.in';

const STAFF = [
  { email: MARKER_EMAIL, name: 'Rohan Mehta', dept: 'Facilities', avatar: 'bolt' },
  { email: 'sanjay.patel@adit.ac.in', name: 'Sanjay Patel', dept: 'Facilities · Plumbing', avatar: 'wave' },
  { email: 'kavita.joshi@adit.ac.in', name: 'Kavita Joshi', dept: 'Facilities · Electrical', avatar: 'sun' },
];

const STUDENTS = [
  { email: 'aarav.shah@adit.ac.in', name: 'Aarav Shah', dept: 'Computer Engineering', avatar: 'spark' },
  { email: 'diya.patel@adit.ac.in', name: 'Diya Patel', dept: 'Information Technology', avatar: 'heart' },
  { email: 'kabir.desai@adit.ac.in', name: 'Kabir Desai', dept: 'Mechanical Engineering', avatar: 'leaf' },
  { email: 'meera.iyer@adit.ac.in', name: 'Meera Iyer', dept: 'Electronics & Communication', avatar: 'star' },
  { email: 'vihaan.trivedi@adit.ac.in', name: 'Vihaan Trivedi', dept: 'Civil Engineering', avatar: 'book' },
  { email: 'ananya.rao@adit.ac.in', name: 'Ananya Rao', dept: 'Electrical Engineering', avatar: null },
];

// [title, description, category, building, location, status, priority,
//  reporter (student index), assignee (staff index | null), hours ago,
//  hours to resolve (resolved/reopened only), resolution note]
const ISSUES = [
  ['Ceiling fan not working in Room 204', 'The ceiling fan does not start even on full regulator. Room gets very hot during afternoon lectures.', 'electrical', 'engineering-block', 'Second floor, Room 204', 'inProgress', 'medium', 0, 2, 30],
  ['Washbasin leaking in washroom', 'Water keeps leaking from below the washbasin and the floor stays wet and slippery.', 'plumbing', 'hostel', 'Hostel B · 1F washroom', 'reported', 'high', 1, null, 5],
  ['Exposed wiring near Lab 3 door', 'A junction box cover is missing and live-looking wires are exposed at shoulder height next to the lab door.', 'safety', 'science-block', 'Ground floor, outside Lab 3', 'reported', 'urgent', 3, null, 6],
  ["Projector won't detect HDMI", 'The seminar hall projector shows "No signal" with every laptop we tried. The HDMI cable looks fine.', 'it', 'library', 'Seminar Hall', 'inProgress', 'high', 2, 0, 26],
  ['Broken bench in canteen', 'One of the long benches has a cracked seat plank and a loose leg. It wobbles when two people sit.', 'furniture', 'canteen', 'North seating area', 'resolved', 'medium', 4, 0, 60, 20, 'Replaced the cracked seat plank and bolted both legs.'],
  ['Overflowing bins near gate 2', 'Both dustbins near gate 2 are overflowing and garbage is spread on the road.', 'cleanliness', 'grounds', 'Main Gate 2 · Parking', 'reopened', 'medium', 5, 1, 80, 10, 'Bins cleared and extra bin placed.'],
  ['Wi-Fi dead zone on 2nd floor', 'No Wi-Fi signal at all in the reading area on the second floor. Students cannot access e-journals.', 'it', 'library', '2F reading area', 'reopened', 'high', 0, 0, 120, 30, 'Access point restarted and re-mounted.'],
  ['Loose handrail on staircase', 'The handrail on staircase B is loose at the landing and moves when you hold it.', 'safety', 'admin-block', 'Stair B, first landing', 'reported', 'medium', 0, null, 1],
  ['Tube light flickering', 'Two tube lights at the back of the classroom keep flickering, which is distracting during lectures.', 'electrical', 'engineering-block', 'Third floor, Room 312', 'reported', 'low', 2, null, 9],
  ['Water cooler not cooling', 'The water cooler on the ground floor dispenses warm water only.', 'plumbing', 'workshop', 'Ground floor entrance', 'inProgress', 'medium', 3, 1, 48],
  ['Door lock broken in Lab 5', 'The lab door lock is jammed and the door cannot be locked after practicals.', 'furniture', 'science-block', 'First floor, Lab 5', 'inProgress', 'high', 4, 0, 20],
  ['Smart board not responding to touch', 'The smart board powers on but does not respond to the pen or touch.', 'it', 'engineering-block', 'Second floor, Room 210', 'reported', 'medium', 1, null, 14],
  ['Washroom very dirty', 'The boys washroom has not been cleaned since morning and there is a strong smell.', 'cleanliness', 'engineering-block', 'Ground floor washroom', 'resolved', 'high', 2, 1, 50, 3, 'Deep cleaned and housekeeping schedule updated.'],
  ['AC dripping water on desks', 'The split AC in the computer lab drips water on the desks below.', 'electrical', 'engineering-block', 'Computer Lab 2', 'resolved', 'medium', 0, 2, 96, 18, 'Drain pipe was blocked; cleared and re-routed.'],
  ['Basketball hoop net torn', 'The net on the east basketball hoop is torn and hanging loose.', 'other', 'sports-complex', 'Outdoor court, east hoop', 'reported', 'low', 4, null, 40],
  ['Broken window pane in classroom', 'A window pane is cracked with sharp edges near the last bench.', 'safety', 'science-block', 'Second floor, Room 205', 'inProgress', 'urgent', 5, 0, 10],
  ['Tap running continuously', 'The tap near the canteen hand-wash area does not close fully and water keeps running.', 'plumbing', 'canteen', 'Hand-wash area', 'resolved', 'medium', 1, 1, 130, 6, 'Washer replaced, tap closes fully now.'],
  ['Chairs missing in auditorium row F', 'Four chairs are missing from row F, students have to stand during events.', 'furniture', 'auditorium', 'Row F, left side', 'reported', 'low', 3, null, 70],
  ['Library printer jammed', 'The library printer shows a paper jam error and does not print.', 'it', 'library', 'Ground floor, print corner', 'resolved', 'medium', 2, 0, 75, 4, 'Removed stuck paper and cleaned the rollers.'],
  ['Cobwebs and dust in corridor', 'The corridor ceiling has heavy cobwebs and the fans are covered in dust.', 'cleanliness', 'admin-block', 'First floor corridor', 'reported', 'low', 5, null, 22],
  ['Street light off near hostel', 'The street light on the path to the hostel is off, the path is very dark at night.', 'electrical', 'hostel', 'Path between Hostel A and B', 'inProgress', 'high', 1, 2, 36],
  ['Fire extinguisher expired', 'The fire extinguisher outside the workshop has an expiry date from last year.', 'safety', 'workshop', 'Main entrance', 'resolved', 'urgent', 3, 0, 160, 12, 'Replaced with a new certified extinguisher.'],
  ['Drinking water tastes odd', 'Water from the RO purifier on the second floor tastes salty.', 'plumbing', 'library', 'Second floor water point', 'reported', 'high', 4, null, 3],
  ['Notice board glass broken', 'The glass of the department notice board is broken and pieces are on the floor.', 'furniture', 'admin-block', 'Ground floor lobby', 'resolved', 'medium', 0, 0, 200, 8, 'Glass replaced and area cleaned.'],
  ['Gym treadmill not starting', 'The second treadmill in the gym shows an error code and does not start.', 'other', 'sports-complex', 'Indoor gym', 'inProgress', 'medium', 2, 2, 55],
  ['Leaking roof during rain', 'Rain water drips from the ceiling near the stage, a bucket has been placed.', 'other', 'auditorium', 'Near stage, right wing', 'reported', 'high', 5, null, 18],
  ['Lab computer will not boot', 'PC number 14 in the lab shows a black screen after the logo.', 'it', 'engineering-block', 'Computer Lab 1, PC 14', 'resolved', 'low', 3, 0, 110, 24, 'Reinstalled the OS and replaced the SSD.'],
  ['Garbage near canteen kitchen', 'Food waste is piled up behind the canteen kitchen and attracting stray dogs.', 'cleanliness', 'canteen', 'Behind kitchen', 'inProgress', 'high', 4, 1, 8],
  ['Electric socket sparking', 'The socket next to the teacher desk sparks when a charger is plugged in.', 'electrical', 'science-block', 'Ground floor, Room 101', 'resolved', 'urgent', 1, 2, 30, 2, 'Replaced the burnt socket and checked the circuit.'],
  ['Parking area potholes', 'Large potholes in the two-wheeler parking fill with water and are slippery.', 'other', 'grounds', 'Two-wheeler parking', 'reported', 'medium', 0, null, 90],
];

const FEEDBACK = {
  // issue index → [stillExists, comment]
  4: [false, 'Bench feels solid now, thanks!'],
  5: [true, 'Bins are overflowing again by evening.'],
  6: [true, 'Signal still drops near the windows.'],
  12: [false, null],
  13: [false, 'No more dripping.'],
  16: [false, 'Fixed, thank you.'],
  28: [false, null],
};

// issue index -> student indexes who said "me too" (never the reporter; open issues only)
const UPVOTES = {
  1: [0, 2, 4, 5], 2: [0, 1, 2, 4], 3: [0, 1, 4], 7: [1, 2, 3], 8: [0, 1], 9: [0, 1, 5],
  11: [0, 2], 19: [0, 1, 2], 20: [0, 2, 3], 22: [0, 1, 2, 5], 26: [1, 2, 3], 29: [1, 3, 4],
};

const HOUR = 3600 * 1000;

async function main() {
  const config = loadConfig();
  const hash = await hashPassword(PASSWORD, config.bcryptRounds);

  const result = await withTransaction(async (db) => {
    const { rows: existing } = await db.query('SELECT 1 FROM users WHERE email = $1', [MARKER_EMAIL]);
    if (existing.length > 0) return 'already-seeded';

    const insertUser = async (u, role) => {
      const { rows } = await db.query(
        `INSERT INTO users (email, password_hash, display_name, role, department, avatar)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (email) DO UPDATE SET role = EXCLUDED.role
         RETURNING id, display_name`,
        [u.email, hash, u.name, role, u.dept, u.avatar],
      );
      return rows[0];
    };
    const staff = [];
    for (const u of STAFF) staff.push(await insertUser(u, 'admin'));
    const students = [];
    for (const u of STUDENTS) students.push(await insertUser(u, 'student'));

    const now = Date.now();
    // Oldest first so issue numbers follow creation order.
    const ordered = ISSUES.map((spec, index) => ({ spec, index })).sort(
      (a, b) => b.spec[9] - a.spec[9],
    );

    for (const { spec, index } of ordered) {
      const [title, description, category, building, location, status, priority,
        reporterIdx, assigneeIdx, hoursAgo, hoursToResolve, resolutionNote] = spec;
      const reporter = students[reporterIdx];
      const assignee = assigneeIdx == null ? null : staff[assigneeIdx];
      const admin = assignee ?? staff[0];
      const createdAt = new Date(now - hoursAgo * HOUR);
      // Keep every event in the past, in order.
      const at = (h) => new Date(Math.min(createdAt.getTime() + h * HOUR, now - 5 * 60 * 1000));

      const events = [
        { actor: reporter.id, action: 'created', newStatus: 'reported', at: createdAt },
      ];
      if (priority !== 'medium') {
        events.push({ actor: admin.id, action: 'priorityChanged', oldPriority: 'medium', newPriority: priority, at: at(0.3) });
      }
      if (assignee) {
        events.push({ actor: staff[0].id, action: 'assigned', note: `Assigned to ${assignee.display_name}`, at: at(0.6) });
      }
      let resolvedAt = null;
      let reopenCount = 0;
      if (status !== 'reported') {
        events.push({ actor: admin.id, action: 'statusChanged', oldStatus: 'reported', newStatus: 'inProgress', note: 'Work started', at: at(1) });
      }
      if (status === 'resolved' || status === 'reopened') {
        const done = at(hoursToResolve);
        events.push({ actor: admin.id, action: 'statusChanged', oldStatus: 'inProgress', newStatus: 'resolved', note: resolutionNote, at: done });
        resolvedAt = done;
      }
      if (status === 'reopened') {
        events.push({ actor: admin.id, action: 'reopened', oldStatus: 'resolved', newStatus: 'reopened', note: 'Reporter says the problem is back', at: at(hoursToResolve + 2) });
        resolvedAt = null;
        reopenCount = 1;
      }
      const updatedAt = events[events.length - 1].at;

      const { rows } = await db.query(
        `INSERT INTO issues (title, description, category, building_id, location_detail,
           reporter_id, reporter_display_name, status, priority, assigned_to,
           resolution_note, created_at, updated_at, resolved_at, reopen_count)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
         RETURNING id`,
        [title, description, category, building, location, reporter.id, reporter.display_name,
          status, priority, assignee?.id ?? null,
          status === 'resolved' || status === 'reopened' ? resolutionNote : null,
          createdAt, updatedAt, resolvedAt, reopenCount],
      );
      const issueId = rows[0].id;

      for (const e of events) {
        await db.query(
          `INSERT INTO issue_updates (issue_id, actor_id, action, old_status, new_status,
             old_priority, new_priority, note, created_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
          [issueId, e.actor, e.action, e.oldStatus ?? null, e.newStatus ?? null,
            e.oldPriority ?? null, e.newPriority ?? null, e.note ?? null, e.at],
        );
      }

      for (const voter of UPVOTES[index] ?? []) {
        if (voter === reporterIdx) continue;
        await db.query(
          'INSERT INTO issue_upvotes (issue_id, user_id, created_at) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING',
          [issueId, students[voter].id, at(2 + voter)],
        );
      }

      const fb = FEEDBACK[index];
      if (fb) {
        await db.query(
          `INSERT INTO issue_feedback (issue_id, reporter_id, still_exists, comment, created_at)
           VALUES ($1,$2,$3,$4,$5)`,
          [issueId, reporter.id, fb[0], fb[1], at(hoursToResolve + 1)],
        );
      }
    }
    return 'seeded';
  });

  if (result === 'already-seeded') {
    console.log('Demo data already present (found rohan.mehta@adit.ac.in). Nothing changed.');
  } else {
    console.log(`Seeded ${STAFF.length} staff, ${STUDENTS.length} students and ${ISSUES.length} issues.`);
    console.log(`All demo accounts use the password "${PASSWORD}". Admin: ${MARKER_EMAIL}`);
  }
}

try {
  await main();
} catch (err) {
  console.error(`Seeding failed: ${err.message}`);
  process.exitCode = 1;
} finally {
  await closePool();
}
