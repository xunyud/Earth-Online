# Changelog

- 最后更新：2026-04-27
- 维护者：Kiro

## v1.6.0 - 2026-04-27

### 记忆系统演进 3.1–3.4（Memory System Evolution）

#### 3.1 记忆衰减与知识提取
- `guide_memory.ts`：新增 `computeDecayWeight`（Ebbinghaus 四段衰减）和 `applyDecayWeights`（加权排序 + 中期记忆兜底），集成到 `gatherGuideMemoryBundle` 流程
- `evermemos_client.ts`：`EverMemOSClient` 新增 `flushMemories(userId)` 方法，调用 EverMemOS Flush API 触发知识提取
- 新增 `knowledge-extraction` Edge Function：支持批量/单用户模式，pg_cron 每周触发，错误隔离

#### 3.2 画像 Epoch 与自动生成
- 数据库迁移：`guide_portraits` 表新增 `epoch` 字段（ISO 周标识），唯一索引 `(user_id, epoch)`
- `guide-portrait-generate/helpers.ts`：新增 `currentIsoWeek` ISO 8601 周计算函数
- `guide-portrait-generate/index.ts`：支持 epoch 填充、upsert 覆盖、上一张画像 summary 注入、batch_mode 批量生成
- `memory_page.dart`：新增画像时间线 PageView 轮播，0/1 张时显示引导文案

#### 3.3 记忆驱动任务推荐
- 新增 `memory-recommender` Edge Function：从 EverMemOS 检索行为模式 → DeepSeek LLM 生成 2–3 条推荐
- `guide_engine.ts`：`buildGuideBootstrapPayload` 集成推荐（8s 超时，失败不阻塞）
- `guide_service.dart`：新增 `MemoryRecommendation` 模型，`GuideBootstrapResult` 扩展 `recommendations` 字段
- `home_page.dart`：新增"小忆建议"卡片区域，点击预填任务创建

#### 3.4 匿名群体记忆
- 新增 `collective_memory.ts`：匿名写入/检索 Collective Space（group_id: earth-online-collective）
- 新增 `milestone_detector.ts`：检测 streak_7day / first_clear / recovery_from_break 三种里程碑
- `sync-user-memory/index.ts`：任务完成后检测里程碑并匿名写入 Collective Space
- `memory-patrol/index.ts`：断签信号时注入"其他冒险者的经验"群体智慧

#### 属性测试覆盖
- 19 个正确性属性（Property 1–19），使用 fast-check / glados 验证，共 103 个后端测试全部通过

---

## v1.5.1 - 2026-04-24

### 记忆上传修复 & API Key 隔离
- `evermemos_client.ts`：`createMemoryFromMessages` 的 messages 数组每条补充 `timestamp: Date.now()`，修复 EverMemOS v1 要求的 int64 时间戳缺失问题。
- `evermemos_service.dart`：前端记忆上传 payload 补充 `timestamp` 字段。
- `guide-portrait-generate`：图像生成使用独立的 `OPENAI_IMAGE_API_KEY` + `OPENAI_IMAGE_BASE_URL`，与对话 key 隔离。
- `supabase/.env.local`：`OPENAI_API_KEY` 恢复为对话专用 key，新增 `OPENAI_IMAGE_API_KEY` 和 `OPENAI_IMAGE_BASE_URL`。

### 项目分析文档
- 新增 `docs/project/2026-04-24-earth-online-analysis.md`：项目深度分析与发展规划（五千字+），涵盖项目本质理解、记忆系统现状、记忆扩展方向、功能发展路线、技术架构演进、前景判断。

---

## v1.5.0 - 2026-04-22

### 独立记忆面板
- 新增 `frontend/lib/features/memory/screens/memory_page.dart`：独立记忆面板页面，展示用户在 EverMemOS 中积累的记忆片段，支持关键词搜索。
- 新增 `frontend/lib/core/services/memory_service.dart`：直接调用 EverMemOS v1 REST API，提供 `loadRecent`（加载最近30条）和 `search`（关键词检索）两个方法，自动解析 smart-p-memory 信封格式。
- 记忆卡片按类型分类展示（任务事件/对话记录/用户画像/Agent目标/Agent工具/Agent完成/主动提醒），点击展开查看完整内容和来源任务。
- `app_drawer.dart`：在日记菜单项后新增"我的记忆"入口（`Icons.memory_rounded`）。
- `app_locale_controller.dart`：补充 `memory.*` 系列 i18n 文案（中英双语）。

