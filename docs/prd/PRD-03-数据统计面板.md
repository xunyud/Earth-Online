# PRD-03：数据统计面板

## 1. 功能概述

新增统计页面，以图表形式展示用户的任务完成趋势、XP 曲线等关键数据，帮助用户回顾成长轨迹。所有数据均来自现有表，不需要新建数据表。

## 2. 用户故事

- 作为用户，我希望看到过去一周/一月的任务完成数量趋势，了解自己的效率变化。
- 作为用户，我希望看到 XP 累积曲线和等级进度，获得成就感。
- 作为用户，我希望知道"最高效的一天"和"最长连续打卡"等亮点数据。

## 3. 现状分析

### 数据来源
- `quest_nodes`：`completed_at`（完成时间）、`xp_reward`（经验值）、`quest_tier`（任务等级）
- `daily_logs`：`date_id`、`completed_count`、`is_perfect`、`streak_day`（PRD-01 新增）
- `profiles`：`total_xp`、`level`、`current_streak`、`longest_streak`（PRD-01 新增）

### 已有基础
- `life_diary_page.dart` 已按天分组查询已完成任务
- `LevelEngine` 可计算任意 XP 值对应的等级

## 4. 页面设计

### 4.1 入口
- HomePage 底部导航栏新增 Tab："📊 统计"
- 或在人生日记页顶部增加切换按钮

### 4.2 统计页布局

#### 顶部：亮点卡片区（横滑）
| 卡片 | 数据来源 |
|------|---------|
| 本周完成 N 个任务 | `quest_nodes` WHERE `completed_at` >= 7天前 |
| 累计 XP: N | `profiles.total_xp` |
| 当前等级: Lv.N "称号" | `LevelEngine` |
| 最长连续: N 天 | `profiles.longest_streak` |
| 最高效一天: M月D日 (N个) | `daily_logs` MAX(`completed_count`) |

#### 中部：任务完成趋势图
- **默认周视图**：最近 7 天的每日完成数柱状图
- **可切换月视图**：最近 30 天趋势折线图
- X 轴：日期；Y 轴：完成数量
- 完美日（`is_perfect=true`）柱子顶部加星标

#### 下部：XP 累积曲线
- 折线图：展示过去 30 天的 XP 日累积值
- 等级线：在对应 XP 值处画横虚线标注等级门槛
- 数据来源：按天聚合 `quest_nodes.xp_reward` WHERE `completed_at` 在范围内

#### 底部：任务分类饼图
- 饼图/环形图：按 `quest_tier` 分类的完成任务占比
- Main_Quest / Side_Quest / Daily 三类
- 时间范围与上方图表联动

## 5. 技术方案

### 5.1 图表库选型
- **推荐**：`fl_chart`（纯 Flutter，无平台依赖，支持柱状图/折线图/饼图）
- **备选**：`syncfusion_flutter_charts`（功能更丰富但体积较大）

### 5.2 数据查询
所有查询在前端通过 Supabase Client 完成，无需新建 Edge Function。

```dart
// 周视图：最近 7 天每日完成数
final result = await supabase
    .from('daily_logs')
    .select('date_id, completed_count, is_perfect')
    .eq('user_id', userId)
    .gte('date_id', sevenDaysAgo)
    .order('date_id');

// XP 日累积：按天聚合
final xpData = await supabase
    .from('quest_nodes')
    .select('completed_at, xp_reward')
    .eq('user_id', userId)
    .eq('is_completed', true)
    .gte('completed_at', thirtyDaysAgo);

// 任务分类统计
final tierData = await supabase
    .from('quest_nodes')
    .select('quest_tier')
    .eq('user_id', userId)
    .eq('is_completed', true)
    .gte('completed_at', rangeStart);
```

### 5.3 前端架构
```
lib/features/stats/
├── controllers/
│   └── stats_controller.dart    # 数据加载 + 聚合计算
├── models/
│   └── stats_data.dart          # DailyStats, TierStats 等数据类
├── screens/
│   └── stats_page.dart          # 统计页面主体
└── widgets/
    ├── highlight_cards.dart      # 亮点卡片区
    ├── completion_chart.dart     # 完成趋势图
    ├── xp_curve_chart.dart       # XP 曲线图
    └── tier_pie_chart.dart       # 分类饼图
```

### 5.4 性能考虑
- 数据量不大（个人用户30天），前端聚合即可
- 页面进入时一次性加载所有数据，避免多次查询
- 使用 `ChangeNotifier` 管理加载状态

## 6. 依赖项
```yaml
# pubspec.yaml
fl_chart: ^0.70.0
```

## 7. 边界情况
- **无数据状态**：新用户显示空状态引导（"完成你的第一个任务吧！"）
- **时区处理**：统计按用户本地日期聚合，与 PRD-01 签到逻辑保持一致
- **大数据量**：最多查询 30 天数据，无性能风险

## 8. 验收标准
- [ ] 亮点卡片正确显示各项统计数据
- [ ] 周视图柱状图正确展示最近 7 天完成数
- [ ] 月视图折线图正确展示最近 30 天趋势
- [ ] XP 曲线正确展示累积增长
- [ ] 饼图正确展示任务分类占比
- [ ] 无数据时显示空状态引导
- [ ] 切换周/月视图响应流畅
