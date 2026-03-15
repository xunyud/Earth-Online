CREATE OR REPLACE FUNCTION public.checkin_and_get_multiplier(p_date_id text)
RETURNS TABLE(streak int, multiplier double precision, is_new_checkin boolean, used_protect boolean)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_uid uuid;
    v_today date;
    v_last date;
    v_streak int;
    v_longest int;
    v_mult double precision;
    v_is_new boolean;
    v_used_protect boolean := false;
    v_yesterday date;
    v_protect_id uuid;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated';
    END IF;

    v_today := p_date_id::date;
    v_yesterday := v_today - interval '1 day';

    SELECT p.last_checkin_date, p.current_streak, p.longest_streak
    INTO v_last, v_streak, v_longest
    FROM public.profiles p
    WHERE p.id = v_uid
    FOR UPDATE;

    IF v_last = v_today THEN
        v_is_new := false;
    ELSE
        v_is_new := true;
        IF v_last = v_yesterday THEN
            v_streak := COALESCE(v_streak, 0) + 1;
        ELSE
            SELECT id INTO v_protect_id
            FROM inventory
            WHERE user_id = v_uid
              AND effect_type = 'streak_protect'
              AND is_used = false
            LIMIT 1
            FOR UPDATE;

            IF v_protect_id IS NOT NULL THEN
                UPDATE inventory
                SET is_used = true, used_at = now()
                WHERE id = v_protect_id;
                v_streak := COALESCE(v_streak, 0) + 1;
                v_used_protect := true;
            ELSE
                v_streak := 1;
            END IF;
        END IF;

        v_longest := GREATEST(COALESCE(v_longest, 0), v_streak);

        UPDATE public.profiles
        SET current_streak = v_streak,
            longest_streak = v_longest,
            last_checkin_date = v_today
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

    INSERT INTO daily_logs (user_id, date_id, streak_day, xp_multiplier)
    VALUES (v_uid, p_date_id, v_streak, v_mult)
    ON CONFLICT (user_id, date_id) DO UPDATE
    SET streak_day = EXCLUDED.streak_day,
        xp_multiplier = EXCLUDED.xp_multiplier;

    RETURN QUERY SELECT v_streak, v_mult, v_is_new, v_used_protect;
END;
$$;

GRANT EXECUTE ON FUNCTION public.checkin_and_get_multiplier(text) TO authenticated;

NOTIFY pgrst, 'reload schema';
