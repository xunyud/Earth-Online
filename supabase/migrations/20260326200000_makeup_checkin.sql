-- 补签功能：花费金币为过去漏签的日期补签，并重算连续天数
-- 规则：50 金币/天，仅限最近 30 天内的漏签日

CREATE OR REPLACE FUNCTION public.makeup_checkin(
    p_date_id text,
    p_cost int DEFAULT 50
)
RETURNS TABLE(success boolean, new_streak int, gold_after int, message text)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_uid uuid;
    v_target date;
    v_today date;
    v_gold int;
    v_existing int;
    v_streak int;
    v_longest int;
    v_last_checkin date;
    v_row record;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN QUERY SELECT false, 0, 0, '未登录'::text;
        RETURN;
    END IF;

    v_target := p_date_id::date;
    v_today := current_date;

    -- 校验日期范围：不能是今天或未来，不能超过 30 天前
    IF v_target >= v_today THEN
        RETURN QUERY SELECT false, 0, 0, '不能补签今天或未来的日期'::text;
        RETURN;
    END IF;
    IF v_target < v_today - 30 THEN
        RETURN QUERY SELECT false, 0, 0, '只能补签最近 30 天内的日期'::text;
        RETURN;
    END IF;

    -- 检查该日是否已签到
    SELECT streak_day INTO v_existing
    FROM daily_logs
    WHERE user_id = v_uid AND date_id = v_target;

    IF v_existing IS NOT NULL AND v_existing > 0 THEN
        RETURN QUERY SELECT false, 0, 0, '该日已签到'::text;
        RETURN;
    END IF;

    -- 锁定 profiles 行，检查金币
    SELECT gold, current_streak, longest_streak
    INTO v_gold, v_streak, v_longest
    FROM profiles
    WHERE id = v_uid
    FOR UPDATE;

    IF v_gold < p_cost THEN
        RETURN QUERY SELECT false, 0, v_gold, '金币不足'::text;
        RETURN;
    END IF;

    -- 扣金币
    UPDATE profiles SET gold = gold - p_cost WHERE id = v_uid;
    v_gold := v_gold - p_cost;

    -- 插入/更新签到记录
    INSERT INTO daily_logs (user_id, date_id, streak_day, xp_multiplier)
    VALUES (v_uid, v_target, 1, 1.0)
    ON CONFLICT (user_id, date_id) DO UPDATE
    SET streak_day = 1;

    -- 重算连续天数：从今天开始倒推，找连续签到日
    v_streak := 0;
    FOR v_row IN
        SELECT date_id AS d
        FROM daily_logs
        WHERE user_id = v_uid
          AND streak_day > 0
          AND date_id <= v_today
          AND date_id > v_today - 60
        ORDER BY date_id DESC
    LOOP
        IF v_row.d = v_today - v_streak THEN
            v_streak := v_streak + 1;
        ELSE
            EXIT;
        END IF;
    END LOOP;

    v_longest := GREATEST(COALESCE(v_longest, 0), v_streak);

    -- 更新最新的签到日期为连续链中最近的那天
    IF v_streak > 0 THEN
        v_last_checkin := v_today;
    ELSE
        v_last_checkin := v_target;
    END IF;

    UPDATE profiles
    SET current_streak = v_streak,
        longest_streak = v_longest,
        last_checkin_date = v_last_checkin
    WHERE id = v_uid;

    RETURN QUERY SELECT true, v_streak, v_gold, '补签成功'::text;
END;
$$;

GRANT EXECUTE ON FUNCTION public.makeup_checkin(text, int) TO authenticated;

NOTIFY pgrst, 'reload schema';
