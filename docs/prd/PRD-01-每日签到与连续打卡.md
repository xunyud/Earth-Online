# PRD-01：每日签到与连续打卡系统

## 1. 功能概述

在现有 `daily_logs` 基础上构建签到系统，追踪用户连续完成天数，并通过 XP 奖励倍率激励持续使用。

## 2. 用户故事

- 作为用户，我希望每天完成至少一个任务后自动签到，让我有持续使用的动力。
- 作为用户，我希望看到连续打卡天数和当前倍率，让我不想断签。
- 作为用户，如果断签了，我希望知道倍率会重置，但不会丢失已有 XP。

## 3. 现状分析

### 已有基础
- `daily_logs` 表：存在 `date_id`、`completed_count`、`is_perfect`、`encouragement` 字段
- `QuestController._upsertDailyLogForToday()`：任务完成时已在写入日志
- `profiles` 表：有 `total_xp`、`level`、`current_xp`、`max_xp` 字段
- `LevelEngine`：已实现等级计算逻辑

### 缺失项
- `daily_logs` 表迁移文件缺失（线上可能已存在，需补齐本地迁移）
- `daily_logs` 无 `user_id` 字段（需确认）或查询未带过滤
- 无连续签到天数追踪
- 无 XP 倍率机制

## 4. 数据模型变更

### 4.1 daily_logs 表补充字段
```sql
ALTER TABLE daily_logs ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id);
ALTER TABLE daily_logs ADD COLUMN IF NOT EXISTS streak_day int DEFAULT 0;  -- 当日连续天数快照
ALTER TABLE daily_logs ADD COLUMN IF NOT EXISTS xp_multiplier double precision DEFAULT 1.0;  -- 当日倍率快照
ALTER TABLE daily_logs ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
```

### 4.2 profiles 表补充字段
```sql
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS current_streak int DEFAULT 0;       -- 当前连续天数
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS longest_streak int DEFAULT 0;       -- 历史最长连续天数
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_checkin_date date;             -- 上次签到日期
```

## 5. 核心逻辑

### 5.1 签到触发条件
- **自动签到**：当天首次完成任务时自动触发（不需要手动签到按钮）
- 判断依据：`profiles.last_checkin_date != today`

### 5.2 连续天数计算
```
if last_checkin_date == yesterday:
    current_streak += 1
elif last_checkin_date == today:
    pass  # 已签到，不重复计算
else:
    current_streak = 1  # 断签，重置为 1

longest_streak = max(longest_streak, current_streak)
last_checkin_date = today
```

### 5.3 XP 倍率规则
| 连续天数 | 倍率 | 说明 |
|---------|------|------|
| 1-2 天  | ×1.0 | 基础倍率 |
| 3-6 天  | ×1.5 | 初级连续奖励 |
| 7-13 天 | ×2.0 | 周级连续奖励 |
| 14-29 天| ×2.5 | 双周级奖励 |
| 30+ 天  | ×3.0 | 月级封顶奖励 |

### 5.4 XP 计算变更
当前：`deltaXp = sumXp`（所有子任务 xpReward 之和）
变更为：`deltaXp = sumXp × xp_multiplier`

仅在当天首次签到时计算倍率并写入 `daily_logs.xp_multiplier`；后续完成任务使用缓存的当日倍率。

## 6. 前端变更

### 6.1 签到状态展示（HomePage 顶部栏）
- 显示：🔥 连续 N 天 | 倍率 ×M
- 动画：签到时播放火焰特效（复用 confetti 库）
- 断签提示：倍率重置时 Snackbar 提示"连续签到中断，倍率已重置为 ×1.0"

### 6.2 签到日历（可选，放入人生日记页）
- 当月日历视图，已签到日期标绿色圆点
- 完美日（全部完成）标金色圆点
- 显示当月签到率

### 6.3 任务完成时的倍率提示
- 完成任务的 XP Toast 中显示倍率："+30 XP (×1.5)"

## 7. 后端变更

### 7.1 Postgres RPC 函数
创建 `checkin_and_get_multiplier(p_user_id uuid)` 函数：
- 读取 `profiles.last_checkin_date` 和 `current_streak`
- 按规则更新连续天数和倍率
- 写入 `daily_logs` 当日记录
- 返回 `{streak, multiplier, is_new_checkin}`

### 7.2 修改 _applyCustomStatsDelta
- 在调用前先获取当日倍率
- 将 `deltaXp × multiplier` 传入 RPC

## 8. 边界情况
- **时区问题**：以用户本地日期为准，签到日期使用 `DateTime.now().toLocal()` 的日期部分
- **补签**：V1 不支持补签
- **跨天任务**：23:50 开始的任务在 00:10 完成，按完成时间的日期记入
- **同时多设备**：RPC 使用 `FOR UPDATE` 锁防止并发签到

## 9. 验收标准
- [ ] 当天首次完成任务，连续天数 +1，倍率正确更新
- [ ] 断签后倍率重置为 ×1.0，连续天数重置为 1
- [ ] HomePage 顶部正确显示连续天数和倍率
- [ ] 任务完成时 XP 按倍率正确计算
- [ ] `daily_logs` 正确记录 `streak_day` 和 `xp_multiplier`
