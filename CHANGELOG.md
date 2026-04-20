# Changelog

- 最后更新：2026-04-15
- 维护者：Codex

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
