ALTER TABLE public.guide_user_settings
ADD COLUMN IF NOT EXISTS display_name text;
