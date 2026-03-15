import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from "../_shared/cors.ts"
import { getOrCreateDailyEvent } from "../_shared/guide_engine.ts"

function toText(v: unknown) {
  if (typeof v === "string") return v.trim()
  if (v == null) return ""
  return String(v).trim()
}

function json(status: number, data: unknown) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  if (req.method !== "POST") return json(405, { success: false, error: "Method Not Allowed" })

  try {
    const authHeader = req.headers.get("Authorization") ?? ""
    const accessToken = authHeader.replace("Bearer", "").trim()
    if (!accessToken) return json(401, { success: false, error: "Missing bearer token" })

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? ""
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    if (!supabaseUrl || !supabaseAnonKey || !serviceRole) {
      throw new Error("Missing SUPABASE env")
    }

    const authClient = createClient(supabaseUrl, supabaseAnonKey)
    const { data: authData, error: authError } = await authClient.auth.getUser(accessToken)
    if (authError || !authData.user) return json(401, { success: false, error: "Invalid JWT" })

    let body: Record<string, unknown> = {}
    try {
      body = await req.json()
    } catch {
      body = {}
    }
    const scene = toText(body.scene) || "home"

    const supabase = createClient(supabaseUrl, serviceRole)
    const payload = await getOrCreateDailyEvent(supabase, authData.user.id, scene)
    return json(200, {
      success: true,
      event_id: payload.event_id,
      title: payload.title,
      description: payload.description,
      reward_xp: payload.reward_xp,
      reward_gold: payload.reward_gold,
      reason: payload.reason,
      status: payload.status,
      memory_refs: payload.memory_refs,
    })
  } catch (error) {
    return json(500, { success: false, error: error instanceof Error ? error.message : String(error) })
  }
})
