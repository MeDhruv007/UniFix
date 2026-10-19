/** DB rows → API objects (API.md "Objects" + "v1.1 additions"). Nullable fields are always present as null. */

const iso = (d) => (d ? d.toISOString() : null);

/** "FMC-" + number zero-padded to 4 digits; numbers >= 10000 print all their digits. */
export const issueCode = (number) => `FMC-${String(number).padStart(4, '0')}`;

/**
 * Columns for `SELECT ... FROM issues` and `INSERT/UPDATE issues ... RETURNING`. The assignee's
 * display name is read at query time through a scalar subquery, so RETURNING clauses get it too.
 * `viewerParam` is the SQL placeholder (e.g. '$3') bound to the caller's user id, for upvotedByMe.
 */
export const issueColumns = (viewerParam) => `id, number, campus_id, title, description, category, building_id, location_detail,
  photo_paths, reporter_id, reporter_display_name, status, priority, assigned_to,
  (SELECT au.display_name FROM users au WHERE au.id = issues.assigned_to) AS assigned_to_name,
  resolution_note, resolution_photo_paths, created_at, updated_at, resolved_at, reopen_count,
  (SELECT count(*)::int FROM issue_upvotes uv WHERE uv.issue_id = issues.id) AS upvote_count,
  EXISTS (SELECT 1 FROM issue_upvotes uv WHERE uv.issue_id = issues.id AND uv.user_id = ${viewerParam}) AS upvoted_by_me`;

export function toIssue(row) {
  return {
    id: row.id,
    number: row.number,
    code: issueCode(row.number),
    campusId: row.campus_id,
    title: row.title,
    description: row.description,
    category: row.category,
    buildingId: row.building_id,
    locationDetail: row.location_detail,
    photoPaths: row.photo_paths ?? [],
    reporterId: row.reporter_id,
    reporterDisplayName: row.reporter_display_name,
    status: row.status,
    priority: row.priority,
    assignedTo: row.assigned_to ?? null,
    assignedToName: row.assigned_to_name ?? null,
    resolutionNote: row.resolution_note ?? null,
    resolutionPhotoPaths: row.resolution_photo_paths ?? [],
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
    resolvedAt: iso(row.resolved_at),
    reopenCount: row.reopen_count,
    upvoteCount: row.upvote_count ?? 0,
    upvotedByMe: row.upvoted_by_me ?? false,
  };
}

/** Columns for `SELECT ... FROM issue_updates`; the actor's display name is read at query time. */
export const UPDATE_COLUMNS = `id, actor_id,
  (SELECT uu.display_name FROM users uu WHERE uu.id = issue_updates.actor_id) AS actor_name,
  action, old_status, new_status, old_priority, new_priority, note, created_at`;

export function toIssueUpdate(row) {
  return {
    id: row.id,
    actorId: row.actor_id,
    actorName: row.actor_name,
    action: row.action,
    oldStatus: row.old_status ?? null,
    newStatus: row.new_status ?? null,
    oldPriority: row.old_priority ?? null,
    newPriority: row.new_priority ?? null,
    note: row.note ?? null,
    createdAt: iso(row.created_at),
  };
}

export const FEEDBACK_COLUMNS = 'issue_id, reporter_id, still_exists, comment, created_at';

export function toFeedback(row) {
  return {
    issueId: row.issue_id,
    reporterId: row.reporter_id,
    stillExists: row.still_exists,
    comment: row.comment ?? null,
    createdAt: iso(row.created_at),
  };
}

/** GET /issues/stats: one aggregate row + (category, n) rows for open issues → API object. */
export function toStats(row, openByCategoryRows, categories) {
  const openByCategory = Object.fromEntries(categories.map((c) => [c, 0]));
  for (const r of openByCategoryRows) openByCategory[r.category] = r.n;
  return {
    reported: row.reported,
    inProgress: row.in_progress,
    resolved: row.resolved,
    reopened: row.reopened,
    total: row.total,
    open: row.open,
    urgent: row.urgent,
    unassigned: row.unassigned,
    assignedToMe: row.assigned_to_me ?? 0,
    createdLast24h: row.created_last_24h,
    resolvedThisWeek: row.resolved_this_week,
    // numeric comes back from pg as a string; null when there are no resolved issues.
    avgResolutionHours: row.avg_resolution_hours === null ? null : Number(row.avg_resolution_hours),
    openByCategory,
  };
}

export const STAFF_COLUMNS = 'id, display_name';

/** GET /staff item. */
export const toStaff = (row) => ({ id: row.id, displayName: row.display_name });
