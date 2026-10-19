-- "Me too" upvotes: one per user per issue (the reporter never upvotes their own issue).
CREATE TABLE IF NOT EXISTS issue_upvotes (
  issue_id   uuid        NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
  user_id    uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (issue_id, user_id)
);
CREATE INDEX IF NOT EXISTS issue_upvotes_issue_id_idx ON issue_upvotes (issue_id);
