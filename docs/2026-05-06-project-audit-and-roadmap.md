# 项目审计与开发路线图

> 审计日期：2026-05-06
> 审计范围：代码质量、测试覆盖、技术债务、安全性、依赖健康

---

## 一、项目现状总览

| 维度 | 状态 | 评分 |
|------|------|------|
| 架构设计 | Feature-first，模块清晰 | ⭐⭐⭐⭐ |
| 代码质量 | 无 TODO/FIXME，命名规范 | ⭐⭐⭐⭐ |
| 测试覆盖 | 核心模块缺口大（Widget 仅 27%） | ⭐⭐ |
| 技术债务 | home_page.dart 7159 行、Edge Functions 重复代码 | ⭐⭐ |
| 安全性 | Supabase anon key 硬编码 | ⭐⭐ |
| 依赖健康 | flutter_lints 已废弃、多个 0.x 依赖 | ⭐⭐⭐ |

---

## 二、测试覆盖分析

### 2.1 测试文件统计

| 层级 | 测试文件数 | 说明 |
|------|-----------|------|
| Frontend 单元/Widget 测试 | 71 | `frontend/test/` |
| Supabase 集中测试 | 32 | `supabase/functions/tests/` |
| Supabase 共位测试 | 16 | 各函数目录下 `*_test.ts` |
| **合计** | **119** | |

### 2.2 前端测试缺口

**无测试的核心模块：**

| 模块 | 文件 | 风险 |
|------|------|------|
| 等级引擎 | `core/utils/level_engine.dart` | 双写风险（前端 + SQL RPC） |
| 成就控制器 | `achievement/controllers/achievement_controller.dart` | 游戏化核心 |
| 记忆服务 | `core/services/memory_service.dart` | 核心服务 |
| 国际化控制器 | `core/i18n/app_locale_controller.dart` | 全局影响 |
| 首页 | `quest/screens/home_page.dart` | 最大文件，0 测试 |

**Widget 测试覆盖率：** 约 27%（10/37）

### 2.3 Edge Functions 测试缺口

**无测试的高优先级函数：**

| 函数 | 说明 |
|------|------|
| `wechat-webhook/index.ts` | 微信入口，外部调用 |
| `guide-chat/index.ts` | AI 对话核心 |
| `weekly-report-push/index.ts` | 周报推送 |
| `sync-user-memory/index.ts` | 记忆同步 |

---

## 三、技术债务清单

### 3.1 P0 — 紧急

#### 3.1.1 home_page.dart 7159 行

项目最大文件，混合了 AI 对话、任务管理、导航、Agent 运行时等 6+ 种职责。任何功能改动都需要触碰此文件，合并冲突风险极高。

#### 3.1.2 Supabase anon key 硬编码

`frontend/lib/main.dart` 第 26-27 行直接硬编码了 Supabase URL 和 anon key：

```dart
url: 'https://ndbhxjvrgxeuyykrlyxl.supabase.co',
anonKey: 'sb_publishable_oqeYb0IhGpRlPmYCWqLomQ_Jr4yrwT9',
```

### 3.2 P1 — 高

#### 3.2.1 Edge Functions 重复代码

| 重复项 | 出现次数 |
|--------|----------|
| `toText()` | 14 处 |
| `corsHeaders` | 6 处 |
| `toRecord()` | 8 处 |
| `json()` 响应构造 | 12+ 处 |
| `toBool()` | 2 处 |

修改一处逻辑需要同步 14 处，极易遗漏。

#### 3.2.2 Deno import 风格混用

- 旧式 `serve`：`generate-binding-code`, `process-tasks`, `webhook`, `wechat-webhook`
- 新式 `Deno.serve`：其余函数

### 3.3 P2 — 中

#### 3.3.1 超过 500 行的 Dart 文件（14 个）

| 文件 | 行数 |
|------|------|
| `quest/screens/home_page.dart` | 7159 |
| `quest/controllers/quest_controller.dart` | 2117 |
| `memory/screens/memory_page.dart` | 1662 |
| `binding/screens/binding_view.dart` | 1433 |
| `core/i18n/app_locale_controller.dart` | 1349 |
| `auth/screens/login_screen.dart` | 1291 |
| `quest/widgets/guide_panel_dialog.dart` | 982 |
| `core/services/evermemos_service.dart` | 940 |
| `reward/screens/reward_shop_page.dart` | 885 |
| `core/widgets/app_drawer.dart` | 793 |
| `core/services/guide_service.dart` | 775 |
| `auth/widgets/forest_atmosphere.dart` | 657 |
| `quest/widgets/quest_board.dart` | 593 |
| `quest/screens/life_diary_page.dart` | 565 |

#### 3.3.2 依赖版本问题

