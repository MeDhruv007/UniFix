import { describe, expect, it } from 'vitest';
import { AppError } from '../../src/errors.js';
import {
  createIssueSchema,
  feedbackSchema,
  listIssuesQuery,
  priorityChangeSchema,
  statusChangeSchema,
} from '../../src/issues/schemas.js';
import { parse } from '../../src/middleware/validate.js';

const ok = {
  title: '  Fan not working  ',
  description: 'The ceiling fan does not start.',
  category: 'electrical',
  buildingId: 'engineering-block',
  locationDetail: 'Room 204',
};

const message = (fn) => {
  try {
    fn();
  } catch (err) {
    expect(err).toBeInstanceOf(AppError);
    expect(err.status).toBe(400);
    expect(err.code).toBe('VALIDATION');
    return err.message;
  }
  throw new Error('expected a validation error');
};

describe('createIssueSchema', () => {
  it('trims strings and strips unknown keys', () => {
    const out = parse(createIssueSchema, { ...ok, status: 'resolved', reporterId: 'x', campusId: 'evil' });
    expect(out.title).toBe('Fan not working');
    expect(out).not.toHaveProperty('status');
    expect(out).not.toHaveProperty('reporterId');
    expect(out).not.toHaveProperty('campusId');
  });

  it('applies length limits after trimming', () => {
    expect(message(() => parse(createIssueSchema, { ...ok, title: '   abc    ' }))).toBe(
      'Title must be at least 5 characters.',
    );
    expect(message(() => parse(createIssueSchema, { ...ok, title: 'x'.repeat(101) }))).toBe(
      'Title must be at most 100 characters.',
    );
    expect(message(() => parse(createIssueSchema, { ...ok, description: 'short' }))).toMatch(/Description/);
    expect(message(() => parse(createIssueSchema, { ...ok, locationDetail: 'x' }))).toMatch(/Location detail/);
    expect(parse(createIssueSchema, { ...ok, title: 'x'.repeat(100) }).title).toHaveLength(100);
  });

  it('requires fields and validates enums', () => {
    const { title: _omit, ...noTitle } = ok;
    expect(message(() => parse(createIssueSchema, noTitle))).toBe('Title is required.');
    expect(message(() => parse(createIssueSchema, { ...ok, category: 'magic' }))).toMatch(/Category must be one of/);
    expect(message(() => parse(createIssueSchema, { ...ok, buildingId: 'moon-base' }))).toMatch(/Building/);
  });
});

describe('statusChangeSchema / priorityChangeSchema', () => {
  it('turns blank notes into null and caps length', () => {
    expect(parse(statusChangeSchema, { from: 'reported', to: 'inProgress', note: '   ' }).note).toBeNull();
    expect(message(() => parse(statusChangeSchema, { from: 'reported', to: 'inProgress', note: 'x'.repeat(501) })))
      .toBe('Note must be at most 500 characters.');
  });

  it('rejects unknown enum values', () => {
    expect(message(() => parse(statusChangeSchema, { from: 'reported', to: 'done' }))).toMatch(/^to must be one of/);
    expect(message(() => parse(priorityChangeSchema, { from: 'medium', to: 'critical' }))).toMatch(/^to must be/);
  });
});

describe('listIssuesQuery', () => {
  it('applies defaults and treats empty filters as absent', () => {
    expect(parse(listIssuesQuery, { status: '', category: '' })).toEqual({
      status: undefined,
      category: undefined,
      mine: false,
      limit: 20,
      offset: 0,
      q: undefined,
      open: false,
      priority: undefined,
      assigned: undefined,
      assignedToMe: false,
      sort: 'newest',
    });
  });

  it('parses values and enforces 1..50', () => {
    expect(parse(listIssuesQuery, { mine: 'true', limit: '50', offset: '10', status: 'resolved' })).toMatchObject({
      mine: true,
      limit: 50,
      offset: 10,
      status: 'resolved',
    });
    expect(message(() => parse(listIssuesQuery, { limit: '0' }))).toMatch(/limit/);
    expect(message(() => parse(listIssuesQuery, { limit: '51' }))).toMatch(/limit/);
    expect(message(() => parse(listIssuesQuery, { limit: '-1' }))).toMatch(/limit/);
    expect(message(() => parse(listIssuesQuery, { mine: 'yes' }))).toMatch(/mine/);
    expect(message(() => parse(listIssuesQuery, { status: 'closed' }))).toMatch(/status/);
  });
});

describe('feedbackSchema', () => {
  it('requires a boolean stillExists', () => {
    expect(message(() => parse(feedbackSchema, { stillExists: 'no' }))).toMatch(/stillExists/);
    expect(parse(feedbackSchema, { stillExists: false, comment: '  ' })).toEqual({ stillExists: false, comment: null });
  });
});
