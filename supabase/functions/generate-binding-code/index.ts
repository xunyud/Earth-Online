import { serve } from "std/http/server.ts";
import { createClient } from "@supabase/supabase-js";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseKey);

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response("Missing Authorization header", { status: 401 });
    }

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));

    if (authError || !user) {
      return new Response("Unauthorized", { status: 401 });
    }

    // Generate 6-char alphanumeric code (A-Z, 0-9)
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    let bindingCode = "";
    for (let i = 0; i < 6; i++) {
      bindingCode += chars.charAt(Math.floor(Math.random() * chars.length));
    }

    // Set expiration to 15 minutes from now
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();

    const { error: updateError } = await supabase
      .from("profiles")
      .update({
        binding_code: bindingCode,
        binding_expires_at: expiresAt,
      })
      .eq("id", user.id);

    if (updateError) {
      console.error("Update Error", updateError);
      return new Response(JSON.stringify({ error: "Failed to generate code" }), { status: 500 });
    }

    return new Response(JSON.stringify({ code: bindingCode, expires_at: expiresAt }), {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
      status: 200,
    });
  } catch (error) {
    console.error(error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});
