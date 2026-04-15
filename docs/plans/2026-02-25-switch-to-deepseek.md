# Switch to DeepSeek API Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Switch `parse-quest` from OpenAI to DeepSeek, and standardize both the API key and base URL configuration.

**Architecture:**
- **Base URL:** `https://api.deepseek.com`
- **Endpoint:** `https://api.deepseek.com/chat/completions`
- **Model:** `deepseek-chat`
- **Secrets:** `DEEPSEEK_API_KEY` and `DEEPSEEK_BASE_URL`

**Tech Stack:** Deno, Supabase Edge Functions.

---

### Task 1: Update LLM Call

**Files:**
- Modify: `supabase/functions/parse-quest/index.ts`

**Steps:**
1. Replace the OpenAI endpoint with `https://api.deepseek.com/chat/completions`.
2. Replace the model with `deepseek-chat`.
3. Read the API key from `Deno.env.get("DEEPSEEK_API_KEY")`.
4. Read the base URL from `Deno.env.get("DEEPSEEK_BASE_URL") ?? "https://api.deepseek.com"`.

### Task 2: Configure Secrets

**Files:**
- None (CLI / deployment configuration)

**Steps:**
1. Run:

```bash
supabase secrets set DEEPSEEK_API_KEY=<your-deepseek-key> DEEPSEEK_BASE_URL=https://api.deepseek.com
```

2. Redeploy:

```bash
supabase functions deploy parse-quest
```

### Task 3: Security Rule

**Rule:** Never write the real DeepSeek key into tracked docs, source code, or committed `.env` files. The real key must only be injected through local environment variables or Supabase Secrets.

---

### Execution Steps

1. Update `parse-quest` to use DeepSeek.
2. Set `DEEPSEEK_API_KEY`.
3. Set `DEEPSEEK_BASE_URL=https://api.deepseek.com`.
4. Redeploy and verify the function.
