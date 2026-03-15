-- 修复 checkin_and_get_multiplier：INSERT 时补齐 completed_count 等非空字段默认值
-- 同时为线上 daily_logs 补充 DEFAULT 约束，避免后续类似问题

ALTER TABLE daily_logs ALTER COLUMN completed_count SET DEFAULT 0;
ALTER TABLE daily_logs ALTER COLUMN is_perfect SET DEFAULT false;

CREATE OR REPLACE FUNCTION public.checkin_and_get_multiplier(p_date_id date)
RETURNS TABLE(streak int, multiplier double precision, is_new_checkin boolean)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_uid uuid;
    v_last date;
    v_streak int;
    v_longest int;
    v_mult double precision;
    v_is_new boolean;
    v_yesterday date;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated';
    END IF;

    v_yesterday := p_date_id - interval '1 day';

    SELECT p.last_checkin_date, p.current_streak, p.longest_streak
    INTO v_last, v_streak, v_longest
    FROM public.profiles p
    WHERE p.id = v_uid
    FOR UPDATE;

    IF v_last = p_date_id THEN
        v_is_new := false;
        v_streak := COALESCE(v_streak, 0);
    ELSE
        v_is_new := true;
        IF v_last = v_yesterday THEN
            v_streak := COALESCE(v_streak, 0) + 1;
        ELSE
            v_streak := 1;
        END IF;
        v_longest := GREATEST(COALESCE(v_longest, 0), v_streak);

        UPDATE public.profiles
        SET current_streak = v_streak,
            longest_streak = v_longest,
            last_checkin_date = p_date_id
        WHERE id = v_uid;
    END IF;

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

    -- 补齐 completed_count 和 is_perfect 的默认值
    INSERT INTO daily_logs (user_id, date_id, completed_count, is_perfect, streak_day, xp_multiplier)
    VALUES (v_uid, p_date_id, 0, false, v_streak, v_mult)
    ON CONFLICT (user_id, date_id) DO UPDATE
    SET streak_day = EXCLUDED.streak_day,
        xp_multiplier = EXCLUDED.xp_multiplier;

    RETURN QUERY SELECT v_streak, v_mult, v_is_new;
END;
$$;

GRANT EXECUTE ON FUNCTION public.checkin_and_get_multiplier(date) TO authenticated;
