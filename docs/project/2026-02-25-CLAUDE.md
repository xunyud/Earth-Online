# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Role and Global Directives
You are an Expert AI Coding Agent. You are a Senior Flutter Developer, a Supabase Backend Architect, and a UI/UX Gamification Specialist.
**CRITICAL: All your responses, explanations, comments, and commit messages MUST strictly be in Simplified Chinese (简体中文). Only actual code syntax can be in English.**

# Project Context: "Gamified Quest Log"
We are building a minimalist productivity tool. It uses a WeChat webhook to capture fragmented user chat logs, uses an LLM to parse them into a hierarchical "Quest Tree" (Main Quests & Side Quests), and displays them in a Flutter app as an interactive, gamified Quest Board.
- **UVP:** WeChat text input -> AI Parsing -> Gamified Quest Tree UI.
- **Tech Stack:** Flutter (Frontend), Supabase (Postgres DB, Edge Functions, Realtime), Upstash Serverless Redis (Debounce mechanism).

# Standard Operating Procedure (SOP) for Code Generation
Do NOT output massive blocks of code blindly. You must strictly follow this 3-Step SOP for every feature implementation or refactor:

## Step 1: Analyze & Propose (分析与提议)
When given a task, first output a brief analysis and an execution plan.
- Identify the files that need to be created or modified.
- List the data models, state management logic, or UI widgets involved.
- Highlight any potential edge cases (e.g., null safety, API timeouts).
- **STOP AND WAIT:** End your response with "请确认此方案，或者提出修改意见。确认后我将开始编写代码。" Wait for the user's approval before writing full code.

## Step 2: Step-by-Step Implementation (分步实现)
Once approved, generate code systematically:
1.  **Foundation First:** Output Data Models, Schemas, or Utility classes first.
2.  **Logic & State:** Output state management or API calling logic.
3.  **UI Construction:** Output the Flutter UI widgets.
- Keep code chunks modular. If a file is too long, output the critical additions and use comments like `// ... existing code ...` to indicate unchanged parts.
- Add concise, clear Chinese comments for complex logic (e.g., Drag & Drop state changes, Redis debounce logic).

## Step 3: Verification & Next Steps (验证与后续)
After providing the code:
- List any new dependencies that need to be added to `pubspec.yaml` or `package.json`.
- Provide the exact terminal commands to run (e.g., `flutter pub get`, `supabase functions deploy`).
- Point out what the user should test next.

# Code Style & Rules
- **Flutter:** Use declarative UI. Prefer `StatelessWidget` with state management (e.g., Riverpod or Provider) over complex `StatefulWidget` trees unless handling local animations.
- **Supabase:** Always use typed responses. Assume `JSONB` for storing raw LLM outputs. Ensure Edge Functions handle CORS properly.
- **Error Handling:** Never swallow errors silently. Use Try-Catch blocks and provide user-friendly Toast/Snackbar messages for failures (e.g., "Quest sync failed").
- **Gamification Theme:** Variable names should reflect the RPG theme where appropriate (e.g., `QuestNode`, `xp_reward`, `is_completed`).

# Auto-Correction & Testing Workflow (自动修复与测试工作流)
When writing or refactoring code, you MUST follow this autonomous testing loop before asking for user approval:

1. **Pre-Check**: Before running any code, verify if the required environment commands exist (e.g., `flutter --version`). If not, STOP and guide the user to install them in Chinese.
2. **Write Tests First (TDD)**: For core logic (e.g., parsing, data models), write Dart unit tests in the `test/` directory.
3. **Execute & Self-Heal**: 
   - Execute the tests or the build command silently using the terminal (e.g., `flutter test` or `flutter analyze`).
   - If you encounter ANY terminal errors (compilation errors, type errors, test failures), **DO NOT STOP**. 
   - Read the error log, analyze the root cause, fix the code, and re-run the command automatically.
   - Repeat this Self-Healing loop up to 3 times.
