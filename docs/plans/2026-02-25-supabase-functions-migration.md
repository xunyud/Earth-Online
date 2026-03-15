# Supabase Edge Functions & Redis Architecture Migration Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate backend logic to Supabase Edge Functions using Upstash Redis for stateless message buffering and debounce management.

**Architecture:**
- **Receiver Function (`webhook`)**: Stateless endpoint. Pushes messages to Upstash Redis (`msgs:{user_id}`) and sets a debounce timer (`timer:{user_id}` with 15s TTL).
- **Processor Function (`process-tasks`)**: Triggered via Cron (or manually). Scans for active message lists (`msgs:*`). If `timer:{user_id}` has expired (does not exist), aggregates messages, calls LLM, and saves to Supabase DB.
- **Tech Stack:** Deno, Supabase Edge Functions, Upstash Redis, OpenAI API.

---

### Task 1: Environment & Project Structure Setup

**Files:**
- Create: `supabase/config.toml` (if needed, or just rely on folder structure)
- Create: `supabase/functions/import_map.json`
- Create: `supabase/functions/.env.example`
- Delete: `backend/` (Archive or remove to avoid confusion)

**Step 1: Create Supabase Functions Directory**

```bash
mkdir supabase\functions
```

**Step 2: Create Import Map**

Create `supabase/functions/import_map.json` to manage Deno dependencies.

```json
{
  "imports": {
    "std/": "https://deno.land/std@0.208.0/",
    "@supabase/supabase-js": "https://esm.sh/@supabase/supabase-js@2.39.0",
    "@upstash/redis": "https://esm.sh/@upstash/redis@1.28.0",
    "openai": "https://esm.sh/openai@4.20.1"
  }
}
```

**Step 3: Cleanup Old Backend**

(Optional but recommended) Move old backend to `_archive/backend`.

```bash
mkdir _archive
mv backend _archive/backend
```

### Task 2: Implement Receiver Function (`webhook`)

**Files:**
- Create: `supabase/functions/webhook/index.ts`

**Step 1: Create Function File**

Create `supabase/functions/webhook/index.ts`.

```typescript
import { serve } from "std/http/server.ts";
import { Redis } from "@upstash/redis";

const redis = new Redis({
  url: Deno.env.get("UPSTASH_REDIS_REST_URL")!,
  token: Deno.env.get("UPSTASH_REDIS_REST_TOKEN")!,
});

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    const { user_id, content } = await req.json();

    if (!user_id || !content) {
      return new Response("Missing user_id or content", { status: 400 });
    }

    // 1. Push message to Redis List
    await redis.rpush(`msgs:${user_id}`, content);

    // 2. Set/Update Timer Key (15 seconds expiration)
    // using set with EX (seconds)
    await redis.set(`timer:${user_id}`, "active", { ex: 15 });

    return new Response(JSON.stringify({ status: "queued" }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    console.error(error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
});
```

### Task 3: Implement Processor Function (`process-tasks`)

**Files:**
- Create: `supabase/functions/process-tasks/index.ts`

**Step 1: Create Function File**

Create `supabase/functions/process-tasks/index.ts`. This function will be called by a Cron job.

