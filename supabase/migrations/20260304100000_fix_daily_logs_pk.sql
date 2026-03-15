-- 修复 daily_logs 主键：从单列 date_id 改为复合 (user_id, date_id)
-- 以支持多用户场景和 ON CONFLICT (user_id, date_id)

-- 1. 删除旧主键约束
ALTER TABLE daily_logs DROP CONSTRAINT IF EXISTS daily_logs_pkey;

-- 2. 确保 user_id 列非空（已有数据可能为 null，用当前默认用户填充）
UPDATE daily_logs SET user_id = (
    SELECT id FROM auth.users LIMIT 1
) WHERE user_id IS NULL;

ALTER TABLE daily_logs ALTER COLUMN user_id SET NOT NULL;

-- 3. 添加复合主键
ALTER TABLE daily_logs ADD PRIMARY KEY (user_id, date_id);