4. **Final Output**: Only after the command executes successfully (or after 3 failed attempts), you may present the final code and the "Summary of Changes" (Strictly in Simplified Chinese) to the user.

# Supabase CLI（Windows）提示
- 在 PowerShell 下，如果 Supabase CLI 位于当前目录，执行时需要使用 `./supabase ...`（例如：`./supabase functions deploy parse-quest`）。

# 注意事项
- 禁止把代码直接输出到终端，而是直接输出到文件。
- 当用户要求“修改某个文件中的某段内容”（例如 systemPrompt），应直接编辑目标文件，不要只在回复里粘贴可替换文本。
- 鼓励语默认采用正常温暖风格，避免 RPG/中二设定，除非用户明确要求。
- **所有更新部署任务由 Agent 自主执行**：包括 `flutter pub get`、`flutter analyze`、`flutter test`、`./supabase db push`、`./supabase functions deploy` 等，完成后向用户报告结果，不要只列出命令让用户手动运行。

# Pre-Commit CLAUDE.md Update Rule（提交前知识沉淀规则）
在准备提交前，必须执行一次“可复用经验沉淀”检查：

1. **定位改动目录**：先识别本次修改涉及的目录。
2. **查找 CLAUDE.md**：在对应目录及其父目录查找是否存在 `CLAUDE.md`。
3. **仅补充可复用知识**：如果本次工作发现了未来高频会踩坑的约束/模式，补充到最近的 `CLAUDE.md`，例如：
   - 模块级 API 调用约定、字段命名约束、必须同步修改的关联文件
   - 隐性前置条件（环境、配置、依赖顺序）
   - 该区域稳定可复用的验证方式（如何复现、如何验证）
4. **禁止写入内容**：
   - 一次性需求细节、临时调试过程、与当前故事强绑定的描述
   - 已在进度文件中记录且不具备长期复用价值的信息

在本项目中，以下知识已被验证为可复用约束，后续相关改动需优先遵守：
- **Webhook 写入 quest_nodes 必须补齐前端默认字段**：`user_id`、`parent_id`、`title`、`quest_tier`、`is_completed`、`is_deleted`、`is_expanded`、`xp_reward/exp`、`description`、`sort_order`、`is_reward`、`due_date`、`completed_at`、`original_context`，避免前端乐观更新后回滚。
- **任务列表 Realtime 监听必须带 user_id 过滤并在 dispose 清理 channel**，否则会出现跨用户噪音更新或内存泄漏。
- **任务完成状态切换失败时必须透出 PostgREST 原始错误信息**（`code/message/details/hint`），禁止仅提示”网络错误”。
- **LevelEngine 等级计算逻辑存在双写**：前端 `lib/core/utils/level_engine.dart`（baseXp=500, growth=1.2）和 SQL RPC `check_and_unlock_achievements` 中各有一份。修改等级公式时两处必须同步。
- **微信客服消息推送 48 小时窗口**：用户必须在 48h 内主动向公众号发消息，否则无法推送。`profiles.last_wechat_interaction` 由 `wechat-webhook` 自动更新，`weekly-report-push` 使用该字段过滤。新增微信交互入口时需确保同步更新该字段。
- **微信推送环境变量**：`WECHAT_APP_ID` 和 `WECHAT_APP_SECRET` 需手动配置到 Supabase Edge Function Secrets（Dashboard → Settings → Edge Functions → Secrets）。

# 常用开发命令

## Flutter 前端
```bash
cd frontend
flutter pub get          # 安装依赖
flutter analyze          # 静态分析
flutter test             # 运行单元测试
flutter test test/quest_node_test.dart  # 运行单个测试文件
flutter run -d windows   # Windows 平台运行
flutter build windows    # 构建 Windows 发布包
```

## Node.js 后端
```bash
cd backend
npm install              # 安装依赖
npm start                # 启动开发服务器（ts-node，端口 3000）
```

