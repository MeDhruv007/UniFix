import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { detectImageType, newPhotoPath, resolvePhotoPath } from '../../src/photos/storage.js';
import { JPEG, NOT_AN_IMAGE, PNG, WEBP } from '../helpers.js';

const ID = '3f2a1b4c-5d6e-4f70-8a9b-0c1d2e3f4a5b';
const FILE = '9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d';

describe('detectImageType (magic bytes)', () => {
  it('recognises jpeg, png and webp', () => {
    expect(detectImageType(JPEG)).toBe('jpg');
    expect(detectImageType(PNG)).toBe('png');
    expect(detectImageType(WEBP)).toBe('webp');
  });

  it('rejects everything else regardless of name', () => {
    expect(detectImageType(NOT_AN_IMAGE)).toBeNull();
    expect(detectImageType(Buffer.from('GIF89a......'))).toBeNull();
    expect(detectImageType(Buffer.from('RIFF\0\0\0\0WAVE'))).toBeNull();
    expect(detectImageType(Buffer.alloc(0))).toBeNull();
  });
});

describe('photo paths', () => {
  const root = path.resolve('/srv/uploads');

  it('generates server-side UUID file names', () => {
    const p = newPhotoPath(ID, 'report', 'png');
    expect(p).toMatch(new RegExp(`^issues/${ID}/report/[0-9a-f-]{36}\\.png$`));
    expect(resolvePhotoPath(root, p)).toBe(path.join(root, p));
  });

  it('accepts only well-formed paths inside the root', () => {
    expect(resolvePhotoPath(root, `issues/${ID}/resolution/${FILE}.webp`)).not.toBeNull();
    for (const bad of [
      '../etc/passwd',
      `issues/${ID}/report/../../../../etc/passwd`,
      `issues/${ID}/report/${FILE}.jpg/..`,
      `/issues/${ID}/report/${FILE}.jpg`,
      `issues/${ID}/report/${FILE}.svg`,
      `issues/${ID}/other/${FILE}.jpg`,
      `issues/${ID}\\report\\${FILE}.jpg`,
      `.tmp/${FILE}`,
      '',
      undefined,
    ]) {
      expect(resolvePhotoPath(root, bad), String(bad)).toBeNull();
    }
  });
});
