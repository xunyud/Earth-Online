# PRD-05：道具商城增强

## 1. 功能概述

在现有奖励兑换系统基础上，增加系统预设商品（皮肤/主题/特效），形成"完成任务 → 赚取金币 → 购买道具 → 个性化体验"的完整闭环。

## 2. 用户故事

- 作为用户，我希望用赚到的金币购买主题皮肤，自定义 App 外观。
- 作为用户，我希望购买特效道具（如双倍 XP 卡），加速成长。
- 作为用户，我希望在背包中管理已购道具，选择激活/使用。

## 3. 现状分析

### 已有基础
- `RewardController`：支持 `loadRewards`、`addReward`、`buyReward`、`loadInventory`、`useItem`
- `RewardShopPage`：展示商品列表、余额、兑换按钮
- `InventoryPage`：展示背包物品、使用按钮
- `Reward` 模型：`id`、`title`、`cost`
- `InventoryItem` 模型：`id`、`rewardTitle`、`cost`
- 两套主题已实现（清新呼吸 / 黑暗之魂）
- RPC `buy_reward` 被调用但 SQL 定义缺失

### 缺失项
- `rewards` / `inventory` 表迁移缺失
- `buy_reward` RPC 未定义
- `profiles.gold` 字段未定义
- `increment_custom_stats` RPC 未定义
- 仅支持用户自定义奖励，无系统预设商品
- 无道具效果系统（购买后无实际功能变化）

## 4. 数据模型变更

### 4.1 补齐缺失表和字段

```sql
-- profiles 补充 gold 字段
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS gold int DEFAULT 0;

-- rewards 表（用户自定义 + 系统预设）
CREATE TABLE IF NOT EXISTS rewards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id),    -- NULL 表示系统预设
    title text NOT NULL,
    description text,
    cost int NOT NULL DEFAULT 0,
    category text NOT NULL DEFAULT 'custom',    -- custom / theme / effect / cosmetic
    icon text,                                  -- emoji 或图标
    effect_type text,                           -- 效果类型：theme_unlock / xp_boost / confetti_style
    effect_value text,                          -- 效果参数（如主题 ID、倍率）
    is_system boolean DEFAULT false,            -- 是否系统预设
    is_active boolean DEFAULT true,             -- 是否在售
    created_at timestamptz DEFAULT now()
);

-- inventory 表（用户已购道具）
CREATE TABLE IF NOT EXISTS inventory (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id),
    reward_id uuid REFERENCES rewards(id),
    reward_title text NOT NULL,
    cost int DEFAULT 0,
    is_used boolean DEFAULT false,              -- 一次性道具是否已使用
    is_equipped boolean DEFAULT false,          -- 持久道具是否装备中
    purchased_at timestamptz DEFAULT now(),
    used_at timestamptz
);

-- RLS
ALTER TABLE rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;

CREATE POLICY "所有人可查看系统商品和自己的商品"
    ON rewards FOR SELECT
    USING (is_system = true OR auth.uid() = user_id);

CREATE POLICY "用户管理自己的背包"
    ON inventory FOR ALL
    USING (auth.uid() = user_id);
```

### 4.2 RPC 函数补齐