---

## v1.4.1 - 2026-04-22

### 代码 Agent 接入 EverMemOS 记忆
- `agent_engine.ts`：新增 `syncAgentEventToMemory` 工具函数，fire-and-forget 写入 EverMemOS，失败只打 warn 不阻塞主流程。
- `agent-turn/index.ts`：run 创建后写入 `agent_goal` 类型记忆，记录用户目标。
- `agent-step-complete/index.ts`：工具执行成功后写入 `agent_tool_result` 记忆；run 进入终态时写入 `agent_run_complete` 记忆。
- 三个事件类型（`agent_goal` / `agent_tool_result` / `agent_run_complete`）均以 `task_event` memoryKind 写入用户的 personal scope，供后续 agentic search 检索。

### 项目规范
- 新增 `.kiro/steering/project-update-convention.md`：每次项目更新必须同步写入 CHANGELOG 和 EverMemOS 记忆，规范已自动注入 AI agent 上下文。

---

## v1.4.0 - 2026-04-22

### 记忆系统全面升级（EverOS v1）

#### 方向1：记忆驱动 Agent 规划
- `guide_memory.ts`：`scene=agent` 时额外调用 EverMemOS `agenticSearch`，把语义推理后的历史片段注入 `recentContext`，新增 `agentic_memory_lines` 字段到 `GuideMemoryBundle`。
- `agent_engine.ts`：`buildAgentPlanningContext` 透传 `agentic_memory_lines`。
- `agent_planner.ts`：`planAgentGoal` 从 `clientContext._agentic_memory_lines` 读取历史，注入 freeform 路径的 `memory_context` 参数，让 `app.chat.freeform.respond` 能感知用户历史。
- `agent-turn/index.ts`：把 `planningContext.agentic_memory_lines` 注入 `clientContext` 再传给 `planGoal`。

#### 方向2：记忆可见性（前端）
- `guide_panel_dialog.dart`：`GuideDialogMessage` 新增 `memoryRefs: List<String>` 字段；气泡底部记忆标签改为可点击展开的片段列表，按来源类型显示（🎯 智能关联、📅 近期记忆、🗂 长期回调、🔗 跨任务关联等）。
- `home_page.dart`：`_GuideChatMessage` 新增 `memoryRefs` 字段，`_appendGuideMessage` 和 `setModalState` 均传入实际 refs 列表，`GuideDialogMessage` 构建时同步传入。

#### 方向3：主动推送（memory-patrol）
- 新增 `supabase/functions/memory-patrol/index.ts`：检测断签（streak ≥ 3 但今天未打卡）、任务搁置（有活跃任务但今日完成数为 0）、长时间沉默三种模式，写入 `guide_dialog_logs` 并通过微信客服消息 API 推送，同时把推送事件写回 EverMemOS 形成闭环。
- 支持单用户手动触发（传 `user_id`）和批量定时巡逻（查询最近 7 天活跃用户）。

#### 方向4：跨任务记忆关联
- `guide_memory.ts`：当用户有近期完成任务或活跃任务时，额外做一次 `semantic_memory` + `episodic_memory` 混合检索，把跨任务历史关联注入 `longTermCallbacks`，ref 前缀标记为 `mem_cross`。

#### EverMemOS 客户端升级（evermemos_client.ts）
- `EverMemSearchInput` 新增 `groupId`、`agentId`、`retrieveMethod: "agentic"` 支持。
- 新增 `agenticSearch` 方法：`POST /memories/search/` with `search_type: agentic`。
- 新增 `createSender` / `getSender` / `updateSender` 三个 sender 身份追踪方法，对应 EverOS v1 `/senders/` 端点。
- `getOptionalAuthHeaders` 优先读取 `EVERMEMOS_API_KEY`，兼容旧的 `EVERMEMOS_AUTH_TOKEN`。

#### 环境变量
- `supabase/.env.local`：`EVERMEMOS_API_URL` 升级至 `https://api.evermind.ai/api/v1/memories`，`EVERMEMOS_API_KEY` 更新为新 key。

---

## v1.3.0 - 2026-04-15

