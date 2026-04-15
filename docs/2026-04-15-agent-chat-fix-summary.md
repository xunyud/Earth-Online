# Agent Chat Fix Summary

- 日期：2026-04-15
- 执行者：Codex
- 主题：业务型 agent 收束与自由聊天修复

## 背景

本轮问题集中在两条线上：

1. 业务型 agent 已经开始替换操作型 agent，但自由聊天仍然残留在旧的 `GuideService.chat` 单点路径中，没有真正统一到 agent 编排入口。
2. 自由聊天在实际界面中表现为重复固定模板句，例如：
   - “我已复盘你最近 X 条记忆……”
   - “网络有点抖动，我先离线陪你……”

## 根因结论

### 根因 1：兼容模型接口地址错误

项目中多处模型调用最初使用：

- `https://api.86gamestore.com/chat/completions`

但对目标服务进行真实探测后确认：

- 站点首页：`https://api.86gamestore.com`
- OpenAI 兼容模型列表：`https://api.86gamestore.com/v1/models`
- OpenAI 兼容聊天接口：`https://api.86gamestore.com/v1/chat/completions`

也就是说，真实可用的兼容接口必须带 `/v1`。

由于原代码少了 `/v1`，请求失败后又在 `guide_ai.ts` 中静默 fallback，于是界面上看起来像“根本没走出去”。

### 根因 2：自由聊天仍依赖远端旧部署的 `guide-chat`

虽然本地代码已修复了兼容接口 base URL，但界面里的自由聊天最初仍然经由：

- `HomePage -> GuideService.chat -> Supabase function guide-chat`

而远端 Supabase 上部署的 `guide-chat` 仍是旧逻辑，因此即便本地代码更新，真实界面仍可能拿到旧模板回复。

### 根因 3：业务型 agent 的远端 `agent-turn` 未部署

真实浏览器测试中发现：

- `POST https://.../functions/v1/agent-turn` 预检/请求失败
- 原因是远端函数不存在，浏览器侧表现为 CORS / `net::ERR_FAILED`

所以不能依赖远端 `agent-turn` 作为当前可用的统一入口。

### 根因 4：浏览器直连第三方模型接口被 CORS 阻断

在将自由聊天改为前端直连 `https://api.86gamestore.com/v1/chat/completions` 后，真实浏览器网络日志显示：

- 请求实际发出
- 但浏览器侧被 `net::ERR_FAILED` / CORS 限制拦截

说明浏览器不能直接安全稳定地访问该模型服务。

## 最终修复方案

### 1. 业务型 agent 统一入口

将普通聊天、任务创建、任务修改、任务拆分、周报生成、奖励兑换、页面导航统一归入业务型 agent 规划：

- `app.chat.freeform.respond`
- `app.quest.create`
- `app.quest.update`
- `app.quest.split`
- `app.weekly_summary.generate`
- `app.reward.redeem`
- `app.navigation.open`

这样聊天、周报、任务修改不再是两条完全分离的逻辑。

### 2. 修复 OpenAI 兼容接口 base URL

新增兼容 base URL 归一化逻辑，保证：

- `https://api.86gamestore.com` -> `https://api.86gamestore.com/v1`
- 已带 `/v1` 的地址不重复追加

修复覆盖这些链路：

- `supabase/functions/_shared/guide_ai.ts`
- `supabase/functions/weekly-summary/index.ts`
- `supabase/functions/parse-quest/index.ts`
- `supabase/functions/process-tasks/index.ts`
- `backend/src/llm.ts`

### 3. 自由聊天改为“agent 统一入口 + 本地后端代理”

最终采用的稳定路径为：

1. 前端对任意非空聊天输入统一走业务型 agent 入口
2. 对自由聊天，planner 规划为 `app.chat.freeform.respond`
3. runtime 不再让浏览器直接请求第三方模型接口
4. runtime 优先请求本地后端代理：
   - `POST http://127.0.0.1:3000/agent/free-chat`
