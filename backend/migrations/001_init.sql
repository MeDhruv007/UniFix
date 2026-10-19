-- FixMyCampus initial schema. Applied once by src/migrate.js.
CREATE EXTENSION IF NOT EXISTS citext;

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Users ---------------------------------------------------------------------
CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         citext NOT NULL UNIQUE
                CHECK (email::text = lower(email::text) AND char_length(email::text) BETWEEN 3 AND 254),
  password_hash text NOT NULL,
  display_name  text NOT NULL CHECK (char_length(display_name) BETWEEN 2 AND 60),
  role          text NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'admin')),
  campus_id     text NOT NULL DEFAULT 'adit-main',
  department    text NULL CHECK (department IS NULL OR char_length(department) <= 60),
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER users_set_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Issues --------------------------------------------------------------------
CREATE TABLE issues (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campus_id              text NOT NULL DEFAULT 'adit-main',
  title                  text NOT NULL CHECK (char_length(title) BETWEEN 5 AND 100),
  description            text NOT NULL CHECK (char_length(description) BETWEEN 10 AND 1000),
  category               text NOT NULL CHECK (category IN
                           ('electrical', 'plumbing', 'cleanliness', 'furniture', 'it', 'safety', 'other')),
  building_id            text NOT NULL CHECK (building_id IN
                           ('engineering-block', 'science-block', 'admin-block', 'library', 'workshop',
                            'canteen', 'hostel', 'sports-complex', 'auditorium', 'grounds')),
  location_detail        text NOT NULL CHECK (char_length(location_detail) BETWEEN 2 AND 120),
  photo_paths            text[] NOT NULL DEFAULT '{}' CHECK (cardinality(photo_paths) <= 3),
  reporter_id            uuid NOT NULL REFERENCES users (id),
  reporter_display_name  text NOT NULL,
  status                 text NOT NULL DEFAULT 'reported'
                           CHECK (status IN ('reported', 'inProgress', 'resolved', 'reopened')),
  priority               text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  assigned_to            uuid NULL REFERENCES users (id),
  resolution_note        text NULL CHECK (resolution_note IS NULL OR char_length(resolution_note) BETWEEN 1 AND 500),
  resolution_photo_paths text[] NOT NULL DEFAULT '{}' CHECK (cardinality(resolution_photo_paths) <= 3),
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  resolved_at            timestamptz NULL,
  reopen_count           integer NOT NULL DEFAULT 0 CHECK (reopen_count >= 0),
  CONSTRAINT issues_resolved_at_matches_status CHECK ((status = 'resolved') = (resolved_at IS NOT NULL))
);

CREATE TRIGGER issues_set_updated_at BEFORE UPDATE ON issues
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX issues_campus_created_idx          ON issues (campus_id, created_at DESC);
CREATE INDEX issues_campus_status_created_idx   ON issues (campus_id, status, created_at DESC);
CREATE INDEX issues_campus_category_created_idx ON issues (campus_id, category, created_at DESC);
CREATE INDEX issues_reporter_created_idx        ON issues (reporter_id, created_at DESC);

-- Issue history (append-only) ----------------------------------------------
CREATE TABLE issue_updates (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq          bigint GENERATED ALWAYS AS IDENTITY,
  issue_id     uuid NOT NULL REFERENCES issues (id),
  actor_id     uuid NOT NULL REFERENCES users (id),
  action       text NOT NULL CHECK (action IN
                 ('created', 'statusChanged', 'priorityChanged', 'assigned', 'commented', 'reopened')),
  old_status   text NULL CHECK (old_status IN ('reported', 'inProgress', 'resolved', 'reopened')),
  new_status   text NULL CHECK (new_status IN ('reported', 'inProgress', 'resolved', 'reopened')),
  old_priority text NULL CHECK (old_priority IN ('low', 'medium', 'high', 'urgent')),
  new_priority text NULL CHECK (new_priority IN ('low', 'medium', 'high', 'urgent')),
  note         text NULL CHECK (note IS NULL OR char_length(note) <= 500),
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX issue_updates_issue_created_idx ON issue_updates (issue_id, created_at, seq);

CREATE OR REPLACE FUNCTION reject_issue_update_mutation() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'issue_updates is append-only';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER issue_updates_append_only BEFORE UPDATE OR DELETE ON issue_updates
  FOR EACH ROW EXECUTE FUNCTION reject_issue_update_mutation();

-- Reporter feedback (one per reporter per issue) ---------------------------
CREATE TABLE issue_feedback (
  issue_id     uuid NOT NULL REFERENCES issues (id),
  reporter_id  uuid NOT NULL REFERENCES users (id),
  still_exists boolean NOT NULL,
  comment      text NULL CHECK (comment IS NULL OR char_length(comment) <= 500),
  created_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (issue_id, reporter_id)
);

-- Password reset tokens (only the SHA-256 hash is stored) -------------------
CREATE TABLE password_reset_tokens (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  used_at    timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX password_reset_tokens_user_idx ON password_reset_tokens (user_id);
