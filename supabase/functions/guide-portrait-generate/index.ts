import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { gatherGuideMemoryBundle } from "../_shared/guide_memory.ts";
import { resolveAccessibleImageUrl } from "./helpers.ts";

function toText(v: unknown) {
  if (typeof v === "string") return v.trim();
  if (v == null) return "";
  return String(v).trim();
}

function toBool(v: unknown, fallback = false) {
  if (typeof v === "boolean") return v;
  if (typeof v === "string") {
    const lowered = v.trim().toLowerCase();
    if (lowered === "true") return true;
    if (lowered === "false") return false;
  }
  return fallback;
}

function json(status: number, data: unknown) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function stylePrompt(style: string) {
  switch (style) {
    case "charcoal":
      return "charcoal sketch, high contrast, expressive line work";
    case "ink":
      return "ink illustration, clean lineart, monochrome style";
    case "watercolor":
      return "soft watercolor portrait, natural tones, textured paper";
    case "cinematic":
      return "cinematic portrait, dramatic light, realistic details";
    case "pencil_sketch":
    default:
      return "pencil sketch portrait, graphite texture, hand-drawn details";
  }
}

function buildPrompt(
  memory: {
    recent_context: string[];
    long_term_callbacks: string[];
    behavior_signals: string[];
  },
  style: string,
) {
  const recent = memory.recent_context.slice(0, 4).join(" | ");
  const callbacks = memory.long_term_callbacks.slice(0, 3).join(" | ");
  const signals = memory.behavior_signals.slice(0, 3).join(" | ");

  return [
    "Portrait of a determined earth explorer, age-neutral adult, half-body, looking confident and calm.",
    `Visual style: ${stylePrompt(style)}.`,
    "Outfit hints: practical jacket, expedition notebook, subtle quest-themed accessories.",
    "Mood: warm, resilient, thoughtful.",
    "Background: minimal environmental textures, no text overlays.",
    "DO NOT render any words, logos, UI, watermark, or signature.",
    `Recent memory cues: ${recent || "steady progress in daily quests"}.`,
    `Long-term callbacks: ${
      callbacks || "building long-term discipline and recovery rhythm"
    }.`,
    `Behavior signals: ${signals || "balanced momentum and recovery"}.`,
  ].join(" ");
}

function buildSummary(memory: {
  behavior_signals: string[];
  recent_context: string[];
  long_term_callbacks: string[];
}, isEnglish: boolean) {
  const signal = memory.behavior_signals[0] ||
    (isEnglish ? "Your rhythm has been moving forward steadily." : "近期节奏稳步推进");
  const recent = memory.recent_context[0] ||
    (isEnglish ? "You kept taking action today." : "今天有持续行动");
  const callback = memory.long_term_callbacks[0] ||
    (isEnglish ? "Long-term habits are taking shape." : "长期习惯正在形成");
  return isEnglish
    ? `Portrait cues: ${signal}; ${recent}; ${callback}.`
    : `画像依据：${signal}；${recent}；${callback}。`;
}

function buildImageUrl(input: {
  prompt: string;
  model: string;
  seed: number;
  token: string;
}) {
  const query = new URLSearchParams({
    model: input.model,
    width: "1024",
    height: "1024",
    seed: String(input.seed),
    nologo: "true",
    safe: "true",
    private: "true",
    enhance: "true",
  });
  if (input.token) {
    query.set("token", input.token);
  }
  const encodedPrompt = encodeURIComponent(input.prompt.slice(0, 2000));
  return `https://image.pollinations.ai/prompt/${encodedPrompt}?${query.toString()}`;
}

async function touchImage(url: string) {
  const resp = await fetch(url, {
    method: "GET",
    headers: { Accept: "image/*" },
  });
  if (!resp.ok) {
    const raw = await resp.text().catch(() => "");
    throw new Error(
      `Pollinations request failed: status=${resp.status} body=${raw}`,
    );
  }
  return resp.url || url;
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
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !supabaseAnonKey || !serviceRole) {
      throw new Error("Missing SUPABASE env");
    }

    const authClient = createClient(supabaseUrl, supabaseAnonKey);
    const { data: authData, error: authError } = await authClient.auth.getUser(
      accessToken,
    );
    if (authError || !authData.user) {
      return json(401, { success: false, error: "Invalid JWT" });
    }

    let body: Record<string, unknown> = {};
    try {
      body = await req.json();
    } catch {
      body = {};
    }

    const scene = toText(body.scene) || "profile";
    const style = toText(body.style) || "pencil_sketch";
    const forceRefresh = toBool(body.force_refresh, true);
    const languageCode = toText(body.language_code).toLowerCase();
    const isEnglish = body.is_english === true || languageCode.startsWith("en");
    const model = toText(Deno.env.get("POLLINATIONS_MODEL")) || "flux";
    const token = toText(Deno.env.get("POLLINATIONS_API_KEY"));

    const supabase = createClient(supabaseUrl, serviceRole);

    if (!forceRefresh) {
      const { data: latest } = await supabase
        .from("guide_portraits")
        .select("image_url,model,seed,style,summary,memory_refs")
        .eq("user_id", authData.user.id)
        .eq("style", style)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (latest) {
        return json(200, {
          success: true,
          image_url: latest.image_url,
          model: latest.model,
          seed: latest.seed,
          style: latest.style,
          summary: latest.summary,
          memory_refs: latest.memory_refs ?? [],
          trace_id: crypto.randomUUID(),
        });
      }
    }

    const memory = await gatherGuideMemoryBundle(supabase, authData.user.id, {
      scene,
      userMessage: `portrait:${style}`,
      maxRawItems: 60,
      maxPackedChars: 14000,
    });

    const prompt = buildPrompt(memory, style);
    const summary = buildSummary(memory, isEnglish);
    const seed = Math.floor(Math.random() * 2147483647);
    const imageUrl = buildImageUrl({
      prompt,
      model,
      seed,
      token,
    });
    const resolvedImageUrl = await resolveAccessibleImageUrl(
      imageUrl,
      touchImage,
    );

    const insertPayload = {
      user_id: authData.user.id,
      style,
      prompt,
      summary,
      image_url: resolvedImageUrl,
      model,
      seed,
      memory_refs: memory.memory_refs.slice(0, 120),
    };

    await supabase.from("guide_portraits").insert(insertPayload);

    return json(200, {
      success: true,
      image_url: resolvedImageUrl,
      model,
      seed,
      style,
      summary,
      memory_refs: memory.memory_refs.slice(0, 120),
      trace_id: crypto.randomUUID(),
    });
  } catch (error) {
    return json(500, {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    });
  }
});
