import { describe, expect, it } from 'vitest';
import { STATUSES, STATUS_TRANSITIONS, canTransition } from '../../src/domain.js';

describe('status transition table', () => {
  const allowed = [
    ['reported', 'inProgress'],
    ['inProgress', 'resolved'],
    ['resolved', 'reopened'],
    ['reopened', 'inProgress'],
    ['reopened', 'resolved'],
  ];

  it('allows exactly the transitions in API.md', () => {
    for (const from of STATUSES) {
      for (const to of STATUSES) {
        const expected = allowed.some(([f, t]) => f === from && t === to);
        expect(canTransition(from, to), `${from} -> ${to}`).toBe(expected);
      }
    }
  });

  it('rejects unknown and prototype-ish keys', () => {
    expect(canTransition('toString', 'inProgress')).toBe(false);
    expect(canTransition('__proto__', 'resolved')).toBe(false);
    expect(canTransition(undefined, 'resolved')).toBe(false);
  });

  it('is frozen', () => {
    expect(Object.isFrozen(STATUS_TRANSITIONS)).toBe(true);
    expect(Object.isFrozen(STATUS_TRANSITIONS.reported)).toBe(true);
  });
});
