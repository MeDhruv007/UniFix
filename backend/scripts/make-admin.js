// Usage: npm run make-admin -- someone@adit.ac.in
import { closePool, query } from '../src/db.js';

const email = process.argv[2]?.trim().toLowerCase();
if (!email) {
  console.error('Usage: npm run make-admin -- <email>');
  process.exit(2);
}

try {
  const { rows } = await query(
    "UPDATE users SET role = 'admin' WHERE email = $1 RETURNING id, email, role",
    [email],
  );
  if (rows.length === 0) {
    console.error(`No user with email ${email}. Register the account first.`);
    process.exitCode = 1;
  } else {
    console.log(`${rows[0].email} is now an admin (id ${rows[0].id}).`);
  }
} catch (err) {
  console.error(`Failed: ${err.message}`);
  process.exitCode = 1;
} finally {
  await closePool();
}
