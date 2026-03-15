import { serve } from "std/http/server.ts";
import { createClient } from "@supabase/supabase-js";
import { Redis } from "@upstash/redis";

const redis = new Redis({
  url: Deno.env.get("UPSTASH_REDIS_REST_URL")!,
  token: Deno.env.get("UPSTASH_REDIS_REST_TOKEN")!,
});

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseKey);

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    const { user_id: sender_id, content } = await req.json(); // WeChat sends sender_id as user_id often in mock payloads, but let's assume sender_id is OpenID.
    // Clarification: The prompt implies the input payload might have "user_id" which IS the OpenID in the context of the webhook.
    // Let's assume input JSON is { "user_id": "OPENID", "content": "..." }

    if (!sender_id || !content) {
      return new Response("Missing user_id (sender_id) or content", { status: 400 });
    }

    // 1. Check if it is a binding code (6 chars alphanumeric)
    const bindingCodeRegex = /^[A-Z0-9]{6}$/i;
    
    if (bindingCodeRegex.test(content.trim())) {
        // Attempt Binding
        const code = content.trim().toUpperCase();
        
        const { data: profiles, error } = await supabase
            .from('profiles')
            .select('id')
            .eq('binding_code', code)
            .gt('binding_expires_at', new Date().toISOString())
            .single();

        if (error || !profiles) {
            // Reply failure
            // In a real WeChat webhook, we would return XML/JSON as per WeChat spec.
            // Here we just return JSON for the simulation.
            return new Response(JSON.stringify({ 
                reply: "❌ 绑定码无效或已过期，请在 App 内重新生成。" 
            }), { status: 200, headers: { "Content-Type": "application/json" } });
        }

        // Update Profile
        const { error: updateError } = await supabase
            .from('profiles')
            .update({ 
                wechat_openid: sender_id,
                binding_code: null,
                binding_expires_at: null
            })
            .eq('id', profiles.id);

        if (updateError) {
             return new Response(JSON.stringify({ 
                reply: "❌ 系统错误，绑定失败。" 
            }), { status: 200, headers: { "Content-Type": "application/json" } });
        }

        return new Response(JSON.stringify({ 
            reply: "✅ 绑定成功！欢迎来到你的专属任务控制台，冒险者。" 
        }), { status: 200, headers: { "Content-Type": "application/json" } });
    }

    // 2. Standard Message Handling
    // Need to find the App User ID associated with this OpenID
    const { data: userProfile, error: userError } = await supabase
        .from('profiles')
        .select('id')
        .eq('wechat_openid', sender_id)
        .single();

    if (userError || !userProfile) {
        return new Response(JSON.stringify({ 
            reply: "⚠️ 未绑定账号。请在 App 中生成绑定码并发送给我。" 
        }), { status: 200, headers: { "Content-Type": "application/json" } });
    }

    const appUserId = userProfile.id;

    // 3. Push message to Redis List (using App User ID)
    await redis.rpush(`msgs:${appUserId}`, content);

    // 4. Set/Update Timer Key
    await redis.set(`timer:${appUserId}`, "active", { ex: 15 });

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
