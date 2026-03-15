import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from "../_shared/cors.ts"
import { acceptOrDismissDailyEvent } from "../_shared/guide_engine.ts"

function toText(v: unknown) {
  if (typeof v === "string") return v.trim()
  if (v == null) return ""
  return String(v).trim()
}

function toBool(v: unknown, fallback = false) {
  if (typeof v === "boolean") return v
  if (typeof v === "string") return v.toLowerCase() === "true"
  return fallback
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

    const body = await req.json()
    const eventId = toText(body?.event_id)
    const accept = toBool(body?.accept, false)
    if (!eventId) return json(400, { success: false, error: "Missing event_id" })

    const supabase = createClient(supabaseUrl, serviceRole)
    const payload = await acceptOrDismissDailyEvent(supabase, authData.user.id, eventId, accept)
    return json(200, { success: true, ...payload })
  } catch (error) {
    return json(500, { success: false, error: error instanceof Error ? error.message : String(error) })
  }
})
