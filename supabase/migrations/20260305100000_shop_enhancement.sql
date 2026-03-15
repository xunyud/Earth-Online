-- ============================================================
-- PRD-05: 道具商城增强
-- 补齐 rewards/inventory 表字段、重写 buy_reward RPC、种子数据
-- ============================================================

-- 1. rewards 表：允许 user_id 为 NULL（系统预设商品无所属用户）
ALTER TABLE rewards ALTER COLUMN user_id DROP NOT NULL;

-- rewards 表补充字段
ALTER TABLE rewards ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE rewards ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'custom';
ALTER TABLE rewards ADD COLUMN IF NOT EXISTS icon text;
ALTER TABLE rewards ADD COLUMN IF NOT EXISTS effect_type text;
ALTER TABLE rewards ADD COLUMN IF NOT EXISTS effect_value text;
ALTER TABLE rewards ADD COLUMN IF NOT EXISTS is_system boolean DEFAULT false;
ALTER TABLE rewards ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;
ALTER TABLE rewards ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

-- 2. inventory 表补充字段
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS reward_id uuid REFERENCES rewards(id);
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS is_equipped boolean DEFAULT false;
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS purchased_at timestamptz DEFAULT now();
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS used_at timestamptz;
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS effect_type text;
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS effect_value text;

-- 3. RLS 策略
ALTER TABLE rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "查看系统商品和自己的商品" ON rewards;
CREATE POLICY "查看系统商品和自己的商品"
    ON rewards FOR SELECT
    USING (is_system = true OR auth.uid() = user_id);

DROP POLICY IF EXISTS "用户管理自己的自定义商品" ON rewards;
CREATE POLICY "用户管理自己的自定义商品"
    ON rewards FOR INSERT WITH CHECK (auth.uid() = user_id AND is_system = false);

DROP POLICY IF EXISTS "用户删除自己的自定义商品" ON rewards;
CREATE POLICY "用户删除自己的自定义商品"
    ON rewards FOR DELETE USING (auth.uid() = user_id AND is_system = false);

DROP POLICY IF EXISTS "用户查看自己的背包" ON inventory;
CREATE POLICY "用户查看自己的背包"
    ON inventory FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "用户更新自己的背包" ON inventory;
CREATE POLICY "用户更新自己的背包"
    ON inventory FOR UPDATE USING (auth.uid() = user_id);

-- 4. 重写 buy_reward RPC（改为 r_id 参数，原子扣币+入库+携带效果信息）
CREATE OR REPLACE FUNCTION public.buy_reward(r_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_gold int;
    v_cost int;
    v_title text;
    v_effect_type text;
    v_effect_value text;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'not_authenticated';
    END IF;

    -- 读取商品信息
    SELECT cost, title, effect_type, effect_value
    INTO v_cost, v_title, v_effect_type, v_effect_value
    FROM rewards
    WHERE id = r_id AND is_active = true;

    IF v_cost IS NULL THEN
        RAISE EXCEPTION 'reward_not_found';
    END IF;

    -- 锁定用户行，读取金币
    SELECT gold INTO v_gold
    FROM profiles
    WHERE id = auth.uid()
    FOR UPDATE;

    IF v_gold < v_cost THEN
        RETURN false;
    END IF;

    -- 扣币
    UPDATE profiles SET gold = gold - v_cost WHERE id = auth.uid();

    -- 入库背包
    INSERT INTO inventory (user_id, reward_id, reward_title, cost, effect_type, effect_value)
    VALUES (auth.uid(), r_id, v_title, v_cost, v_effect_type, v_effect_value);

    RETURN true;
END;
$$;

-- 删除旧版签名（如果存在）
DROP FUNCTION IF EXISTS public.buy_reward(text, int);
DROP FUNCTION IF EXISTS public.buy_reward(uuid, int);

GRANT EXECUTE ON FUNCTION public.buy_reward(uuid) TO authenticated;

-- 5. 系统预设商品种子数据
-- 先清理已有系统商品（幂等）
DELETE FROM rewards WHERE is_system = true;

-- 主题类
INSERT INTO rewards (title, description, cost, category, icon, effect_type, effect_value, is_system, user_id)
VALUES
    ('深海主题', '解锁深海配色方案，沉浸于幽蓝深邃的海底世界', 500, 'theme', '🌊', 'theme_unlock', 'ocean_deep', true, NULL),
    ('樱花主题', '解锁粉色樱花配色，感受春日浪漫', 500, 'theme', '🌸', 'theme_unlock', 'sakura', true, NULL),
    ('熔岩主题', '解锁暗红熔岩配色，体验炽热的冒险', 800, 'theme', '🔥', 'theme_unlock', 'lava', true, NULL);

-- 特效类（一次性）
INSERT INTO rewards (title, description, cost, category, icon, effect_type, effect_value, is_system, user_id)
VALUES
    ('双倍 XP 卡', '下次完成任务时经验值翻倍', 200, 'effect', '⚡', 'xp_boost', '2.0', true, NULL),
    ('烟花特效', '下次完成任务时播放绚丽烟花', 100, 'effect', '🎆', 'confetti_style', 'fireworks', true, NULL),
    ('签到保护卡', '断签时自动使用，保留连续天数', 300, 'effect', '🛡️', 'streak_protect', '1', true, NULL);

-- 装饰类（永久）
INSERT INTO rewards (title, description, cost, category, icon, effect_type, effect_value, is_system, user_id)
VALUES
    ('金色边框', '任务卡片换上尊贵的金色边框', 1000, 'cosmetic', '🎖️', 'card_border', 'gold', true, NULL),
    ('完成特效升级', '完成动画从对勾变为星光特效', 600, 'cosmetic', '✨', 'complete_effect', 'sparkle', true, NULL);

-- 索引
CREATE INDEX IF NOT EXISTS idx_rewards_system ON rewards(is_system) WHERE is_system = true;
CREATE INDEX IF NOT EXISTS idx_inventory_user_unused ON inventory(user_id, is_used) WHERE is_used = false;

-- 刷新 PostgREST schema 缓存
NOTIFY pgrst, 'reload schema';
