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
    try {
        const completion = await openai.chat.completions.create({
            messages: [
                { role: "system", content: `You are the "Quest Master" AI of an RPG game. Your job is to analyze chaotic chat logs from the user and synthesize them into a structured Quest Tree.

Rules for Extraction & Analysis:
1. Identify Tiers: Determine if an intent is a "Main_Quest" (crucial, high impact, blocker) or a "Side_Quest" (nice to have, minor errand) or "Daily".
2. Breakdown Sub-quests: If a message implies multiple steps (e.g., "Prepare for tomorrow's pitch, read the docs, and draft the PPT"), create ONE parent Main_Quest ("Prepare for Pitch") and MULTIPLE child QuestNodes ("Read docs", "Draft PPT") with the parent's temporary ID in their parent_temp_id field.
3. Assign XP: Assign an xp_reward (10 to 100) based on how hard or time-consuming the task seems.
4. Output a flat JSON array of QuestNode objects, properly linked via parent_temp_id. Root nodes must have parent_temp_id: null.` },
                { role: "user", content: text }
            ],
            model: "gpt-3.5-turbo",
            functions: [
                {
                    name: "save_quests",
                    description: "Save extracted quests",
                    parameters: {
                        type: "object",
                        properties: {
                            quests: {
                                type: "array",
                                items: {
                                    type: "object",
                                    properties: {
                                        temp_id: { type: "string", description: "Temporary unique ID for linking" },
                                        parent_temp_id: { type: "string", nullable: true, description: "Temporary ID of parent node" },
                                        title: { type: "string" },
                                        quest_tier: { type: "string", enum: ["Main_Quest", "Side_Quest", "Daily"] },
                                        xp_reward: { type: "number" },
                                        original_context: { type: "array", items: { type: "string" } }
                                    },
                                    required: ["temp_id", "title", "quest_tier", "xp_reward"]
                                }
                            }
                        },
                        required: ["quests"]
                    }
                }
            ],
            function_call: { name: "save_quests" }
        });

        const functionArgs = completion.choices[0].message.function_call?.arguments;
        if (functionArgs) {
            return JSON.parse(functionArgs).quests;
        }
    } catch (error) {
        console.error("LLM Error:", error);
    }
    return [];
}

serve(async (req) => {
  try {
    const keys = await redis.keys("msgs:*");
    const results = [];

    for (const key of keys) {
      const userId = key.split(":")[1];
      const timerExists = await redis.exists(`timer:${userId}`);
      
      if (timerExists === 0) {
        const messages = await redis.lrange(key, 0, -1);
        
        if (messages.length > 0) {
           await redis.del(key);
           const aggregatedText = messages.join("\n");
           const extractedQuests = await extractTasks(aggregatedText);
           
           if (extractedQuests.length > 0) {
             // Resolve IDs
             const tempIdMap = new Map<string, string>();
             
             // 1. Generate real UUIDs
             extractedQuests.forEach(q => {
                 tempIdMap.set(q.temp_id, crypto.randomUUID());
             });

             // 2. Prepare for Insert
             const questsToInsert = extractedQuests.map(q => ({
                 id: tempIdMap.get(q.temp_id),
                 user_id: userId,
                 parent_id: q.parent_temp_id ? tempIdMap.get(q.parent_temp_id) : null,
                 title: q.title,
                 quest_tier: q.quest_tier,
                 xp_reward: q.xp_reward,
                 original_context: q.original_context || [],
                 is_completed: false
             }));

             // 3. Insert into DB
             // Note: Supabase insert might fail if parents don't exist yet due to FK constraints.
             // Strategy: Sort by dependency (roots first) or insert in batches.
             // Simple approach: Sort so that items with parent_id: null come first.
             // Even better: Insert roots first, then children.
             
             const roots = questsToInsert.filter(q => q.parent_id === null);
             const children = questsToInsert.filter(q => q.parent_id !== null);
             
             // Insert roots
             if (roots.length > 0) {
                const { error: rootError } = await supabase.from('quest_nodes').insert(roots);
                if (rootError) throw rootError;
             }
             
             // Insert children
             if (children.length > 0) {
                const { error: childError } = await supabase.from('quest_nodes').insert(children);
                if (childError) throw childError;
             }
             
             results.push({ userId, status: "processed", quests: questsToInsert.length });
           } else {
             results.push({ userId, status: "no_quests_extracted" });
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