5. 本地后端代理再请求：
   - `https://api.86gamestore.com/v1/chat/completions`

这样既统一了 agent 编排入口，又避开了浏览器 CORS 问题。

### 4. 自由聊天回答风格修正

为直连聊天新增专用 system prompt，要求：

- 直接回答用户当前问题
- 不复述“我已复盘你最近几条记忆”这种模板句
- 不强行转任务
- 用 1 到 3 句中文自然回答
- 必要时补一句轻量追问或陪伴式延续

## 本轮主要改动文件

### 前端

- `frontend/lib/core/config/app_config.dart`
- `frontend/lib/core/services/local_agent_runtime_service.dart`
- `frontend/lib/features/quest/screens/home_page.dart`
- `frontend/test/local_agent_runtime_service_test.dart`

### Supabase / Deno

- `supabase/functions/_shared/guide_ai.ts`
- `supabase/functions/_shared/guide_ai_test.ts`
- `supabase/functions/_shared/agent_planner.ts`
- `supabase/functions/_shared/agent_planner_test.ts`
- `supabase/functions/_shared/agent_policy.ts`
- `supabase/functions/_shared/agent_policy_test.ts`
- `supabase/functions/agent-turn/index_test.ts`
- `supabase/functions/agent-step-complete/index_test.ts`
- `supabase/functions/weekly-summary/index.ts`
- `supabase/functions/parse-quest/index.ts`
- `supabase/functions/process-tasks/index.ts`

### 本地 backend

- `backend/src/index.ts`
- `backend/src/llm.ts`
- `backend/.env`

## 验证结果

### 代码级验证

已通过：

- `flutter test test/local_agent_runtime_service_test.dart test/agent_run_service_test.dart test/agent_service_test.dart`
- `deno test --no-check functions/_shared/agent_planner_test.ts functions/_shared/agent_policy_test.ts functions/agent-turn/index_test.ts functions/agent-step-complete/index_test.ts functions/_shared/guide_ai_test.ts`
- `deno test functions/_shared/guide_ai_test.ts`

说明：

- 前端 `flutter analyze` 当前仍有一个 `dead_code` warning，来源于 `home_page.dart` 中业务型 agent 收束后残留的旧技术判断分支，不影响本轮功能可用性。

### 后端代理验证

已直接验证：

- `POST http://127.0.0.1:3000/agent/free-chat`

返回：

- `200 OK`
- 有真实聊天回复

示例返回：

```json
{"success":true,"reply":"我是 AI 助手。"}
```

### 真实界面聊天测试

已执行真实 UI 聊天测试，步骤如下：

1. 启动本地 backend，监听 `3000`
2. 启动 Flutter web-server，并通过 `dart-define` 注入：
   - `OPENAI_API_KEY`
   - `OPENAI_BASE_URL`
   - `OPENAI_CHAT_MODEL`
   - `AGENT_CHAT_PROXY_URL`
3. 匿名进入应用
4. 打开“小忆”对话框
5. 输入：`你是谁`
6. 点击发送

最终界面实际返回：

> 我是小忆，会陪你把事情想清楚、慢慢推进，也可以只是陪你聊聊。你现在想让我帮你做什么？

这说明：

- 不再是固定 fallback 模板句
- 不再是“网络有点抖动，我先离线陪你……”
- 自由聊天已经真实走通

## 当前状态

本轮目标已达成：

- 自由聊天已从旧的 `GuideService.chat` 单点依赖中解耦
- 聊天、周报、任务修改等能力已收束到业务型 agent 统一入口
- 自由聊天在当前本机环境下已经通过真实界面测试

## 后续建议

1. 将远端 Supabase 的 `agent-turn` 正式部署，避免当前只能依赖本地兜底
2. 将 `guide-chat` 远端函数升级为新业务型编排，减少本地与远端逻辑漂移
3. 抽出独立的前端聊天代理 service，进一步减轻 `home_page.dart` 体积
4. 清理 `home_page.dart` 中已失效的旧技术路由判断，消除当前 `dead_code` warning
