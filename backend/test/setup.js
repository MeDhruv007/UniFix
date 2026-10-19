import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

// Test defaults; real env vars win.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET ??= 'test-secret-test-secret-test-secret-0123456789';
process.env.BCRYPT_ROUNDS ??= '4';
process.env.AUTH_RATE_LIMIT ??= '0';
process.env.LOG_LEVEL ??= 'silent';
process.env.UPLOADS_DIR ??= fs.mkdtempSync(path.join(os.tmpdir(), 'fmc-uploads-'));