| 依赖 | 当前版本 | 问题 |
|------|----------|------|
| `flutter_lints` | `^2.0.0` | 已废弃，应迁移到 `very_good_analysis` |
| `supabase_flutter` | `^2.0.0` | 主版本范围过宽 |
| `webview_windows` | `^0.4.0` | 0.x 预发布版本 |
| `deno.land/std` | `0.168.0` | 已停更，应迁移到 JSR `@std/` |

### 3.4 P3 — 低

#### 3.4.1 硬编码配置值

- `app_config.dart` 第 36 行：`agentChatProxyUrl` 默认值指向 `localhost`
- `app_config.dart` 第 11 行：`evermemosBaseUrl` 硬编码
- `app_config.dart` 第 26 行：`openaiBaseUrl` 硬编码
- `home_page.dart` 第 904-927 行：UI 层直接调用 OpenAI API

#### 3.4.2 散落的魔法数字

- `app_drawer.dart` 第 90 行：`width: 300`
- `quest_board.dart` 第 41-43 行：`indentStep: 32.0`, `gutterWidth: 28.0`, `itemGap: 10.0`
- 多处动画 Duration 使用内联数字

---

## 四、开发路线图

### 阶段 1：home_page.dart 拆分（第 1 周）

**目标：** 将 7159 行拆分为 5-6 个职责单一的模块

**拆分方案：**

```
home_page.dart (7159行)
├── home_scaffold.dart          — 骨架 + 导航 + 抽屉
├── home_ai_chat.dart           — AI 对话逻辑 + 消息列表
├── home_agent_runtime.dart     — Agent 执行时序 + 审批
├── home_daily_event.dart       — 每日事件处理
├── home_quest_actions.dart     — 任务操作（创建/完成/编辑）
└── home_coach_marks.dart       — 新手引导覆盖层
```

**验收标准：**
- 每个子文件 < 1500 行
- 所有现有功能正常运行
- 无新增 lint warning

### 阶段 2：Edge Functions 公共层提取（第 2 周）

**目标：** 消除 14+ 处重复代码

**步骤：**

1. 创建 `_shared/http_helpers.ts`，统一导出：
   - `corsHeaders`
   - `toText(value: unknown): string`
   - `toRecord(value: unknown): Record<string, unknown>`
   - `toBool(value: unknown): boolean`
   - `json(status: number, data: unknown): Response`

2. 逐个函数替换（每个独立部署验证）：
   - 第一批：`parse-quest`, `wechat-webhook`（最活跃）
   - 第二批：`guide-*` 系列
   - 第三批：`agent-*` 系列

3. 统一 import 风格为 `Deno.serve`

**验收标准：**
- 所有函数从 `_shared/http_helpers.ts` 导入
- 无内联重复定义
- 全部函数部署成功

### 阶段 3：核心测试补全（第 3 周）

**目标：** 覆盖高风险模块

**优先级：**

| 优先级 | 模块 | 原因 |
|--------|------|------|
| 1 | `level_engine.dart` | 纯逻辑，易测，有双写风险 |
| 2 | `achievement_controller.dart` | 游戏化核心体验 |
| 3 | `wechat-webhook` | 外部入口，错误影响面大 |
| 4 | `guide-chat` | AI 对话核心 |

**依赖升级：**
- 添加 `mocktail` 作为 mock 框架
- 添加 `flutter_coverage` 生成覆盖率报告

### 阶段 4：安全性与依赖升级（第 4 周）

**安全性修复：**
- Supabase 配置改为 `String.fromEnvironment` 注入
- OpenAI 调用迁移到 Edge Function
- `app_config.dart` 默认值改为生产地址或空值

**依赖升级：**
- `flutter_lints` → `very_good_analysis`
- `deno.land/std` → JSR `@std/`
- 锁定 `supabase_flutter` 次版本范围

---

## 五、附录

### A. 项目架构概览

```
微信消息 → [wechat-webhook] → quest_nodes 表 → [Realtime] → Flutter UI
                                    ↑
Flutter 前端手动添加/编辑 ──────────┘
                                    ↑
[parse-quest] ← DeepSeek LLM ──────┘
```

### B. 核心模块导航

| 模块 | 路径 | 行数 |
|------|------|------|
| 应用入口 | `frontend/lib/main.dart` | ~250 |
| 任务控制器 | `frontend/lib/features/quest/controllers/quest_controller.dart` | 2117 |
| QuestNode 模型 | `frontend/lib/features/quest/models/quest_node.dart` | ~300 |
| 任务看板 | `frontend/lib/features/quest/widgets/quest_board.dart` | 593 |
| 等级引擎 | `frontend/lib/core/utils/level_engine.dart` | ~100 |
| 微信 Webhook | `supabase/functions/wechat-webhook/index.ts` | ~600 |
| LLM 解析 | `supabase/functions/parse-quest/index.ts` | ~400 |

### C. 开发命令速查

```bash
# Flutter
cd frontend && flutter pub get && flutter analyze && flutter test

# Supabase（项目根目录）
./supabase functions deploy parse-quest
./supabase functions deploy wechat-webhook
./supabase db push
```
