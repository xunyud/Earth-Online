-- =============================================
-- PRD-07: 微信周报推送系统
-- 1. profiles 新增推送偏好 + 最近交互时间
-- 2. push_logs 推送记录表
-- =============================================

-- ---------- 1. profiles 新增列 ----------

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS weekly_push_enabled boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS last_wechat_interaction timestamptz;

-- ---------- 2. push_logs 表 ----------

CREATE TABLE IF NOT EXISTS public.push_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  push_type text NOT NULL DEFAULT 'weekly_report',
  content_preview text,                    -- 推送内容前 200 字
  status text NOT NULL DEFAULT 'pending',  -- pending / sent / failed / skipped
  error_message text,
  created_at timestamptz DEFAULT now(),
  sent_at timestamptz
);

-- 索引：按用户 + 时间查询推送历史
CREATE INDEX IF NOT EXISTS idx_push_logs_user_created
  ON public.push_logs (user_id, created_at DESC);

-- ---------- 3. RLS ----------

ALTER TABLE public.push_logs ENABLE ROW LEVEL SECURITY;

-- 用户只读自己的推送记录
CREATE POLICY "push_logs_select_own"
  ON public.push_logs FOR SELECT
  USING (auth.uid() = user_id);

-- service_role 可写（Edge Function 使用 service_role_key）
CREATE POLICY "push_logs_insert_service"
  ON public.push_logs FOR INSERT
  WITH CHECK (true);

CREATE POLICY "push_logs_update_service"
  ON public.push_logs FOR UPDATE
  USING (true);

-- ---------- 4. 刷新 PostgREST schema cache ----------
NOTIFY pgrst, 'reload schema';
