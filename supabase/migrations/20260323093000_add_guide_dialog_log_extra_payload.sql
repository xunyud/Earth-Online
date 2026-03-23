ALTER TABLE public.guide_dialog_logs
ADD COLUMN IF NOT EXISTS extra_payload jsonb;
