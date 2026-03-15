-- 修复 check_and_unlock_achievements uuid = text 类型错误
-- 使用本地变量显式转换类型，避免 PL/pgSQL 在 SQL 上下文中的隐式类型解析问题

DROP FUNCTION IF EXISTS public.check_and_unlock_achievements(uuid, text);

CREATE FUNCTION public.check_and_unlock_achievements(
    p_user_id uuid,
    p_category text
)
RETURNS TABLE(out_achievement_id text, out_title text, out_icon text, out_xp_bonus int, out_gold_bonus int)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id_text text := p_user_id::text;   -- quest_nodes.user_id 是 text
    v_user_id_uuid uuid := p_user_id;         -- user_achievements/profiles 是 uuid
    v_total_completed int;
    v_streak int;
    v_total_xp int;
    v_level int;
    v_xp_cap int;
    v_xp_remainder int;
    rec RECORD;
BEGIN
    -- 按类别预加载用户当前值
    IF p_category IN ('quest', 'special') THEN
        SELECT COUNT(*)::int INTO v_total_completed
        FROM quest_nodes
        WHERE user_id = v_user_id_text
          AND is_completed = true
          AND is_deleted = false;
    END IF;

    IF p_category = 'streak' THEN
        SELECT COALESCE(current_streak, 0)
        INTO v_streak
        FROM profiles WHERE id = v_user_id_uuid;
    END IF;

    IF p_category = 'xp' THEN
        SELECT COALESCE(total_xp, 0)
        INTO v_total_xp
        FROM profiles WHERE id = v_user_id_uuid;

        -- 计算等级（LevelEngine 逻辑：baseXp=500, growth=1.2）
        v_level := 1;
        v_xp_remainder := v_total_xp;
        v_xp_cap := 500;
        WHILE v_xp_remainder >= v_xp_cap LOOP
            v_xp_remainder := v_xp_remainder - v_xp_cap;
            v_level := v_level + 1;
            v_xp_cap := CEIL(v_xp_cap * 1.2);
        END LOOP;
    END IF;

    -- 遍历该类别下用户尚未解锁的成就
    FOR rec IN
        SELECT a.*
        FROM achievements a
        WHERE a.category = p_category
          AND NOT EXISTS (
              SELECT 1 FROM user_achievements ua
              WHERE ua.user_id = v_user_id_uuid
                AND ua.achievement_id = a.id
          )
        ORDER BY a.sort_order
    LOOP
        IF (rec.condition_type = 'total_completed' AND v_total_completed >= rec.condition_value)
           OR (rec.condition_type = 'streak'          AND v_streak          >= rec.condition_value)
           OR (rec.condition_type = 'total_xp'        AND v_total_xp        >= rec.condition_value)
           OR (rec.condition_type = 'level'            AND v_level           >= rec.condition_value)
           OR (rec.condition_type = 'board_clear')
           OR (rec.condition_type = 'first_wechat')
        THEN
            INSERT INTO user_achievements (user_id, achievement_id)
            VALUES (v_user_id_uuid, rec.id)
            ON CONFLICT (user_id, achievement_id) DO NOTHING;

            IF COALESCE(rec.xp_bonus, 0) > 0 OR COALESCE(rec.gold_bonus, 0) > 0 THEN
                UPDATE profiles
                SET total_xp = GREATEST(0, total_xp + COALESCE(rec.xp_bonus, 0)),
                    gold     = GREATEST(0, gold + COALESCE(rec.gold_bonus, 0))
                WHERE id = v_user_id_uuid;
            END IF;

            out_achievement_id := rec.id;
            out_title          := rec.title;
            out_icon           := rec.icon;
            out_xp_bonus       := rec.xp_bonus;
            out_gold_bonus     := rec.gold_bonus;
            RETURN NEXT;
        END IF;
    END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_and_unlock_achievements(uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
