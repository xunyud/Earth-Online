# Switch to DeepSeek API Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 `parse-quest` Edge Function 的 LLM 提供商从 OpenAI 切换为 DeepSeek，并设置正确的 API Key。

**Architecture:**
- **Endpoint:** `https://api.deepseek.com/chat/completions` (OpenAI-compatible)
- **Model:** `deepseek-chat`
- **Key:** Set via Supabase Secrets.

**Tech Stack:** Deno, Supabase Edge Functions.

---

### Task 1: 修改代码逻辑

**Files:**
- Modify: `supabase/functions/parse-quest/index.ts`

**Step 1: 更新 Fetch URL**
- 将 `https://api.openai.com/v1/chat/completions` 替换为 `https://api.deepseek.com/chat/completions`。

**Step 2: 更新 Model**
- 将 `gpt-4o-mini` 替换为 `deepseek-chat`。

**Step 3: 移除硬编码的 Key 引用 (最佳实践)**
- 代码中依然通过 `Deno.env.get('OPENAI_API_KEY')` 获取 Key。
- **注意**: 我们可以保持环境变量名为 `OPENAI_API_KEY` 以减少代码改动，或者改名为 `DEEPSEEK_API_KEY`。为了代码清晰，建议改名为 `DEEPSEEK_API_KEY`，并在部署时设置该 Secret。

### Task 2: 重新部署与配置 Secret

**Files:**
- None (Command line operations)

**Step 1: 设置 Secret**
- 运行 `supabase secrets set DEEPSEEK_API_KEY=sk-xxxx`。

**Step 2: 部署**
- 运行 `supabase functions deploy parse-quest`.

---

### Execution Steps

1.  **Code**: Update `index.ts`.
2.  **Secret**: Set the provided DeepSeek Key.
3.  **Deploy**: Redeploy function.
