-- 停用旧系统商品，仅保留日常奖励型系统商城商品
-- 这里不直接物理删除，避免影响已购买背包记录对 rewards.id 的引用

UPDATE rewards
SET
  is_active = false
WHERE is_system = true
  AND title NOT IN (
    '听一首歌',
    '散步二十分钟',
    '看一集喜欢的内容',
    '买一杯喜欢的饮料',
    '躺平放空半小时',
    '喝杯奶茶',
    '点一份喜欢的小甜点',
    '玩游戏一小时'
  );

UPDATE rewards
SET
  is_active = true,
  category = 'custom',
  effect_type = NULL,
  effect_value = NULL,
  user_id = NULL
WHERE is_system = true
  AND title IN (
    '听一首歌',
    '散步二十分钟',
    '看一集喜欢的内容',
    '买一杯喜欢的饮料',
    '躺平放空半小时',
    '喝杯奶茶',
    '点一份喜欢的小甜点',
    '玩游戏一小时'
  );

NOTIFY pgrst, 'reload schema';