```sql
-- 购买道具
CREATE OR REPLACE FUNCTION buy_reward(r_id uuid, r_cost int)
RETURNS boolean AS $$
DECLARE
    v_gold int;
BEGIN
    SELECT gold INTO v_gold FROM profiles WHERE id = auth.uid() FOR UPDATE;
    IF v_gold < r_cost THEN RETURN false; END IF;

    UPDATE profiles SET gold = gold - r_cost WHERE id = auth.uid();
    INSERT INTO inventory (user_id, reward_id, reward_title, cost)
        SELECT auth.uid(), r_id, title, cost FROM rewards WHERE id = r_id;
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- XP/金币增量更新
CREATE OR REPLACE FUNCTION increment_custom_stats(delta_xp int, delta_gold int)
RETURNS void AS $$
BEGIN
    UPDATE profiles
    SET total_xp = total_xp + delta_xp,
        gold = gold + delta_gold
    WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## 5. 系统预设商品

### 5.1 主题类
| 名称 | 价格 | 效果 | effect_type | effect_value |
|------|------|------|-------------|-------------|
| 🌊 深海主题 | 500 金币 | 解锁深海配色方案 | theme_unlock | ocean_deep |
| 🌸 樱花主题 | 500 金币 | 解锁粉色樱花配色 | theme_unlock | sakura |
| 🔥 熔岩主题 | 800 金币 | 解锁暗红熔岩配色 | theme_unlock | lava |

### 5.2 特效类（一次性）
| 名称 | 价格 | 效果 | 持续时间 |
|------|------|------|---------|
| ⚡ 双倍 XP 卡 | 200 金币 | 下次完成任务 XP ×2 | 单次 |
| 🎆 烟花特效 | 100 金币 | 下次完成任务播放烟花 | 单次 |
| 🛡️ 签到保护卡 | 300 金币 | 断签时保留连续天数 | 单次 |

### 5.3 装饰类（永久）
| 名称 | 价格 | 效果 |
|------|------|------|
| 🎖️ 金色边框 | 1000 金币 | 任务卡片金色边框 |
| ✨ 完成特效升级 | 600 金币 | 完成动画从对勾变为星光 |

## 6. 前端变更

### 6.1 商城页改造
现有 `RewardShopPage` 改造为分区展示：

```
┌─────────────────────────┐
│ 💰 余额: 1,250 金币      │
├─────────────────────────┤
│ [系统商城] [我的奖励]     │  ← Tab 切换
├─────────────────────────┤
│ 🎨 主题                  │
│ ┌───┐ ┌───┐ ┌───┐      │
│ │🌊 │ │🌸 │ │🔥 │      │
│ │500│ │500│ │800│      │
│ └───┘ └───┘ └───┘      │
│                         │
│ ⚡ 特效                  │
│ ┌───────┐ ┌───────┐    │
│ │双倍XP  │ │烟花特效│    │
│ │200金币 │ │100金币 │    │
│ └───────┘ └───────┘    │
│                         │
│ 🎖️ 装饰                 │
│ ...                     │
└─────────────────────────┘
```

### 6.2 背包页改造
- 分为"可使用"和"已装备"两个区域
- 一次性道具显示"使用"按钮
- 永久道具显示"装备/卸下"开关
- 已使用的一次性道具灰显或隐藏

### 6.3 道具效果系统
```dart
// 在 QuestController 中集成
Future<double> _getActiveEffects() async {
  // 检查是否有激活的双倍 XP 卡
  // 检查是否有签到保护卡（断签时消耗）
  // 返回额外倍率
}
```

### 6.4 主题解锁集成
- 设置页主题列表中，未购买的主题显示锁定图标 + 价格
- 点击锁定主题跳转商城
- 购买后自动解锁，可在设置中切换

## 7. 文件结构变更
```
lib/features/reward/
├── controllers/
│   └── reward_controller.dart    # 扩展：系统商品加载、分类、效果检查
├── models/
│   ├── reward.dart               # 扩展：category, effect_type, effect_value, is_system
│   └── inventory_item.dart       # 扩展：is_equipped, reward_id, effect 相关
├── screens/
│   ├── reward_shop_page.dart     # 改造：Tab 切换系统/自定义
│   └── inventory_page.dart       # 改造：分区展示
└── widgets/
    ├── system_shop_grid.dart     # 新增：系统商品网格
    └── effect_badge.dart         # 新增：道具效果标签
```

## 8. 边界情况
- **金币不足**：购买按钮灰显 + 提示"金币不足"
- **重复购买主题**：永久类商品购买后从商城隐藏或显示"已拥有"
- **并发购买**：RPC 使用 `FOR UPDATE` 锁防止超扣
- **道具过期**：V1 不做时间限制，所有道具永不过期
- **向后兼容**：现有的用户自定义奖励保持不变，`is_system=false`

## 9. 依赖项
- 无新依赖

## 10. 验收标准
- [ ] 商城正确显示系统预设商品和用户自定义奖励
- [ ] 金币余额正确扣减
- [ ] 购买的主题可在设置中解锁切换
- [ ] 双倍 XP 卡使用后下次完成任务 XP 翻倍
- [ ] 签到保护卡在断签时自动消耗
- [ ] 背包正确区分可使用/已装备道具
- [ ] `buy_reward` 和 `increment_custom_stats` RPC 正常工作
