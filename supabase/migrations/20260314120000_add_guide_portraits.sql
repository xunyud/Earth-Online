-- Memory-driven portrait records for Earth Guide

CREATE TABLE IF NOT EXISTS public.guide_portraits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  style text NOT NULL DEFAULT 'pencil_sketch',
  prompt text NOT NULL,
  summary text NOT NULL DEFAULT '',
  image_url text NOT NULL,
  model text NOT NULL DEFAULT 'flux',
  seed int NOT NULL DEFAULT 0,
  memory_refs jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_guide_portraits_user_created
  ON public.guide_portraits (user_id, created_at DESC);

ALTER TABLE public.guide_portraits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "guide_portraits_select_own" ON public.guide_portraits;
CREATE POLICY "guide_portraits_select_own"
  ON public.guide_portraits FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "guide_portraits_insert_own" ON public.guide_portraits;
CREATE POLICY "guide_portraits_insert_own"
  ON public.guide_portraits FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "guide_portraits_update_own" ON public.guide_portraits;
CREATE POLICY "guide_portraits_update_own"
  ON public.guide_portraits FOR UPDATE
  USING (auth.uid() = user_id);

NOTIFY pgrst, 'reload schema';
