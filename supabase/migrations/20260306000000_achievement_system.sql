-- PRD-04：成就徽章系统
-- 建表 + 种子数据 + RPC + RLS

-- ============================================================
-- 1. achievements 表（成就定义，静态）
-- ============================================================
CREATE TABLE IF NOT EXISTS achievements (
    id text PRIMARY KEY,
    title text NOT NULL,
    description text NOT NULL,
    icon text NOT NULL,
    category text NOT NULL CHECK (category IN ('quest', 'streak', 'xp', 'special')),
    condition_type text NOT NULL CHECK (condition_type IN (
        'total_completed', 'streak', 'total_xp', 'level', 'board_clear', 'first_wechat'
    )),
    condition_value int NOT NULL,
    xp_bonus int DEFAULT 0,
    gold_bonus int DEFAULT 0,
    sort_order int DEFAULT 0
);

ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "所有已认证用户可读取成就定义"
    ON achievements FOR SELECT
    USING (auth.uid() IS NOT NULL);

-- ============================================================
-- 2. user_achievements 表（用户解锁记录）
-- ============================================================
CREATE TABLE IF NOT EXISTS user_achievements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    achievement_id text NOT NULL REFERENCES achievements(id),
    unlocked_at timestamptz DEFAULT now(),
    UNIQUE(user_id, achievement_id)
);

CREATE INDEX IF NOT EXISTS idx_user_achievements_user
    ON user_achievements(user_id);

ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "用户只能查看自己的成就"
    ON user_achievements FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "系统可写入成就"
    ON user_achievements FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 3. 预设成就种子数据（15 条）
-- ============================================================
INSERT INTO achievements (id, title, description, icon, category, condition_type, condition_value, xp_bonus, gold_bonus, sort_order)
VALUES
    -- 任务类 (5)
    ('first_quest',  '初出茅庐',     '完成第 1 个任务',       '🌱', 'quest',   'total_completed', 1,    50,   0,  1),
    ('quest_10',     '勤劳村民',     '累计完成 10 个任务',    '🔨', 'quest',   'total_completed', 10,   100,  0,  2),
    ('quest_50',     '任务达人',     '累计完成 50 个任务',    '⚔️', 'quest',   'total_completed', 50,   300,  0,  3),
    ('quest_100',    '百战英雄',     '累计完成 100 个任务',   '🛡️', 'quest',   'total_completed', 100,  500,  0,  4),
    ('quest_500',    '传奇冒险家',   '累计完成 500 个任务',   '👑', 'quest',   'total_completed', 500,  1000, 0,  5),

    -- 连续签到类 (4)
    ('streak_3',     '三日坚持',     '连续签到 3 天',         '🔥', 'streak',  'streak',          3,    100,  0,  6),
    ('streak_7',     '周冠勇士',     '连续签到 7 天',         '🏅', 'streak',  'streak',          7,    300,  0,  7),
    ('streak_14',    '半月征途',     '连续签到 14 天',        '⭐', 'streak',  'streak',          14,   500,  0,  8),
    ('streak_30',    '月之守护者',   '连续签到 30 天',        '🌙', 'streak',  'streak',          30,   1000, 0,  9),

    -- XP / 等级类 (4)
    ('xp_1000',      '千里之行',     '累计获得 1000 XP',      '📈', 'xp',      'total_xp',        1000, 200,  0,  10),
    ('xp_5000',      '经验丰富',     '累计获得 5000 XP',      '💎', 'xp',      'total_xp',        5000, 500,  0,  11),
    ('level_5',      '进阶冒险者',   '达到 5 级',             '🎯', 'xp',      'level',           5,    300,  0,  12),
    ('level_10',     '资深探索者',   '达到 10 级',            '🏰', 'xp',      'level',           10,   500,  0,  13),

    -- 特殊类 (2)
    ('board_clear',  '日清达人',     '首次清空任务面板',      '✨', 'special', 'board_clear',     1,    200,  0,  14),
    ('first_wechat', '微信通道',     '首次通过微信创建任务',  '📱', 'special', 'first_wechat',    1,    100,  0,  15)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 4. RPC：check_and_unlock_achievements
--    按类别检查未解锁成就，满足条件则解锁并发放奖励
-- ============================================================
CREATE OR REPLACE FUNCTION public.check_and_unlock_achievements(
    p_user_id uuid,
    p_category text
)
RETURNS TABLE(achievement_id text, title text, icon text, xp_bonus int, gold_bonus int)
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

            -- 输出新解锁记录
            achievement_id := rec.id;
            title          := rec.title;
            icon           := rec.icon;
            xp_bonus       := rec.xp_bonus;
            gold_bonus     := rec.gold_bonus;
            RETURN NEXT;
        END IF;
    END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_and_unlock_achievements(uuid, text) TO authenticated;

-- 刷新 PostgREST schema 缓存
NOTIFY pgrst, 'reload schema';
