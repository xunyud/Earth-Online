import "@supabase/functions-js/edge-runtime.d.ts"
import { EverMemOSClient } from "../_shared/evermemos_client.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

function toText(v: unknown) {
  if (typeof v === "string") return v.trim()
  if (v == null) return ""
  return String(v).trim()
}

function toErrorMessage(error: unknown) {
  if (error instanceof Error) return error.message
  try {
    return JSON.stringify(error)
  } catch {
    return String(error)
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ success: false, error: "Method Not Allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }

  try {
    const body = await req.json()
    const userId = toText(body?.user_id)
    const eventType = toText(body?.event_type)
    const content = toText(body?.content)

    if (!userId || !eventType || !content) {
      return new Response(
        JSON.stringify({ success: false, error: "缺少 user_id、event_type 或 content" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      )
    }

    const timeoutMsRaw = Number(Deno.env.get("EVERMEMOS_SYNC_TIMEOUT_MS") ?? "1500")
    const timeoutMs = Number.isFinite(timeoutMsRaw) && timeoutMsRaw > 0 ? timeoutMsRaw : 1500
    const client = new EverMemOSClient()
    const signal = AbortSignal.timeout(timeoutMs)

    try {
      await client.createMemory({
        userId,
        eventType,
        content,
      }, signal)
      return new Response(JSON.stringify({ success: true, synced: true }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    } catch (syncErr) {
      console.warn("sync-user-memory skipped:", toErrorMessage(syncErr))
      return new Response(JSON.stringify({ success: true, synced: false }), {
        status: 202,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }
  } catch (error) {
    const msg = toErrorMessage(error)
    console.error("sync-user-memory error:", msg)
    return new Response(JSON.stringify({ success: false, error: msg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