### 业务型 Agent 与自由聊天
- 新增 `agent-turn`、`agent-run-status`、`agent-step-approve`、`agent-step-complete` 四条 Supabase Functions，支持把一次用户目标拆成可追踪、可确认、可续跑的 agent 执行链路。
- 新增 `agent_runs`、`agent_run_steps`、`agent_step_approvals` 三张表，以及对应索引、约束和 RLS 策略，用于持久化 agent run、步骤状态与审批记录。
- 前端新增 `LocalAgentRuntimeService` 与 `AgentRunService`，把 `app.chat.freeform.respond`、`app.quest.create`、`app.quest.update`、`app.quest.split`、`app.weekly_summary.generate`、`app.reward.redeem`、`app.navigation.open` 等业务动作收束到统一运行时。
- 首页 Guide 对话框新增 agent 执行轨迹、步骤审批卡片与本地步骤执行结果上报，自由聊天不再只是旧的单点调用路径。
- `backend/` 新增 `POST /agent/free-chat` 代理接口，后端 `llm.ts` 补充 OpenAI 兼容 base URL 归一化逻辑，修复 `https://api.86gamestore.com` 这类地址自动补 `/v1` 的问题。

### 国际化与前端体验
- `frontend/lib/core/i18n/app_locale_controller.dart` 补充大批中英文文案，包括夜间反思、回收站、周报报错、快速创建任务、成长仪表盘、任务编辑、任务板暖心文案等。
- Guide 对话、成长画像、统计页与任务板更多内容已根据当前语言环境输出，英文模式下的文本一致性明显提升。
- 奖励、任务、统计与周报相关模型和页面同步补齐国际化与展示细节，降低中英混杂与空文案风险。

### 测试补强
- 新增或更新前端测试：`agent_models_test.dart`、`agent_run_service_test.dart`、`agent_service_test.dart`、`local_agent_runtime_service_test.dart`，以及多组语言与文案来源测试。
- 新增或更新 Deno 测试：`agent_engine_test.ts`、`agent_planner_test.ts`、`agent_policy_test.ts`、`agent-turn/index_test.ts`、`agent-step-approve/index_test.ts`、`agent-step-complete/index_test.ts`、`guide_ai_test.ts`、`guide_ai_language_test.ts`。

### 文档与演示素材
- `README.md` 更新 OpenAI 兼容环境变量说明，并新增项目级 Codex 多代理角色配置说明。
- 新增 `docs/2026-04-15-agent-chat-fix-summary.md`，记录本轮 agent 聊天修复的背景、根因、方案与验证结果。
- `promo-video/` 新增 `EarthOnlineCompetition`、`EarthOnlineCompetitionZh`、`EverMemOSDemo` 等 Remotion 合成，以及对应音频、视频片段和旁白脚本资源。

## v1.2.0 - 2026-03-27

### 新用户注册与新手引导修复
- 修复邮箱注册 OTP 类型不匹配导致的新用户注册失败问题。
- 修复新手引导在数据尚未加载完成时提前执行的竞态问题。
- Coach Marks 改为全屏遮罩并支持点击穿透，目标缺失时可自动跳步，减少引导卡死。
- 侧边栏新增“使用说明”入口，允许用户随时重播功能引导。

### 助手与统计体验优化
- 聊天输入框支持 `Enter` 发送、`Shift+Enter` 换行。
- 修复无记忆用户仍显示“参考了 X 段近期记忆”的错误提示。
- 首页顶部等级 / XP / 金币 / 经验条区域支持点击跳转到统计页。

### 测试维护
- 更新 4 个过期测试文件以匹配当时的登录页、助手面板与国际化源码结构。

## v1.1.0 - 2026-03-26

### 成长仪表盘与签到系统
- 重构统计页为成长仪表盘，加入暖奶油色 / 柔绿 / 低饱和金配色、XP 卡片、图表组件和里程碑模块。
- 接入 `checkin_and_get_multiplier` RPC，实现首次完成任务自动签到与连续天数展示。
- 新增补签能力与 30 天签到日历，支持扣除金币后补签并重算 streak。

### 界面与交互
- 三卡摘要、渐变柱状图、横向任务构成条、成长感言和里程碑徽章组成新的统计体验。
- 统计页完成移动端 / 平板 / 桌面端响应式适配，并加入分区入场动画。
