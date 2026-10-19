-- Preset profile avatars (the app maps each id to an icon + colour).
-- Keep the list in sync with AVATARS in src/domain.js and the Flutter app.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS avatar text NULL
  CONSTRAINT users_avatar_check CHECK (
    avatar IS NULL OR avatar IN ('spark', 'leaf', 'wave', 'sun', 'star', 'bolt', 'heart', 'book')
  );
