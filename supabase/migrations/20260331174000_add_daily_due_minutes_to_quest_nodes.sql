ALTER TABLE public.quest_nodes
ADD COLUMN IF NOT EXISTS daily_due_minutes int;
