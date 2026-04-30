# 项目交接文档（Flutter + Supabase）

## 1) 项目概述与技术栈
- **项目目标**：构建「地球Online」风格任务系统，支持任务树、回收站、微信输入任务、AI 解析与周报生成。
- **前端**：Flutter（`ChangeNotifier + AnimatedBuilder`），核心状态在 `QuestController`。
- **后端**：Supabase（Postgres + Realtime + Edge Functions）。
- **AI**：DeepSeek/OpenAI 兼容接口（当前函数优先 DeepSeek endpoint）。
- **关键集成链路**：微信消息 → `wechat-webhook` → `quest_nodes` 占位任务 → 异步 AI 解析回写 → App Realtime 自动刷新。

---

## 2) 核心业务逻辑

### 2.1 任务系统（Quest Tree）
- 无限层级拖拽（2D）：`quest_board.dart` + `QuestController.moveQuestByDrop`。
- 顶部根锚点“地球Online”：保证任务可稳定降级为 root（`parent_id = null`）。
- 回收站软删除：`is_deleted` 控制显示；支持删除、恢复、彻底删除与批量操作。
- 乐观更新：本地先改 UI，再写库；失败回滚并提示。

### 2.2 Realtime 刷新策略
- `QuestController` 已使用 `supabase.channel` 监听 `quest_nodes` 的 INSERT/UPDATE/DELETE。
- 监听已按 `user_id` 过滤，仅接收当前用户数据。
- `dispose` 中会 `removeChannel`，避免重复订阅与泄漏。

### 2.3 微信绑定与任务写入
- 绑定页：生成 4 位验证码写入 `wechat_bind_codes`，监听 `profiles.wechat_openid` 实时变更。
- 支持解绑：`profiles.wechat_openid -> null`，并切回未绑定 UI。
- `wechat-webhook`：
  - 已绑定用户发文本可直接入任务。
  - 4 位数字在已绑定状态下提示“已绑定”；未绑定状态走验证码绑定。
  - 为避免微信超时，AI 解析采用非阻塞后台执行（`waitUntil`/Promise）。

### 2.4 人生日记与周报
- 人生日记页：`life_diary_page.dart`。
- 已新增入口按钮（右上角）：**📜 召唤村长周报**。
- 点击后调用 `weekly-summary`，展示加载态、成功/失败提示，并自动刷新列表。

---

## 3) 数据库结构现状（Supabase）

### 3.1 关键表
- `quest_nodes`
  - 关键字段：`id,user_id,parent_id,title,quest_tier,is_completed,is_expanded,is_deleted,xp_reward,created_at`
  - 实际联调中存在字段差异兼容：`exp`/`xp_reward`、`sort_order`、`description`、`due_date`、`completed_at`、`is_reward`、`original_context`、`node_type`。
- `profiles`
  - 关键字段：`id,wechat_openid`（及绑定相关字段）。
- `wechat_bind_codes`
  - 关键字段：`code,user_id,expires_at`。
- `daily_logs`
  - 当前用于人生日记与周报落库，线上字段可能与迁移不完全一致，代码已做多字段回退读取/写入兼容。

### 3.2 当前稳定约束
- Webhook 写 `quest_nodes` 必须补齐默认字段，避免前端编辑/勾选失败。
- 任务更新失败必须透出 PostgREST `code/message/details/hint`，不能只显示“网络错误”。

---

## 4) 当前已解决的关键 Bug
- **拖拽深度失控导致 Drop 失败**：深度已限制为 `previous.depth + 1`。
- **首子节点插入失败**：`newParentId` 推导重写，按 `entriesSans + previous + targetDepth` 计算。
- **软删除不持久化**：改为 `is_deleted` 软删并统一过滤。
- **`copyWith` 无法置空 parentId**：已引入 sentinel 支持显式 `null`。
- **微信任务显示后无法勾选完成（乐观更新回退）**：
  - Webhook 载荷补齐默认字段；
  - 前端完成切换异常捕获增强，返回具体数据库错误。
- **任务列表不自动刷新**：已接入用户级 Realtime 订阅并清理 channel。
- **weekly-summary 错误不可读（`[object Object]`）**：
  - 已统一错误序列化；
  - 缺失环境变量会抛出明确中文错误；
  - 500 响应返回 `{ success:false, error }`。

---

## 5) 接下来的待办事项
- **高优先级**：统一 Supabase 实际 schema 与代码中的兼容分支（`xp_reward/exp`、`sort_order`、`daily_logs` 字段），减少回退逻辑复杂度。
- **高优先级**：批量更新/删除接口补齐 `user_id` 约束并核对 RLS 策略，避免多用户越权风险。
- **中优先级**：如需任务顺序跨重启稳定，完善拖拽后的顺序字段持久化策略。
- **当前状态**：主链路已可用，等待用户下达新指令。
