-- =====================================================
-- 为核心业务表添加 Row Level Security 策略
-- quest_nodes / raw_messages / parsed_tasks
-- 使用 ::text 双向转换确保 text/uuid 列均兼容
-- =====================================================

-- 1. quest_nodes（核心任务表）
ALTER TABLE quest_nodes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_own_quests" ON quest_nodes
  FOR SELECT USING (user_id::text = auth.uid()::text);

CREATE POLICY "users_insert_own_quests" ON quest_nodes
  FOR INSERT WITH CHECK (user_id::text = auth.uid()::text);

CREATE POLICY "users_update_own_quests" ON quest_nodes
  FOR UPDATE USING (user_id::text = auth.uid()::text);

CREATE POLICY "users_delete_own_quests" ON quest_nodes
  FOR DELETE USING (user_id::text = auth.uid()::text);

-- 2. raw_messages（原始消息缓存）
ALTER TABLE raw_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_own_messages" ON raw_messages
  FOR SELECT USING (user_id::text = auth.uid()::text);

CREATE POLICY "users_insert_own_messages" ON raw_messages
  FOR INSERT WITH CHECK (user_id::text = auth.uid()::text);

-- 3. parsed_tasks（历史解析结果）
ALTER TABLE parsed_tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_own_parsed_tasks" ON parsed_tasks
  FOR SELECT USING (user_id::text = auth.uid()::text);

CREATE POLICY "users_insert_own_parsed_tasks" ON parsed_tasks
  FOR INSERT WITH CHECK (user_id::text = auth.uid()::text);

-- 4. 为 quest_nodes 添加常用查询索引
CREATE INDEX IF NOT EXISTS idx_quest_nodes_user_completed
  ON quest_nodes(user_id, is_completed);

CREATE INDEX IF NOT EXISTS idx_quest_nodes_user_created
  ON quest_nodes(user_id, created_at DESC);