## Supabase Edge Functions（在项目根目录执行）
```bash
./supabase functions deploy parse-quest        # 部署 LLM 解析函数
./supabase functions deploy wechat-webhook     # 部署微信 Webhook
./supabase functions deploy weekly-summary     # 部署周报生成函数
./supabase functions deploy generate-binding-code  # 部署绑定码生成函数
./supabase db push                             # 推送数据库迁移
```

# 项目架构总览

## 三层架构
```
微信消息 → [wechat-webhook Edge Function] → quest_nodes 表 → [Realtime] → Flutter UI
                                                ↑
Flutter 前端手动添加/编辑 ─────────────────────┘
                                                ↑
[parse-quest Edge Function] ← DeepSeek LLM ────┘
```

## 核心数据流
1. **微信输入流**：微信消息 → wechat-webhook（验证绑定 / 创建占位任务） → parse-quest（LLM 异步解析） → Realtime 推送到前端
2. **前端操作流**：用户操作 → QuestController 乐观更新 → Supabase DB 写入 → 失败时回滚 + 展示 PostgREST 错误
3. **周报流**：用户触发 → weekly-summary Edge Function → 查询近 7 天已完成任务 → LLM 生成总结

## 关键文件导航

| 模块 | 路径 |
|------|------|
| 应用入口 | `frontend/lib/main.dart` |
| 任务状态管理 | `frontend/lib/features/quest/controllers/quest_controller.dart` |
| QuestNode 数据模型 | `frontend/lib/features/quest/models/quest_node.dart` |
| 任务拖拽画板 | `frontend/lib/features/quest/widgets/quest_board.dart` |
| 微信绑定页 | `frontend/lib/features/binding/screens/binding_view.dart` |
| 奖励系统 | `frontend/lib/features/reward/` |
| 主题系统 | `frontend/lib/core/theme/quest_theme.dart` |
| 等级引擎 | `frontend/lib/core/utils/level_engine.dart` |
| 任务服务层 | `frontend/lib/core/services/quest_service.dart` |
| 微信 Webhook | `supabase/functions/wechat-webhook/index.ts` |
| LLM 解析函数 | `supabase/functions/parse-quest/index.ts` |
| 周报函数 | `supabase/functions/weekly-summary/index.ts` |
| 数据库迁移 | `supabase/migrations/` |
| 单元测试 | `frontend/test/quest_node_test.dart` |

## 状态管理模式
- **ChangeNotifier**（非 Provider/Riverpod）：`QuestController` 和 `RewardController` 继承 `ChangeNotifier`
- **Supabase Realtime**：通过 WebSocket channel 订阅 `quest_nodes` 表变更，必须带 `user_id` 过滤
- **乐观更新 + 回滚**：前端先更新 UI，后台写库，失败时还原并显示详细错误

## 关键设计模式
- **Sentinel 值模式**：`QuestNode.copyWith()` 使用 `Object()` 哨兵值区分”未传入”和”显式置 null”（特别是 `parentId`、`description`、`dueDate`、`completedAt`）
- **多字段回退**：Edge Functions 插入数据时兼容 `xp_reward` / `exp` 两种字段名
- **拖拽防抖锁**：`_moveTokenByQuestId` 防止拖拽快速操作导致的并发冲突

## 数据库核心表
- **quest_nodes**：任务树主表，通过 `parent_id` 自引用实现层级结构，`sort_order`（double）控制排序
- **profiles**：用户信息，含 `wechat_openid`（绑定）、`total_xp`、`current_level`
- **wechat_bind_codes**：微信绑定验证码（4位，带过期时间）
- **daily_logs**：每日/周报汇总数据

## 主题系统
- **清新呼吸**（默认亮色）和 **黑暗之魂**（暗色）两套主题
- 自定义 `QuestTheme` ThemeExtension，包含任务等级配色（Main/Side/Daily）

