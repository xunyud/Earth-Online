// knowledge-extraction: 定期知识提取 Edge Function
// 功能：遍历活跃用户，调用 EverMemOS Flush API 从具体记忆中提取行为模式（semantic_memory）
// 触发方式：pg_cron 每周触发（批量模式）或手动调用（单用户模式）
// 输入：POST {} （批量模式）或 POST { user_id }（单用户模式）
// 输出：{ success: boolean, processed: number, errors: string[] }

import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { EverMemOSClient } from "../_shared/evermemos_client.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function toText(v: unknown): string {
  if (typeof v === "string") return v.trim();
  if (v == null) return "";
  return String(v).trim();
}

function toErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}

function json(status: number, data: unknown) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/**
 * 对单个用户执行知识提取（调用 Flush API）。
 * 失败时返回错误信息，不抛出异常，实现错误隔离。
 */
async function flushForUser(
  client: EverMemOSClient,
  userId: string,
): Promise<string | null> {
  try {
    await client.flushMemories(userId, AbortSignal.timeout(30_000));
    return null;
  } catch (err) {
    const msg = toErrorMessage(err);
    console.error(`knowledge-extraction flush failed for user=${userId}:`, msg);
    return `${userId}: ${msg}`;
  }
}

Deno.serve(async (req) => {
  // 处理 CORS 预检请求
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json(405, { success: false, error: "Method Not Allowed" });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRole) {
      throw new Error("Missing SUPABASE env");
    }

    const supabase = createClient(supabaseUrl, serviceRole);
    const everMem = new EverMemOSClient();

    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const targetUserId = toText(body?.user_id);

    let userIds: string[] = [];

    if (targetUserId) {
      // 单用户模式：直接使用传入的 user_id
      userIds = [targetUserId];
    } else {
      // 批量模式：查询最近 7 天有 daily_logs 记录的活跃用户
      const sevenDaysAgo = new Date(Date.now() - 7 * 86400_000)
        .toISOString()
        .slice(0, 10);
      const { data: activeLogs } = await supabase
        .from("daily_logs")
        .select("user_id")
        .gte("date_id", sevenDaysAgo)
        .limit(500);

      if (activeLogs && activeLogs.length > 0) {
        // 去重：同一用户可能有多天的日志
        userIds = [
          ...new Set(
            (activeLogs as Array<{ user_id: string }>).map((r) => r.user_id),
          ),
        ];
      }
    }

    if (userIds.length === 0) {
      return json(200, { success: true, processed: 0, errors: [] });
    }

    // 逐用户调用 Flush API（串行执行，避免并发过高）
    const errors: string[] = [];
    let processed = 0;

    for (const userId of userIds) {
      const err = await flushForUser(everMem, userId);
      if (err) {
        errors.push(err);
      } else {
        processed++;
      }
    }

    console.log(
      `knowledge-extraction done: total=${userIds.length} processed=${processed} errors=${errors.length}`,
    );

    return json(200, {
      success: true,
      processed,
      errors,
    });
  } catch (error) {
    const msg = toErrorMessage(error);
    console.error("knowledge-extraction error:", msg);
    return json(500, { success: false, error: msg });
  }
});
