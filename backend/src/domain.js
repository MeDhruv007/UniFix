/** Enum values and limits from docs/API.md. Single source of truth for the server. */
export const CAMPUS_ID = 'adit-main';

export const STATUSES = ['reported', 'inProgress', 'resolved', 'reopened'];
export const PRIORITIES = ['low', 'medium', 'high', 'urgent'];
export const CATEGORIES = ['electrical', 'plumbing', 'cleanliness', 'furniture', 'it', 'safety', 'other'];
export const UPDATE_ACTIONS = ['created', 'statusChanged', 'priorityChanged', 'assigned', 'commented', 'reopened'];
export const ROLES = ['student', 'admin'];
/** Preset profile avatars; keep in sync with migrations/003_avatar.sql and the app. */
export const AVATARS = ['spark', 'leaf', 'wave', 'sun', 'star', 'bolt', 'heart', 'book'];
export const BUILDING_IDS = [
  'engineering-block',
  'science-block',
  'admin-block',
  'library',
  'workshop',
  'canteen',
  'hostel',
  'sports-complex',
  'auditorium',
  'grounds',
];

export const LIMITS = {
  title: [5, 100],
  description: [10, 1000],
  locationDetail: [2, 120],
  note: 500,
  displayName: [2, 60],
  department: 60,
  passwordMin: 8,
  passwordMaxBytes: 72, // bcrypt only uses the first 72 bytes
  photosPerIssue: 3,
  resolutionPhotos: 3,
  photoBytes: 5 * 1024 * 1024,
  pageMax: 50,
  pageDefault: 20,
  searchMax: 100,
};

/** Allowed status transitions (API.md "Allowed status transitions"). */
export const STATUS_TRANSITIONS = Object.freeze({
  reported: Object.freeze(['inProgress']),
  inProgress: Object.freeze(['resolved']),
  resolved: Object.freeze(['reopened']),
  reopened: Object.freeze(['inProgress', 'resolved']),
});

export function canTransition(from, to) {
  return Object.hasOwn(STATUS_TRANSITIONS, from) && STATUS_TRANSITIONS[from].includes(to);
}

export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const isUuid = (v) => typeof v === 'string' && UUID_RE.test(v);
