# PRD-04：成就徽章系统

## 1. 功能概述

设计一套里程碑成就系统，用户在达到特定条件时自动解锁徽章，配合弹窗动画提供正向反馈。

## 2. 用户故事

- 作为用户，我希望在完成里程碑时获得徽章奖励，增加成就感。
- 作为用户，我希望浏览已解锁和未解锁的徽章列表，了解下一个目标。
- 作为用户，我希望解锁时有惊喜动画，让体验更有趣。

## 3. 现状分析

### 已有基础
- XP/等级系统已完善（`LevelEngine`、`profiles.total_xp`）
- 连续签到系统（PRD-01 完成后提供 `current_streak`、`longest_streak`）
- 任务完成计数（`daily_logs.completed_count`）
- confetti 动画库已引入

### 缺失项
- 无成就定义表
- 无成就解锁记录表
- 无成就检查触发机制

## 4. 数据模型

### 4.1 achievements 表（成就定义，静态数据）
```sql
CREATE TABLE achievements (
    id text PRIMARY KEY,                     -- 唯一标识，如 'first_quest', 'streak_7'
    title text NOT NULL,                     -- 显示名称
    description text NOT NULL,               -- 解锁条件描述
    icon text NOT NULL,                      -- emoji 或图标标识
    category text NOT NULL,                  -- 分类：quest / streak / xp / special
    condition_type text NOT NULL,            -- 条件类型：total_completed / streak / total_xp / board_clear / level
    condition_value int NOT NULL,            -- 条件阈值
    xp_bonus int DEFAULT 0,                 -- 解锁奖励 XP
    gold_bonus int DEFAULT 0,               -- 解锁奖励金币
    sort_order int DEFAULT 0
);
```

### 4.2 user_achievements 表（用户解锁记录）
```sql
CREATE TABLE user_achievements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id),
    achievement_id text NOT NULL REFERENCES achievements(id),
    unlocked_at timestamptz DEFAULT now(),
    UNIQUE(user_id, achievement_id)
);

-- RLS
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "用户只能查看自己的成就"
    ON user_achievements FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "系统可写入成就"
    ON user_achievements FOR INSERT WITH CHECK (auth.uid() = user_id);
```

### 4.3 预设成就列表

#### 任务类
| ID | 名称 | 条件 | 奖励 |
|----|------|------|------|
| first_quest | 初出茅庐 | 完成第 1 个任务 | +50 XP |
| quest_10 | 勤劳村民 | 累计完成 10 个任务 | +100 XP |
| quest_50 | 任务达人 | 累计完成 50 个任务 | +300 XP |
| quest_100 | 百战英雄 | 累计完成 100 个任务 | +500 XP |
| quest_500 | 传奇冒险家 | 累计完成 500 个任务 | +1000 XP |

#### 连续签到类
| ID | 名称 | 条件 | 奖励 |
|----|------|------|------|
| streak_3 | 三日坚持 | 连续签到 3 天 | +100 XP |
| streak_7 | 周冠勇士 | 连续签到 7 天 | +300 XP |
| streak_14 | 半月征途 | 连续签到 14 天 | +500 XP |
| streak_30 | 月之守护者 | 连续签到 30 天 | +1000 XP |

#### XP / 等级类
| ID | 名称 | 条件 | 奖励 |
|----|------|------|------|
| xp_1000 | 千里之行 | 累计 1000 XP | +200 XP |
| xp_5000 | 经验丰富 | 累计 5000 XP | +500 XP |
| level_5 | 进阶冒险者 | 达到 5 级 | +300 XP |
| level_10 | 资深探索者 | 达到 10 级 | +500 XP |

#### 特殊类
| ID | 名称 | 条件 | 奖励 |
|----|------|------|------|
| board_clear | 日清达人 | 首次清空任务面板 | +200 XP |
| first_wechat | 微信通道 | 首次通过微信创建任务 | +100 XP |

## 5. 核心逻辑

### 5.1 成就检查触发点
成就检查不应在每次操作都全量扫描，而是在特定事件后检查对应类别：

| 事件 | 检查的成就类别 |
|------|--------------|
| 任务完成 | quest 类 + special(board_clear) |
| 签到成功 | streak 类 |
| XP 变更 | xp 类 + level 类 |
| 微信任务入库 | special(first_wechat) |

### 5.2 检查流程
```
1. 获取用户已解锁的成就 ID 列表（缓存在内存中）
2. 根据事件类型，筛选出待检查的未解锁成就
3. 按 condition_type 读取用户当前值：
   - total_completed: COUNT(*) FROM quest_nodes WHERE is_completed AND user_id
   - streak: profiles.current_streak
   - total_xp: profiles.total_xp
   - level: LevelEngine.fromTotalXp().level
   - board_clear: 当前未完成任务数 == 0
4. 如果 current_value >= condition_value，插入 user_achievements 并触发弹窗
5. 发放奖励 XP/Gold
```

### 5.3 Postgres RPC 函数
```sql
CREATE OR REPLACE FUNCTION check_and_unlock_achievements(p_user_id uuid, p_category text)
RETURNS TABLE(achievement_id text, title text, icon text, xp_bonus int, gold_bonus int) AS $$
  -- 查询该类别下未解锁的成就
  -- 检查条件是否满足
  -- 批量插入 user_achievements
  -- 返回新解锁的成就列表
$$ LANGUAGE plpgsql;
```

## 6. 前端变更

### 6.1 成就页面
```
lib/features/achievement/
├── controllers/
│   └── achievement_controller.dart
├── models/
│   └── achievement.dart
├── screens/
│   └── achievement_page.dart
└── widgets/
    ├── achievement_card.dart          # 单个徽章卡片
    └── achievement_unlock_dialog.dart # 解锁弹窗动画
```

### 6.2 成就列表页
- 入口：HomePage 中新增"🏆 成就"入口（可放在个人中心或侧边栏）
- 按分类展示：任务 / 签到 / 经验 / 特殊
- 已解锁：彩色显示 + 解锁日期
- 未解锁：灰色 + 进度条（如 "47/50 任务"）

### 6.3 解锁弹窗
- 全屏半透明遮罩
- 居中卡片：徽章图标（放大动画）+ 名称 + 描述 + "+N XP" 奖励
- confetti 撒花特效
- 点击任意处或 2 秒后自动关闭

### 6.4 集成到 QuestController
- 任务完成后调用 `achievementController.checkAchievements('quest')`
- 签到后调用 `achievementController.checkAchievements('streak')`
- XP 变更后调用 `achievementController.checkAchievements('xp')`

## 7. 边界情况
- **批量解锁**：一次操作可能触发多个成就（如完成第 50 个任务同时达到 1000 XP），依次弹窗，间隔 0.5 秒
- **离线解锁**：如果用户在离线时满足条件，上线同步后补发（RPC 层面判断）
- **成就数据一致性**：使用 `UNIQUE(user_id, achievement_id)` 约束防止重复解锁
- **成就定义扩展**：后续新增成就时，只需 INSERT 到 `achievements` 表，无需改代码

## 8. 依赖项
- 无新依赖（confetti 库已引入）

## 9. 验收标准
- [ ] 完成第 1 个任务时解锁"初出茅庐"并弹窗
- [ ] 连续签到 3/7 天时解锁对应成就
- [ ] 成就页正确显示已解锁/未解锁状态和进度
- [ ] 解锁动画流畅，confetti 特效正常
- [ ] 奖励 XP 正确发放并反映在等级系统
- [ ] 不会重复解锁同一成就
