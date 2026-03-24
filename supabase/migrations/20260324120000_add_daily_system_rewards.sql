-- 为系统商城补充日常型固定商品，避免影响用户自定义奖励

INSERT INTO rewards (
  title,
  description,
  cost,
  category,
  icon,
  effect_type,
  effect_value,
  is_system,
  is_active,
  user_id
)
SELECT
  seed.title,
  seed.description,
  seed.cost,
  'custom',
  seed.icon,
  NULL,
  NULL,
  true,
  true,
  NULL
FROM (
  VALUES
    ('听一首歌', '给自己几分钟，安静听完一首喜欢的歌。', 1, '🎵'),
    ('散步二十分钟', '暂时离开任务列表，去走一走换换脑子。', 20, '🚶'),
    ('看一集喜欢的内容', '看一集喜欢的剧、动画或视频。', 30, '📺'),
    ('买一杯喜欢的饮料', '用一杯喜欢的饮料犒劳一下自己。', 35, '🥤'),
    ('躺平放空半小时', '什么都不做，专心休息半小时。', 40, '🛋️'),
    ('喝杯奶茶', '买一杯奶茶，认真享受一下。', 50, '🧋'),
    ('点一份喜欢的小甜点', '来一份甜点，给努力一个具体回报。', 60, '🍰'),
    ('玩游戏一小时', '给自己一小时完整的娱乐时间。', 80, '🎮')
) AS seed(title, description, cost, icon)
WHERE NOT EXISTS (
  SELECT 1
  FROM rewards existing
  WHERE existing.is_system = true
    AND existing.title = seed.title
);

NOTIFY pgrst, 'reload schema';
