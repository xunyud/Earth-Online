// supabase/functions/guide-freeform-chat/index.ts
// 代理前端直接 OpenAI 调用，API Key 仅存于服务端环境变量。

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, toText, toRecord, json } from "../_shared/http.ts";
import { normalizeOpenAICompatibleBaseUrl } from "../_shared/guide_ai.ts";

function getApiKey(): string {
  return (
    Deno.env.get("OPENAI_API_KEY") ||
    Deno.env.get("DEEPSEEK_API_KEY") ||
    ""
  ).trim();
}

function getApiBaseUrl(): string {
  const baseUrl =
    Deno.env.get("OPENAI_BASE_URL") ||
    Deno.env.get("DEEPSEEK_BASE_URL") ||
    "https://api.86gamestore.com";
  return normalizeOpenAICompatibleBaseUrl(baseUrl);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { success: false, error: "Method Not Allowed" });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const accessToken = authHeader.replace("Bearer", "").trim();
    if (!accessToken) {
      return json(401, { success: false, error: "Missing bearer token" });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    if (!supabaseUrl || !supabaseAnonKey) {
      throw new Error("Missing SUPABASE env");
    }

    const authClient = createClient(supabaseUrl, supabaseAnonKey);
    const { data: authData, error: authError } =
      await authClient.auth.getUser(accessToken);
    if (authError || !authData.user) {
      return json(401, { success: false, error: "Invalid JWT" });
    }

    const apiKey = getApiKey();
    if (!apiKey) {
      return json(500, {
        success: false,
        error: "Server missing OPENAI_API_KEY",
      });
    }

    const body = await req.json();
    const message = toText(body?.message);
    const systemPrompt = toText(body?.system_prompt);
    if (!message) {
      return json(400, { success: false, error: "Missing message" });
    }

    const model = toText(body?.model) || "deepseek-chat";
    const temperature = typeof body?.temperature === "number"
      ? body.temperature
      : 0.4;

    const llmResp = await fetch(
      `${getApiBaseUrl()}/chat/completions`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          temperature,
          messages: [
            ...(systemPrompt
              ? [{ role: "system", content: systemPrompt }]
              : []),
            { role: "user", content: message },
          ],
        }),
      },
    );

    if (!llmResp.ok) {
      const errText = await llmResp.text();
      console.error("guide-freeform-chat LLM error:", llmResp.status, errText);
      return json(502, {
        success: false,
        error: `LLM returned ${llmResp.status}`,
      });
    }

    const data = await llmResp.json();
    const reply = toText(data?.choices?.[0]?.message?.content);
    if (!reply) {
      return json(502, { success: false, error: "Empty LLM response" });
    }

    return json(200, { success: true, reply });
  } catch (error) {
    return json(500, {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    });
  }
});
