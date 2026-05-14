import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders, toText, toBool, json } from "../_shared/http.ts"
import { acceptOrDismissDailyEvent } from "../_shared/guide_engine.ts"

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
    const clientContext =
      body?.client_context && typeof body.client_context === "object" && !Array.isArray(body.client_context)
        ? body.client_context as Record<string, unknown>
        : undefined
    const payload = await acceptOrDismissDailyEvent(
      supabase,
      authData.user.id,
      eventId,
      accept,
      clientContext,
    )
    return json(200, { success: true, ...payload })
  } catch (error) {
    return json(500, { success: false, error: error instanceof Error ? error.message : String(error) })
  }
})
