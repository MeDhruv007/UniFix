import { describe, expect, it } from 'vitest';
import { escapeLike, searchNumber } from '../../src/issues/routes.js';
import { assignSchema, listIssuesQuery, statsQuery } from '../../src/issues/schemas.js';
import { issueCode, toStats } from '../../src/issues/serialize.js';
import { CATEGORIES } from '../../src/domain.js';
import { parse } from '../../src/middleware/validate.js';

describe('issueCode', () => {
  it('zero-pads to 4 digits and prints longer numbers in full', () => {
    expect(issueCode(1)).toBe('FMC-0001');
    expect(issueCode(483)).toBe('FMC-0483');
    expect(issueCode(9999)).toBe('FMC-9999');
    expect(issueCode(10000)).toBe('FMC-10000');
    expect(issueCode(123456)).toBe('FMC-123456');
  });
});

describe('search helpers', () => {
  it('escapes LIKE metacharacters', () => {
    expect(escapeLike('50%')).toBe('50\\%');
    expect(escapeLike('a_b')).toBe('a\\_b');
    expect(escapeLike('back\\slash')).toBe('back\\\\slash');
    expect(escapeLike("it's")).toBe("it's");
  });

  it('extracts an issue number from code-like terms', () => {
    for (const q of ['FMC-0483', 'fmc-0483', 'Fmc-483', '0483', '483', '000483']) expect(searchNumber(q)).toBe(483);
    for (const q of ['FMC-', '0', '000', 'FMC-48x', 'fan', '4 83', '-483', 'FMC-FMC-1', '1234567890']) {
      expect(searchNumber(q), q).toBeNull();
    }
    expect(searchNumber('FMC-10000')).toBe(10000);
  });
});

describe('listIssuesQuery v1.1 params', () => {
  it('parses q, open, priority, assigned, sort', () => {
    expect(
      parse(listIssuesQuery, { q: '  fan ', open: 'true', priority: 'urgent', assigned: 'false', sort: 'oldest' }),
    ).toMatchObject({ q: 'fan', open: true, priority: 'urgent', assigned: false, sort: 'oldest' });
    expect(parse(listIssuesQuery, { assigned: 'true', open: 'false', q: '   ' })).toMatchObject({
      assigned: true,
      open: false,
      q: undefined,
      sort: 'newest',
    });
  });

  it.each([
    [{ q: 'x'.repeat(101) }, /^q must be at most 100/],
    [{ q: ['a', 'b'] }, /^q must be text/],
    [{ open: 'yes' }, /^open must be true or false/],
    [{ priority: 'critical' }, /^priority must be one of/],
    [{ assigned: '1' }, /^assigned must be true or false/],
    [{ sort: 'random' }, /^sort must be one of: newest, oldest/],
  ])('rejects %o', (input, msg) => {
    try {
      parse(listIssuesQuery, input);
      throw new Error('expected failure');
    } catch (err) {
      expect(err.status).toBe(400);
      expect(err.message).toMatch(msg);
    }
  });
});

describe('statsQuery / assignSchema', () => {
  it('parses mine', () => {
    expect(parse(statsQuery, {})).toEqual({ mine: false });
    expect(parse(statsQuery, { mine: 'true' })).toEqual({ mine: true });
    expect(() => parse(statsQuery, { mine: 'x' })).toThrow(/mine must be true or false/);
  });

  it('accepts an absent, null or uuid assigneeId only', () => {
    expect(parse(assignSchema, {})).toEqual({});
    expect(parse(assignSchema, { assigneeId: null })).toEqual({ assigneeId: null });
    const id = '3f2a1b4c-5d6e-4f70-8a9b-0c1d2e3f4a5b';
    expect(parse(assignSchema, { assigneeId: ` ${id} ` })).toEqual({ assigneeId: id });
    for (const bad of ['nope', '', 7, true, {}]) {
      expect(() => parse(assignSchema, { assigneeId: bad })).toThrow(/assigneeId must be a user id or null/);
    }
  });
});

describe('toStats', () => {
  it('fills all categories and converts avgResolutionHours', () => {
    const row = {
      reported: 1, in_progress: 0, resolved: 1, reopened: 0, total: 2, open: 1, urgent: 0, unassigned: 1,
      created_last_24h: 2, resolved_this_week: 1, avg_resolution_hours: '57.6',
    };
    const out = toStats(row, [{ category: 'it', n: 1 }], CATEGORIES);
    expect(out.avgResolutionHours).toBe(57.6);
    expect(Object.keys(out.openByCategory)).toEqual(CATEGORIES);
    expect(out.openByCategory.it).toBe(1);
    expect(toStats({ ...row, avg_resolution_hours: null }, [], CATEGORIES).avgResolutionHours).toBeNull();
  });
});
