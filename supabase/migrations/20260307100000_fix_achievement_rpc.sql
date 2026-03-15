-- 修复 check_and_unlock_achievements RPC 两个 bug：
-- 1. RETURNS TABLE 列名 achievement_id 与 user_achievements.achievement_id 冲突 → 重命名为 out_*
-- 2. quest_nodes.user_id 是 text，需 p_user_id::text 显式转换

-- 返回类型变更，必须先 DROP 再 CREATE
DROP FUNCTION IF EXISTS public.check_and_unlock_achievements(uuid, text);

CREATE FUNCTION public.check_and_unlock_achievements(
    p_user_id uuid,
    p_category text
)
RETURNS TABLE(out_achievement_id text, out_title text, out_icon text, out_xp_bonus int, out_gold_bonus int)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
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
        WHERE user_id = p_user_id::text
          AND is_completed = true
          AND is_deleted = false;
    END IF;

    IF p_category = 'streak' THEN
        SELECT COALESCE(p.current_streak, 0)
        INTO v_streak
        FROM profiles p WHERE p.id = p_user_id;
    END IF;

    IF p_category = 'xp' THEN
        SELECT COALESCE(p.total_xp, 0)
        INTO v_total_xp
        FROM profiles p WHERE p.id = p_user_id;

        -- 计算等级（复制 LevelEngine 逻辑：baseXp=500, growth=1.2）
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
              WHERE ua.user_id = p_user_id
                AND ua.achievement_id = a.id
          )
        ORDER BY a.sort_order
    LOOP
        -- 判断是否满足条件
        IF (rec.condition_type = 'total_completed' AND v_total_completed >= rec.condition_value)
           OR (rec.condition_type = 'streak'          AND v_streak          >= rec.condition_value)
           OR (rec.condition_type = 'total_xp'        AND v_total_xp        >= rec.condition_value)
           OR (rec.condition_type = 'level'            AND v_level           >= rec.condition_value)
           OR (rec.condition_type = 'board_clear')
           OR (rec.condition_type = 'first_wechat')
        THEN
            -- 解锁（幂等）
            INSERT INTO user_achievements (user_id, achievement_id)
            VALUES (p_user_id, rec.id)
            ON CONFLICT (user_id, achievement_id) DO NOTHING;

            -- 发放奖励
            IF COALESCE(rec.xp_bonus, 0) > 0 OR COALESCE(rec.gold_bonus, 0) > 0 THEN
                UPDATE profiles
                SET total_xp = GREATEST(0, total_xp + COALESCE(rec.xp_bonus, 0)),
                    gold     = GREATEST(0, gold + COALESCE(rec.gold_bonus, 0))
                WHERE id = p_user_id;
            END IF;

            -- 输出新解锁记录（使用 out_ 前缀避免歧义）
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
