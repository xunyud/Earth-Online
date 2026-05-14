// supabase/functions/_shared/http.ts
// 统一 HTTP 工具函数，消除各 Edge Function 中的重复定义。

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/** @deprecated 使用 corsHeaders 代替 */
export const agentCorsHeaders = corsHeaders;

/** 将未知值转为 trimmed string，null/undefined → "" */
export function toText(value: unknown): string {
  if (typeof value === "string") return value.trim();
  if (value == null) return "";
  return String(value).trim();
}

/** 将未知值安全转为 Record，非对象 → {} */
export function toRecord(
  value: unknown,
): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
}

/** 将未知值转为 boolean，支持字符串 "true"/"false" */
export function toBool(value: unknown, fallback = false): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    const lowered = value.trim().toLowerCase();
    if (lowered === "true") return true;
    if (lowered === "false") return false;
  }
  return fallback;
}

/** 将未知 error 转为可读字符串 */
export function toErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}

/** 快捷构建 JSON Response，自动附带 CORS 头 */
export function json(
  status: number,
  data: unknown,
  extraHeaders?: Record<string, string>,
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      ...extraHeaders,
    },
  });
}
