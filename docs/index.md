# 文档索引

> 最后更新：2026-04-22 | 维护者：Kiro

## 目录结构

```
docs/
├── index.md                    # 本文件，文档导航
├── project/                    # 项目级文档（角色定义、技术上下文、AI指令）
├── changelog/                  # 版本更新记录
├── prd/                        # 产品需求文档（PRD）
├── plans/                      # 功能实现计划
├── verification/               # 验证报告（数据库迁移、安装验证等）
├── superpowers/                # Superpowers 功能相关文档
│   ├── plans/                  # Superpowers 实现计划
│   └── specs/                  # Superpowers 设计规格
└── misc/                       # 其他文档（需求草稿、设计探索等）
```

---

## project/ — 项目级文档

| 文件 | 时间戳 | 说明 |
|------|--------|------|
| [2026-04-22-AGENTS.md](./project/2026-04-22-AGENTS.md) | 2026-04-22 | Codex AI 工作操作手册，定义职责与操作规范 |
| [2026-04-15-AI_CONTEXT.md](./project/2026-04-15-AI_CONTEXT.md) | 2026-04-15 | 项目交接文档，Flutter + Supabase 技术上下文 |
| [2026-02-25-CLAUDE.md](./project/2026-02-25-CLAUDE.md) | 2026-02-25 | Claude Code 工作指引，项目背景与 SOP |

---

## changelog/ — 版本更新记录

| 文件 | 说明 |
|------|------|
| [CHANGELOG.md](./changelog/CHANGELOG.md) | 完整版本历史（v1.0.0 至今） |

版本摘要：
- **v1.3.0** (2026-04-15) — 业务型 Agent、自由聊天、国际化补强
- **v1.2.0** (2026-03-27) — 签到系统、统计面板、补签能力
- 更早版本见 CHANGELOG.md

---

## prd/ — 产品需求文档

| 文件 | 说明 |
|------|------|
| [PRD-01-每日签到与连续打卡.md](./prd/PRD-01-每日签到与连续打卡.md) | 签到与连续打卡需求 |
| [PRD-03-数据统计面板.md](./prd/PRD-03-数据统计面板.md) | 数据统计面板需求 |
| [PRD-04-成就徽章系统.md](./prd/PRD-04-成就徽章系统.md) | 成就徽章系统需求 |
| [PRD-05-道具商城增强.md](./prd/PRD-05-道具商城增强.md) | 道具商城增强需求 |
| [PRD-07-微信周报推送.md](./prd/PRD-07-微信周报推送.md) | 微信周报推送需求 |
| [PRD-08-产品定位与体验对齐.md](./prd/PRD-08-产品定位与体验对齐.md) | 产品定位与体验对齐 |

---

## plans/ — 功能实现计划

| 文件 | 时间戳 | 说明 |
|------|--------|------|
| [2026-03-06-homepage-button-reorg.md](./plans/2026-03-06-homepage-button-reorg.md) | 2026-03-06 | 首页按钮重组 |
| [2026-02-25-chat-to-timeline.md](./plans/2026-02-25-chat-to-timeline.md) | 2026-02-25 | 聊天转时间线 |
| [2026-02-25-connect-real-backend.md](./plans/2026-02-25-connect-real-backend.md) | 2026-02-25 | 接入真实后端 |
| [2026-02-25-frontend-design-upgrade.md](./plans/2026-02-25-frontend-design-upgrade.md) | 2026-02-25 | 前端设计升级 |
| [2026-02-25-gamified-quest-log.md](./plans/2026-02-25-gamified-quest-log.md) | 2026-02-25 | 游戏化任务日志 |
| [2026-02-25-structure-refactor.md](./plans/2026-02-25-structure-refactor.md) | 2026-02-25 | 结构重构 |
| [2026-02-25-supabase-functions-migration.md](./plans/2026-02-25-supabase-functions-migration.md) | 2026-02-25 | Supabase Functions 迁移 |
| 其他 2026-02-25 计划... | 2026-02-25 | 见 plans/ 目录 |

---

## verification/ — 验证报告

| 文件 | 时间戳 | 说明 |
|------|--------|------|
| [2026-04-01-supabase-migration.md](./verification/2026-04-01-supabase-migration.md) | 2026-04-01 | Supabase 数据库迁移验证 |
| [2026-03-26-ecc-install.md](./verification/2026-03-26-ecc-install.md) | 2026-03-26 | ECC 安装验证报告 |

---

## superpowers/ — Superpowers 功能文档

### specs/
| 文件 | 时间戳 | 说明 |
|------|--------|------|
| [2026-04-02-evermemos-demo-design.md](./superpowers/specs/2026-04-02-evermemos-demo-design.md) | 2026-04-02 | EverMemos Demo 设计规格 |
| [2026-04-01-quick-create-modal-design.md](./superpowers/specs/2026-04-01-quick-create-modal-design.md) | 2026-04-01 | 快速创建弹窗设计规格 |
| [2026-03-25-earth-online-readme-design.md](./superpowers/specs/2026-03-25-earth-online-readme-design.md) | 2026-03-25 | Earth Online README 设计规格 |
| [2026-03-24-system-shop-design.md](./superpowers/specs/2026-03-24-system-shop-design.md) | 2026-03-24 | 系统商城设计规格 |

### plans/
| 文件 | 时间戳 | 说明 |
|------|--------|------|
| [2026-04-14-agent-phase-2.md](./superpowers/plans/2026-04-14-agent-phase-2.md) | 2026-04-14 | Agent 第二阶段计划 |
| [2026-04-14-earth-online-agent-refactor.md](./superpowers/plans/2026-04-14-earth-online-agent-refactor.md) | 2026-04-14 | Earth Online Agent 重构计划 |
| [2026-04-02-evermemos-demo-production.md](./superpowers/plans/2026-04-02-evermemos-demo-production.md) | 2026-04-02 | EverMemos Demo 生产计划 |
| [2026-04-01-quick-create-modal-redesign.md](./superpowers/plans/2026-04-01-quick-create-modal-redesign.md) | 2026-04-01 | 快速创建弹窗重设计计划 |
| [2026-03-25-earth-online-readme-refresh.md](./superpowers/plans/2026-03-25-earth-online-readme-refresh.md) | 2026-03-25 | Earth Online README 刷新计划 |
| [2026-03-24-system-shop.md](./superpowers/plans/2026-03-24-system-shop.md) | 2026-03-24 | 系统商城实现计划 |
| [2026-03-12-ui-ux-polish.md](./superpowers/plans/2026-03-12-ui-ux-polish.md) | 2026-03-12 | UI/UX 打磨计划 |

---

## misc/ — 其他文档

| 文件 | 时间戳 | 说明 |
|------|--------|------|
| [2026-02-25-flutter-ui-redesign.md](./misc/2026-02-25-flutter-ui-redesign.md) | 2026-02-25 | Flutter UI 美化与优化需求草稿 |
| [2026-04-15-agent-chat-fix-summary.md](./2026-04-15-agent-chat-fix-summary.md) | 2026-04-15 | Agent 聊天修复总结 |
| [competition-demo-assets.md](./competition-demo-assets.md) | — | 竞赛演示素材说明 |