```typescript
import { serve } from "std/http/server.ts";
import { createClient } from "@supabase/supabase-js";
import { Redis } from "@upstash/redis";
import OpenAI from "openai";

const redis = new Redis({
  url: Deno.env.get("UPSTASH_REDIS_REST_URL")!,
  token: Deno.env.get("UPSTASH_REDIS_REST_TOKEN")!,
});

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseKey);

const openai = new OpenAI({
  apiKey: Deno.env.get("OPENAI_API_KEY")!,
});

async function extractTasks(text: string): Promise<any[]> {
    // ... Copy logic from previous implementation, adapted for Deno/OpenAI
    try {
        const completion = await openai.chat.completions.create({
            messages: [
                { role: "system", content: "You are an expert executive assistant. Analyze the provided fragmented chat logs. Extract actionable tasks. Ignore casual chatter. Consolidate duplicate points. Output strictly as a JSON array adhering to the ParsedTask schema." },
                { role: "user", content: text }
            ],
            model: "gpt-3.5-turbo",
            functions: [
                {
                    name: "save_tasks",
                    description: "Save extracted tasks",
                    parameters: {
                        type: "object",
                        properties: {
                            tasks: {
                                type: "array",
                                items: {
                                    type: "object",
                                    properties: {
                                        title: { type: "string" },
                                        start_time: { type: "string", format: "date-time", nullable: true },
                                        duration_minutes: { type: "number" },
                                        priority: { type: "string", enum: ["low", "medium", "high"] },
                                        dependencies: { type: "array", items: { type: "string" } },
                                        status: { type: "string", enum: ["pending", "in_progress", "done"] }
                                    },
                                    required: ["title", "duration_minutes", "priority", "status"]
                                }
                            }
                        },
                        required: ["tasks"]
                    }
                }
            ],
            function_call: { name: "save_tasks" }
        });

        const functionArgs = completion.choices[0].message.function_call?.arguments;
        if (functionArgs) {
            return JSON.parse(functionArgs).tasks;
        }
    } catch (error) {
        console.error("LLM Error:", error);
    }
    return [];
}

serve(async (req) => {
  try {
    // 1. Scan for all message lists
    // Note: In production with many users, use SCAN. For prototype, KEYS is okay or maintain a set of active users.
    // Better pattern: Maintain a set 'active_users'
    
    // For this implementation, we'll use KEYS for simplicity as per prototype scope, 
    // but a Set is better. Let's assume we scan keys.
    const keys = await redis.keys("msgs:*");
    
    const results = [];

    for (const key of keys) {
      const userId = key.split(":")[1];
      
      // 2. Check if timer exists
      const timerExists = await redis.exists(`timer:${userId}`);
      
      if (timerExists === 0) {
        // Timer expired (or never set, but list exists means messages are pending)
        
        // 3. Pop all messages
        const messages = await redis.lrange(key, 0, -1);
        
        if (messages.length > 0) {
           // Clear list immediately to avoid double processing (Atomic RENAME or delete after is better, 
           // but for now, DEL is fine. Optimistic locking is ideal but complex here).
           await redis.del(key);

           const aggregatedText = messages.join("\n");
           
           // 4. Call LLM
           const tasks = await extractTasks(aggregatedText);
           
           // 5. Save to Supabase
           if (tasks.length > 0) {
             const tasksWithUser = tasks.map(t => ({ ...t, user_id: userId }));
             const { error } = await supabase.from('parsed_tasks').insert(tasksWithUser);
             if (error) console.error("Supabase Error", error);
             results.push({ userId, status: "processed", tasks: tasks.length });
           } else {
             results.push({ userId, status: "no_tasks_extracted" });
           }
        }
      } else {
        results.push({ userId, status: "waiting_for_debounce" });
      }
    }

    return new Response(JSON.stringify({ processed: results }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
     console.error(error);
     return new Response(JSON.stringify({ error: error.message }), {
       status: 500,
     });
  }
});
```

### Task 4: Documentation Update

**Files:**
- Modify: `README.md`

**Step 1: Update README**

Update the architecture section and setup instructions to reflect the move to Supabase Edge Functions and Upstash.
Add instructions on how to set up the Cron job (e.g., via Supabase Dashboard or pg_cron).

```markdown
## Supabase Edge Functions Setup

1. **Deploy Functions**:
   ```bash
   supabase functions deploy webhook
   supabase functions deploy process-tasks
   ```

2. **Set Secrets**:
   ```bash
   supabase secrets set UPSTASH_REDIS_REST_URL=... UPSTASH_REDIS_REST_TOKEN=... OPENAI_API_KEY=...
   ```

3. **Configure Cron**:
   Enable a cron job to call `process-tasks` every minute (or 10s if using custom scheduler).
   
   Example `pg_cron` (if enabled in DB):
   ```sql
   select cron.schedule(
     'process-tasks-every-minute',
     '* * * * *', -- Every minute
     $$
     select
       net.http_post(
           url:='https://<project-ref>.supabase.co/functions/v1/process-tasks',
           headers:='{"Content-Type": "application/json", "Authorization": "Bearer <anon_key>"}'::jsonb,
           body:='{}'::jsonb
       ) as request_id;
     $$
   );
   ```
```
