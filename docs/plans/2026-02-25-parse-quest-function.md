# Supabase "parse-quest" Edge Function Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a `parse-quest` Edge Function that converts natural-language user input into structured quest data and writes it into `quest_nodes`.

**Architecture:**
- **Trigger:** Frontend or webhook sends `text` and `user_id`.
- **LLM Logic:** Call DeepSeek with structured-output prompting.
- **Persistence:** Write parsed quests into `quest_nodes` via Supabase service-role client.
- **Return:** Return created quest objects to the caller.

**Tech Stack:** Deno, Supabase Edge Functions, DeepSeek-compatible HTTP / SDK calls.

---

### Task 1: Function Skeleton

**Files:**
- Create: `supabase/functions/parse-quest/index.ts`
- Modify: `supabase/functions/_shared/cors.ts`

**Steps:**
1. Add CORS headers.
2. Initialize Supabase service-role client.
3. Accept `text` and `user_id`.

### Task 2: DeepSeek Integration

**Files:**
- Modify: `supabase/functions/parse-quest/index.ts`

**Steps:**
1. Define the system prompt for quest extraction.
2. Call `https://api.deepseek.com/chat/completions`.
3. Use `deepseek-chat` as the model.
4. Read secrets from:
   - `DEEPSEEK_API_KEY`
   - `DEEPSEEK_BASE_URL` with fallback `https://api.deepseek.com`
5. Parse the returned JSON payload.

### Task 3: Quest Persistence

**Files:**
- Modify: `supabase/functions/parse-quest/index.ts`

**Steps:**
1. Insert root quests first.
2. Map child quests using the returned parent IDs.
3. Batch insert into `quest_nodes`.

### Task 4: Deployment

**Steps:**
1. Deploy `parse-quest`.
2. Set:

```bash
supabase secrets set DEEPSEEK_API_KEY=<your-deepseek-key> DEEPSEEK_BASE_URL=https://api.deepseek.com
```

3. Verify request parsing and quest creation.

### Security Note

The real DeepSeek key must not be written into repo docs or committed config files. Use local env injection or Supabase Secrets only.
