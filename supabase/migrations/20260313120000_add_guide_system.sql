-- Guide system for "Earth Mentor" experience
-- 1) user settings
-- 2) daily event generation/acceptance
-- 3) dialog logs

CREATE TABLE IF NOT EXISTS public.guide_user_settings (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  guide_enabled boolean NOT NULL DEFAULT true,
  proactive_mode text NOT NULL DEFAULT 'daily_first_open',
  memory_mode text NOT NULL DEFAULT 'hybrid_deep',
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (proactive_mode IN ('daily_first_open')),
  CHECK (memory_mode IN ('hybrid_deep', 'recent_only', 'full'))
);

CREATE TABLE IF NOT EXISTS public.guide_daily_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_date date NOT NULL,
  title text NOT NULL,
  description text NOT NULL,
  reward_xp int NOT NULL DEFAULT 0,
  reward_gold int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'generated',
  memory_refs jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  handled_at timestamptz,
  CHECK (status IN ('generated', 'accepted', 'dismissed', 'expired')),
  UNIQUE (user_id, event_date)
);

CREATE TABLE IF NOT EXISTS public.guide_dialog_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  scene text NOT NULL,
  role text NOT NULL,
  content text NOT NULL,
  memory_refs jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (role IN ('user', 'assistant', 'system'))
);

CREATE INDEX IF NOT EXISTS idx_guide_daily_events_user_date
  ON public.guide_daily_events (user_id, event_date DESC);
CREATE INDEX IF NOT EXISTS idx_guide_dialog_logs_user_created
  ON public.guide_dialog_logs (user_id, created_at DESC);

ALTER TABLE public.guide_user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guide_daily_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guide_dialog_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "guide_settings_select_own" ON public.guide_user_settings;
CREATE POLICY "guide_settings_select_own"
  ON public.guide_user_settings FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "guide_settings_insert_own" ON public.guide_user_settings;
CREATE POLICY "guide_settings_insert_own"
  ON public.guide_user_settings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "guide_settings_update_own" ON public.guide_user_settings;
CREATE POLICY "guide_settings_update_own"
  ON public.guide_user_settings FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "guide_events_select_own" ON public.guide_daily_events;
CREATE POLICY "guide_events_select_own"
  ON public.guide_daily_events FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "guide_events_insert_own" ON public.guide_daily_events;
CREATE POLICY "guide_events_insert_own"
  ON public.guide_daily_events FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "guide_events_update_own" ON public.guide_daily_events;
CREATE POLICY "guide_events_update_own"
  ON public.guide_daily_events FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "guide_dialog_select_own" ON public.guide_dialog_logs;
CREATE POLICY "guide_dialog_select_own"
  ON public.guide_dialog_logs FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "guide_dialog_insert_own" ON public.guide_dialog_logs;
CREATE POLICY "guide_dialog_insert_own"
  ON public.guide_dialog_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

NOTIFY pgrst, 'reload schema';
