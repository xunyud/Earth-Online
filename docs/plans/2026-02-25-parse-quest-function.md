# Supabase "parse-quest" Edge Function Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 创建 `parse-quest` Edge Function，利用 LLM 将用户自然语言输入解析为结构化任务数据，并自动存入数据库。

**Architecture:**
- **Trigger:** Frontend/Webhook POSTs text.
- **LLM Logic:** Calls OpenAI/DeepSeek API with structured output prompting.
- **Data Persistence:** Writes parsed quests directly to `quest_nodes` via Supabase Client (Service Role).
- **Return:** Returns the created quest objects to the caller.

**Tech Stack:** Deno, Supabase Edge Functions, OpenAI SDK.

---

### Task 1: 创建 Function 基础结构

**Files:**
- Create: `supabase/functions/parse-quest/index.ts`
- Modify: `supabase/functions/_shared/cors.ts` (Ensure it's ready, created in previous steps)

**Step 1: 编写 `index.ts`**
- 设置 CORS headers。
- 初始化 Supabase Client (使用 Service Role Key 以绕过 RLS 写入)。
- 接收 `text` 和 `user_id` 参数。

### Task 2: 集成 LLM 逻辑

**Files:**
- Modify: `supabase/functions/parse-quest/index.ts`

**Step 1: 定义 Prompt**
- System: "You are an RPG Quest Master..."
- Format: JSON Array with `title`, `quest_tier` (Main/Side/Daily), `xp_reward`, `parent_index` (for nesting).

**Step 2: 调用 OpenAI API**
- 使用 `fetch` 调用 `https://api.openai.com/v1/chat/completions` (或者兼容的 DeepSeek 端点)。
- 解析返回的 JSON 内容。

### Task 3: 数据库写入与依赖处理

**Files:**
- Modify: `supabase/functions/parse-quest/index.ts`

**Step 1: 处理父子关系**
- 遍历 LLM 返回的数组。
- 先插入 `parent_index == null` 的根任务，获取 ID。
- 再插入子任务，将其 `parent_id` 映射到对应的根任务 ID。

**Step 2: 批量插入**
- 使用 `supabase.from('quest_nodes').insert(...)`。

---

### Execution Steps

1.  **Code**: Write `index.ts` with all logic (API, LLM, DB).
2.  **Deploy**: Run `supabase functions deploy parse-quest`.
3.  **Secrets**: Set `OPENAI_API_KEY`.
