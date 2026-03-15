# PRD 文档总览

## 实现优先级排序

| 优先级 | PRD | 功能 | 体量 | 前置依赖 |
|--------|-----|------|------|---------|
| P0 | PRD-01 | 每日签到与连续打卡 | 中 | 需补齐 daily_logs 迁移 |
| P1 | PRD-05 | 道具商城增强 | 中 | 需补齐 rewards/inventory 迁移、RPC |
| P2 | PRD-03 | 数据统计面板 | 中 | 依赖 PRD-01 的 streak 数据 |
| P3 | PRD-04 | 成就徽章系统 | 大 | 依赖 PRD-01 签到 + PRD-05 金币 |
| P4 | PRD-07 | 微信周报推送 | 中 | 需微信客服消息权限 |

## 推荐实现顺序说明

1. **PRD-01 签到系统** — 基础设施：补齐 daily_logs 表、profiles 新字段、签到 RPC，后续多个功能依赖
2. **PRD-05 商城增强** — 补齐 gold/rewards/inventory 的数据库基础设施（当前代码调用的 RPC 实际缺失），同时完善金币闭环
3. **PRD-03 统计面板** — 纯前端展示层，依赖前两个 PRD 提供的数据
4. **PRD-04 成就系统** — 需要签到、XP、金币系统全部就绪后实现
5. **PRD-07 微信推送** — 独立功能，但需微信平台权限配置，放在最后

## 共享基础设施（需优先处理）

以下缺失项被多个 PRD 共同依赖，应在 PRD-01 中一并补齐：

- [ ] `daily_logs` 表迁移文件
- [ ] `profiles.gold` 字段
- [ ] `increment_custom_stats` RPC 实现
- [ ] `rewards` / `inventory` 表迁移文件
- [ ] `buy_reward` RPC 实现
- [ ] 各表 RLS 策略
