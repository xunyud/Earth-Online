-- ============================================================
-- PRD-01: 每日签到与连续打卡系统
-- 同时补齐 daily_logs 表定义、profiles.gold 列、increment_custom_stats RPC
-- ============================================================

-- 1. 补建 daily_logs 表（线上可能已存在，用 IF NOT EXISTS）
CREATE TABLE IF NOT EXISTS daily_logs (
    date_id text NOT NULL,
    user_id uuid NOT NULL REFERENCES auth.users(id),
    completed_count int DEFAULT 0,
    is_perfect boolean DEFAULT false,
    encouragement text,
    streak_day int DEFAULT 0,
    xp_multiplier double precision DEFAULT 1.0,
    created_at timestamptz DEFAULT now(),
    PRIMARY KEY (user_id, date_id)
);

-- 兼容旧数据：如果表已存在但缺少新列
ALTER TABLE daily_logs ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id);
ALTER TABLE daily_logs ADD COLUMN IF NOT EXISTS streak_day int DEFAULT 0;
ALTER TABLE daily_logs ADD COLUMN IF NOT EXISTS xp_multiplier double precision DEFAULT 1.0;
ALTER TABLE daily_logs ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

-- daily_logs RLS
ALTER TABLE daily_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "用户只能查看自己的日志" ON daily_logs;
CREATE POLICY "用户只能查看自己的日志"
    ON daily_logs FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "用户只能写入自己的日志" ON daily_logs;
CREATE POLICY "用户只能写入自己的日志"
    ON daily_logs FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "用户只能更新自己的日志" ON daily_logs;
CREATE POLICY "用户只能更新自己的日志"
    ON daily_logs FOR UPDATE USING (auth.uid() = user_id);

-- daily_logs 索引
CREATE INDEX IF NOT EXISTS idx_daily_logs_user_date ON daily_logs(user_id, date_id);

-- 2. profiles 补充列
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS gold int DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS current_streak int DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS longest_streak int DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_checkin_date text;  -- YYYY-MM-DD 格式

-- 3. 补齐 increment_custom_stats RPC（现有前端已在调用）
CREATE OR REPLACE FUNCTION public.increment_custom_stats(delta_xp int, delta_gold int)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'not_authenticated';
    END IF;
    UPDATE public.profiles
    SET total_xp  = GREATEST(0, total_xp  + COALESCE(delta_xp, 0)),
        gold      = GREATEST(0, gold      + COALESCE(delta_gold, 0))
    WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.increment_custom_stats(int, int) TO authenticated;

-- 4. 签到核心 RPC：checkin_and_get_multiplier
-- 原子性更新连续天数、倍率，写入 daily_logs，返回签到结果
CREATE OR REPLACE FUNCTION public.checkin_and_get_multiplier(p_date_id text)
RETURNS TABLE(streak int, multiplier double precision, is_new_checkin boolean)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_uid uuid;
    v_last text;
    v_streak int;
    v_longest int;
    v_mult double precision;
    v_is_new boolean;
    v_yesterday text;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated';
    END IF;

    -- 计算昨天的 date_id（基于传入的日期字符串）
    v_yesterday := to_char((p_date_id::date - interval '1 day')::date, 'YYYY-MM-DD');

    -- 读取当前签到状态（加行锁防并发）
    SELECT p.last_checkin_date, p.current_streak, p.longest_streak
    INTO v_last, v_streak, v_longest
    FROM public.profiles p
    WHERE p.id = v_uid
    FOR UPDATE;

    -- 如果今天已签到，直接返回现有值
    IF v_last = p_date_id THEN
        v_is_new := false;
    ELSE
        v_is_new := true;
        -- 判断连续性
        IF v_last = v_yesterday THEN
            v_streak := COALESCE(v_streak, 0) + 1;
        ELSE
            v_streak := 1;
        END IF;
        v_longest := GREATEST(COALESCE(v_longest, 0), v_streak);

        -- 写入 profiles
        UPDATE public.profiles
        SET current_streak = v_streak,
            longest_streak = v_longest,
            last_checkin_date = p_date_id
        WHERE id = v_uid;
    END IF;

    -- 计算倍率
    IF v_streak >= 30 THEN
        v_mult := 3.0;
    ELSIF v_streak >= 14 THEN
        v_mult := 2.5;
    ELSIF v_streak >= 7 THEN
        v_mult := 2.0;
    ELSIF v_streak >= 3 THEN
        v_mult := 1.5;
    ELSE
        v_mult := 1.0;
    END IF;

    -- Upsert daily_logs（写入 streak_day 和 xp_multiplier）
    INSERT INTO daily_logs (user_id, date_id, streak_day, xp_multiplier)
    VALUES (v_uid, p_date_id, v_streak, v_mult)
    ON CONFLICT (user_id, date_id) DO UPDATE
    SET streak_day = EXCLUDED.streak_day,
        xp_multiplier = EXCLUDED.xp_multiplier;

    RETURN QUERY SELECT v_streak, v_mult, v_is_new;
END;
$$;

GRANT EXECUTE ON FUNCTION public.checkin_and_get_multiplier(text) TO authenticated;
