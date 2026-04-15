# Supabase Edge Functions & Redis Architecture Migration Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate backend logic to Supabase Edge Functions using Upstash Redis for stateless buffering and debounce management.

**Architecture:**
- **Receiver Function (`webhook`)**: Push messages into Upstash Redis and refresh a debounce timer.
- **Processor Function (`process-tasks`)**: Aggregate buffered messages after the timer expires, call DeepSeek, and save parsed tasks to Supabase.
- **Tech Stack:** Deno, Supabase Edge Functions, Upstash Redis, DeepSeek API.

---

### Task 1: Environment & Project Structure

**Files:**
- Create: `supabase/functions/import_map.json`
- Create: `supabase/functions/.env.example`
- Optional cleanup: archive `backend/`

**Note:** Use an OpenAI-compatible client if convenient, but point it at DeepSeek.

### Task 2: Receiver Function

**Files:**
- Create: `supabase/functions/webhook/index.ts`

**Responsibilities:**
1. Validate `user_id` and `content`.
2. Push to `msgs:{user_id}`.
3. Refresh `timer:{user_id}` with a 15-second TTL.

### Task 3: Processor Function

**Files:**
- Create: `supabase/functions/process-tasks/index.ts`

**LLM Configuration:**

```typescript
const openai = new OpenAI({
  apiKey: Deno.env.get("DEEPSEEK_API_KEY")!,
  baseURL: Deno.env.get("DEEPSEEK_BASE_URL") ?? "https://api.deepseek.com",
});
```

**Model:** `deepseek-chat`

**Responsibilities:**
1. Scan active Redis message lists.
2. Skip users still inside the debounce window.
3. Aggregate expired message batches.
4. Call DeepSeek for task extraction.
5. Save parsed tasks to Supabase.

### Task 4: Documentation & Deployment

**README / Ops instructions should include:**

```bash
supabase functions deploy webhook
supabase functions deploy process-tasks
supabase secrets set UPSTASH_REDIS_REST_URL=... UPSTASH_REDIS_REST_TOKEN=... DEEPSEEK_API_KEY=<your-deepseek-key> DEEPSEEK_BASE_URL=https://api.deepseek.com
```

### Security Note

Do not place the real DeepSeek key into tracked markdown, source code, or committed `.env` files. Store it only in environment variables or Supabase Secrets.
