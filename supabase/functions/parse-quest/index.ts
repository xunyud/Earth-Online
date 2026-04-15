import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

console.log("Function 'parse-quest' up and running!");

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const accessToken = authHeader.replace("Bearer", "").trim();
    if (!accessToken) {
      return new Response(
        JSON.stringify({ error: "Missing bearer token" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!supabaseUrl || !supabaseAnonKey) {
      throw new Error("Missing SUPABASE_URL or SUPABASE_ANON_KEY");
    }

    const authClient = createClient(supabaseUrl, supabaseAnonKey);
    const { data: authData, error: authError } = await authClient.auth.getUser(
      accessToken,
    );
    if (authError || !authData.user) {
      return new Response(
        JSON.stringify({
          error: "Invalid JWT",
          details: authError?.message ?? null,
        }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const { text, user_id } = await req.json();

    if (!text || !user_id) {
      throw new Error("Missing text or user_id");
    }
    if (authData.user.id !== user_id) {
      return new Response(
        JSON.stringify({ error: "user_id does not match token user" }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 1. Call the configured OpenAI-compatible LLM - parse only, no DB writes
    const llmApiKey = Deno.env.get("OPENAI_API_KEY") ||
      Deno.env.get("DEEPSEEK_API_KEY");
    if (!llmApiKey) {
      throw new Error("OPENAI_API_KEY or DEEPSEEK_API_KEY not set");
    }
    const llmBaseUrl = (
      Deno.env.get("OPENAI_BASE_URL") ||
      Deno.env.get("DEEPSEEK_BASE_URL") ||
      "https://api.86gamestore.com"
    ).replace(/\/+$/, "");
    const normalizedLlmBaseUrl = llmBaseUrl.endsWith("/v1")
      ? llmBaseUrl
      : `${llmBaseUrl}/v1`;

    const systemPrompt = `
    你是一个任务拆解助手。你的目标是把用户输入拆解为“纯父子层级”的任务树，并生成一句正常、温暖的鼓励语。

    【输出格式（必须严格遵守）】
    你只能输出一个合法 JSON 对象，且必须包含两个顶级字段：
    {
      "cheer": "string",
      "tasks": [
        {
          "title": "string",
          "parent_index": null 或 integer,
          "xpReward": integer
        }
      ]
    }
    - 禁止输出 Markdown。
    - 禁止输出解释或任何多余文本。
    - 禁止输出除 cheer 与 tasks 以外的顶级字段。
    - tasks 中也禁止输出除 title / parent_index / xpReward 以外的字段（尤其严禁 description 字段）。

    【强制规则（极其重要）】
    1) title 绝对不能为 null，绝对不能为 ""，也不能全是空白字符；必须保留用户原语言（中文输入输出中文标题，英文输入输出英文标题）。
    2) 严禁生成依赖关系文本：不要出现“依赖/先完成/之后/完成后再”等任何描述依赖的句子；只能用 parent_index 表达父子层级。
    3) 主线拆分规则（时间区分 + 逻辑区分）：
       - 不在同一天且逻辑不相关的任务，必须分开成为不同主线（不同 root，parent_index = null）。
       - 如果“时间关系相同”（同一天/同一时段）或“逻辑关系相同”（同一目标/同一事件/同一主题），任一成立，才允许放在同一主线下。
       - 仅仅是句子顺序/先后措辞（例如“然后/接着/之后/第二天/第三天”）不代表逻辑依赖；除非明显是同一件事的步骤，否则不要因为顺序而强行串成一条链。
       - 当你不确定两件事是否相关时，优先拆成不同主线。
    4) parent_index 用法：
       - parent_index 只能表达“主线下的步骤/子任务”或“同一主线的子层级”。
       - 不能跨主线串联（不同天且不相关的任务不要互相成为父子）。
    5) parent_index 要么为 null，要么必须是有效整数索引，且必须指向 tasks 数组中“当前任务之前”的任务（parent_index < 当前任务索引），禁止越界或指向未来。
    6) xpReward 必须是 10~100 的整数。
    7) cheer 是一句正常温暖的鼓励语：
       - 纯字符串
       - 20 字以内
       - 允许包含 1 个 emoji（可选）
       - 不要 RPG/中二风格，不要夸张设定

    【示例】
    用户输入: "明天下午去医院拔智齿，拔完去睡觉，第二天开会，第三天写代码"
    输出:
    {
      "cheer": "辛苦了，慢慢来就好。",
      "tasks": [
        { "title": "明天下午去医院拔智齿", "parent_index": null, "xpReward": 80 },
        { "title": "拔完去睡觉", "parent_index": 0, "xpReward": 30 },
        { "title": "第二天开会", "parent_index": null, "xpReward": 40 },
        { "title": "第三天写代码", "parent_index": null, "xpReward": 60 }
      ]
    }
    `;

    const response = await fetch(`${normalizedLlmBaseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${llmApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "deepseek-chat",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: text },
        ],
        temperature: 0.5,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`LLM API Error: ${response.status} - ${errorText}`);
    }

    const llmData = await response.json();
    if (!llmData.choices || !llmData.choices[0].message.content) {
      throw new Error("Failed to get LLM response");
    }

    let parsed: any = null;
    try {
      // Clean up markdown code blocks if present
      const rawContent = llmData.choices[0].message.content.replace(
        /```json/g,
        "",
      ).replace(/```/g, "").trim();
      parsed = JSON.parse(rawContent);
    } catch (e) {
      console.error("LLM Parse Error:", e);
      throw new Error("Failed to parse LLM JSON");
    }

    const tasksRaw = Array.isArray(parsed?.tasks) ? parsed.tasks : [];
    const cheerRaw = typeof parsed?.cheer === "string"
      ? parsed.cheer.trim()
      : "";

    const tasks: Array<{
      title: string;
      parent_index: number | null;
      xpReward: number;
    }> = [];

    for (let i = 0; i < tasksRaw.length; i++) {
      const q = tasksRaw[i];
      const title = typeof q?.title === "string" ? q.title.trim() : "";
      if (!title) continue;
      let parent_index: number | null = null;
      if (Number.isInteger(q?.parent_index)) {
        parent_index = q.parent_index;
      }
      if (parent_index !== null && (parent_index < 0 || parent_index >= i)) {
        parent_index = null;
      }

      let xp = Number.isFinite(q?.xpReward) ? Math.round(q.xpReward) : 20;
      if (xp < 10) xp = 10;
      if (xp > 100) xp = 100;

      tasks.push({
        title,
        parent_index,
        xpReward: xp,
      });
    }

    const cheer = cheerRaw && cheerRaw.length <= 60
      ? cheerRaw
      : "辛苦了，慢慢来就好。";

    return new Response(
      JSON.stringify({ tasks, cheer }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
