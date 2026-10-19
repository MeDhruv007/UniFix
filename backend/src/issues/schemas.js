import { z } from 'zod';
import { BUILDING_IDS, CATEGORIES, LIMITS, PRIORITIES, STATUSES, UUID_RE } from '../domain.js';
import {
  body,
  optionalQueryEnum,
  optionalText,
  queryInt,
  requiredEnum,
  requiredText,
} from '../middleware/validate.js';

export const createIssueSchema = body({
  title: requiredText('Title', LIMITS.title),
  description: requiredText('Description', LIMITS.description),
  category: requiredEnum('Category', CATEGORIES),
  buildingId: requiredEnum('Building', BUILDING_IDS),
  locationDetail: requiredText('Location detail', LIMITS.locationDetail),
});

/** Optional `true`/`false` query flag; empty or absent → undefined. */
const optionalQueryBool = (label) =>
  z.preprocess(
    (v) => (v === '' ? undefined : v),
    z
      .enum(['true', 'false'], { error: `${label} must be true or false.` })
      .optional()
      .transform((v) => (v === undefined ? undefined : v === 'true')),
  );

/** `mine`-style flag where only `true` has an effect: absent/empty/false → false. */
const queryFlag = (label) => optionalQueryBool(label).transform((v) => v === true);

export const listIssuesQuery = z.object({
  status: optionalQueryEnum('status', STATUSES),
  category: optionalQueryEnum('category', CATEGORIES),
  mine: queryFlag('mine'),
  // v1.1
  q: z.preprocess(
    (v) => {
      if (typeof v !== 'string') return v;
      const t = v.trim();
      return t === '' ? undefined : t;
    },
    z
      .string({ error: 'q must be text.' })
      .max(LIMITS.searchMax, `q must be at most ${LIMITS.searchMax} characters.`)
      .optional(),
  ),
  open: queryFlag('open'),
  priority: optionalQueryEnum('priority', PRIORITIES),
  assigned: optionalQueryBool('assigned'),
  // v1.4: only issues assigned to the caller.
  assignedToMe: queryFlag('assignedToMe'),
  sort: z.preprocess(
    (v) => (v === '' || v === undefined ? 'newest' : v),
    z.enum(['newest', 'oldest', 'popular'], { error: 'sort must be one of: newest, oldest, popular.' }),
  ),
  limit: queryInt('limit', { min: 1, max: LIMITS.pageMax, fallback: LIMITS.pageDefault }),
  offset: queryInt('offset', { min: 0, max: 1_000_000, fallback: 0 }),
});

export const statusChangeSchema = body({
  from: requiredEnum('from', STATUSES),
  to: requiredEnum('to', STATUSES),
  note: optionalText('Note', LIMITS.note),
});

export const priorityChangeSchema = body({
  from: requiredEnum('from', PRIORITIES),
  to: requiredEnum('to', PRIORITIES),
});

export const statsQuery = z.object({ mine: queryFlag('mine') });

const ASSIGNEE_MSG = 'assigneeId must be a user id or null.';

/** POST /issues/:id/assign — body optional; absent assigneeId = caller, null = unassign. */
export const assignSchema = body({
  assigneeId: z
    .union([z.null(), z.string().trim().regex(UUID_RE, ASSIGNEE_MSG)], { error: ASSIGNEE_MSG })
    .optional(),
});

export const feedbackSchema = body({
  stillExists: z.boolean({ error: 'stillExists must be true or false.' }),
  comment: optionalText('Comment', LIMITS.note),
});
