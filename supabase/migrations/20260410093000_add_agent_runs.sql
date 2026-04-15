CREATE TABLE IF NOT EXISTS public.agent_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  goal text NOT NULL,
  channel text NOT NULL DEFAULT 'desktop',
  status text NOT NULL DEFAULT 'queued',
  summary text,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  started_at timestamptz,
  finished_at timestamptz,
  CHECK (status IN (
    'queued',
    'running',
    'waiting_approval',
    'waiting_local_execution',
    'succeeded',
    'failed',
    'cancelled'
  ))
);

CREATE TABLE IF NOT EXISTS public.agent_run_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id uuid NOT NULL REFERENCES public.agent_runs(id) ON DELETE CASCADE,
  step_index integer NOT NULL,
  kind text NOT NULL,
  tool_name text,
  arguments_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  risk_level text NOT NULL DEFAULT 'low',
  needs_confirmation boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'planned',
  summary text NOT NULL DEFAULT '',
  output_text text,
  result_json jsonb,
  error_text text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  started_at timestamptz,
  finished_at timestamptz,
  CHECK (kind IN (
    'message',
    'tool_call',
    'approval_request',
    'result',
    'error',
    'done'
  )),
  CHECK (risk_level IN ('low', 'medium', 'high')),
  CHECK (status IN (
    'planned',
    'waiting_approval',
    'ready',
    'running',
    'succeeded',
    'failed',
    'cancelled'
  )),
  UNIQUE (run_id, step_index)
);

CREATE TABLE IF NOT EXISTS public.agent_step_approvals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  step_id uuid NOT NULL REFERENCES public.agent_run_steps(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  decision text NOT NULL,
  reason text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CHECK (decision IN ('approved', 'rejected'))
);

CREATE INDEX IF NOT EXISTS idx_agent_runs_user_created
  ON public.agent_runs (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_agent_runs_user_status
  ON public.agent_runs (user_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_agent_run_steps_run_index
  ON public.agent_run_steps (run_id, step_index ASC);

CREATE INDEX IF NOT EXISTS idx_agent_run_steps_run_status
  ON public.agent_run_steps (run_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_agent_step_approvals_step_created
  ON public.agent_step_approvals (step_id, created_at DESC);

ALTER TABLE public.agent_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agent_run_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agent_step_approvals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "agent_runs_select_own" ON public.agent_runs;
CREATE POLICY "agent_runs_select_own"
  ON public.agent_runs FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "agent_runs_insert_own" ON public.agent_runs;
CREATE POLICY "agent_runs_insert_own"
  ON public.agent_runs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "agent_runs_update_own" ON public.agent_runs;
CREATE POLICY "agent_runs_update_own"
  ON public.agent_runs FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "agent_run_steps_select_own" ON public.agent_run_steps;
CREATE POLICY "agent_run_steps_select_own"
  ON public.agent_run_steps FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.agent_runs runs
      WHERE runs.id = run_id
        AND runs.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "agent_run_steps_insert_own" ON public.agent_run_steps;
CREATE POLICY "agent_run_steps_insert_own"
  ON public.agent_run_steps FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.agent_runs runs
      WHERE runs.id = run_id
        AND runs.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "agent_run_steps_update_own" ON public.agent_run_steps;
CREATE POLICY "agent_run_steps_update_own"
  ON public.agent_run_steps FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM public.agent_runs runs
      WHERE runs.id = run_id
        AND runs.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "agent_step_approvals_select_own" ON public.agent_step_approvals;
CREATE POLICY "agent_step_approvals_select_own"
  ON public.agent_step_approvals FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "agent_step_approvals_insert_own" ON public.agent_step_approvals;
CREATE POLICY "agent_step_approvals_insert_own"
  ON public.agent_step_approvals FOR INSERT
  WITH CHECK (auth.uid() = user_id);

NOTIFY pgrst, 'reload schema';
