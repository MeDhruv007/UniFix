import { query } from './db.js';

export const USER_COLUMNS =
  'id, email, display_name, role, campus_id, department, avatar, is_active, created_at, updated_at';

/** DB row → API `User` object. Never includes the password hash. */
export function toUser(row) {
  return {
    id: row.id,
    displayName: row.display_name,
    email: row.email,
    role: row.role,
    campusId: row.campus_id,
    department: row.department ?? null,
    avatar: row.avatar ?? null,
    isActive: row.is_active,
    createdAt: row.created_at.toISOString(),
    updatedAt: row.updated_at.toISOString(),
  };
}

export async function findUserById(id, client = { query }) {
  const { rows } = await client.query(`SELECT ${USER_COLUMNS} FROM users WHERE id = $1`, [id]);
  return rows[0] ?? null;
}
