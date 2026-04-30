-- 记忆护城河：记忆模式驱动的成就解锁
-- 新增 memory 类别和三种记忆成就：memory_100、memory_guardian_30、living_memory_50
-- 同时在 profiles 表新增记忆统计列，供成就检测查询

-- 1. 扩展 achievements 表的 category 和 condition_type CHECK 约束
ALTER TABLE achievements DROP CONSTRAINT IF EXISTS achievements_category_check;
ALTER TABLE achievements ADD CONSTRAINT achievements_category_check
  CHECK (category IN ('quest', 'streak', 'xp', 'special', 'memory'));

ALTER TABLE achievements DROP CONSTRAINT IF EXISTS achievements_condition_type_check;
ALTER TABLE achievements ADD CONSTRAINT achievements_condition_type_check
  CHECK (condition_type IN (
    'total_completed', 'streak', 'total_xp', 'level', 'board_clear', 'first_wechat',
    'memory_count', 'memory_streak', 'memory_reference'
  ));

-- 2. profiles 新增记忆统计列
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_memory_count int DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS memory_streak_days int DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_memory_date date;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS guide_memory_reference_count int DEFAULT 0;

-- 3. 插入三条记忆成就种子数据
INSERT INTO achievements (id, title, description, icon, category, condition_type, condition_value, xp_bonus, gold_bonus, sort_order)
VALUES
  ('memory_100',       '记忆百条',   '累计写入 100 条记忆',           '🧠', 'memory', 'memory_count',     100, 300, 0, 16),
  ('memory_guardian_30','记忆守护者', '连续 30 天每天至少写入 1 条记忆','🛡️', 'memory', 'memory_streak',    30,  500, 0, 17),
  ('living_memory_50', '活的记忆',   '记忆被 Guide 引用累计 50 次',   '💡', 'memory', 'memory_reference',  50,  400, 0, 18)
ON CONFLICT (id) DO NOTHING;

NOTIFY pgrst, 'reload schema';
