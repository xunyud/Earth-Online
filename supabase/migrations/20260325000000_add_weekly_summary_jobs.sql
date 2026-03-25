CREATE TABLE IF NOT EXISTS weekly_summary_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'queued',
  summary text,
  summary_date_id text,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  started_at timestamptz,
  finished_at timestamptz,
  notified_at timestamptz
);

CREATE INDEX IF NOT EXISTS weekly_summary_jobs_user_created_idx
  ON weekly_summary_jobs(user_id, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS weekly_summary_jobs_active_user_idx
  ON weekly_summary_jobs(user_id)
  WHERE status IN ('queued', 'running');
