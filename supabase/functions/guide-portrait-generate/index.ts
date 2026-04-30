import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { gatherGuideMemoryBundle } from "../_shared/guide_memory.ts";
import { currentIsoWeek } from "./helpers.ts";

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
  prevSummary?: string | null,
) {
  const recent = memory.recent_context.slice(0, 4).join(" | ");
  const callbacks = memory.long_term_callbacks.slice(0, 3).join(" | ");
  const signals = memory.behavior_signals.slice(0, 3).join(" | ");

  // 基础画像 prompt
  const parts = [
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
  ];

  // 注入上一张画像的 summary，帮助 LLM 描述用户变化
  if (prevSummary) {
    parts.push(`Previous portrait summary: ${prevSummary}. Describe changes since then.`);
  } else {
    parts.push("This is the user's first portrait.");
  }

  return parts.join(" ");
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
  // 已弃用 Pollinations，改用 OpenAI Images API
  // 保留此函数签名仅为兼容，实际生成在 generateImageViaOpenAI 中完成
  return "";
}

/**
 * 调用 OpenAI 兼容的 Images API 生成画像。
 * 按优先级尝试 gpt-image-2 → gpt-image-1 → dall-e-3，
 * 全部失败则降级到 Pollinations 免费 API。
 * 使用独立的 OPENAI_IMAGE_API_KEY 和 OPENAI_IMAGE_BASE_URL，与对话 key 隔离。
 */
async function generateImageViaOpenAI(prompt: string): Promise<{ b64_json: string; url: string; model: string }> {
  // 图像生成使用独立的 key，与对话 key 隔离
  const apiKey = Deno.env.get("OPENAI_IMAGE_API_KEY") ?? Deno.env.get("OPENAI_API_KEY") ?? "";
  if (!apiKey) throw new Error("Missing OPENAI_IMAGE_API_KEY env");

  const baseUrl = (Deno.env.get("OPENAI_IMAGE_BASE_URL") ?? "https://gpt.mycloudpartners.com")
    .replace(/\/+$/, "");
  const apiBase = baseUrl.endsWith("/v1") ? baseUrl : `${baseUrl}/v1`;

  const models = ["gpt-image-2", "gpt-image-1", "dall-e-3"];
  let lastError = "";

  for (const model of models) {
    try {
      const resp = await fetch(`${apiBase}/images/generations`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model,
          prompt: prompt.slice(0, 4000),
          n: 1,
          size: "1024x1024",
          ...(model.startsWith("gpt-image") ? { quality: "medium" } : {}),
        }),
        signal: AbortSignal.timeout(120_000),
      });

      if (!resp.ok) {
        const raw = await resp.text().catch(() => "");
        lastError = `${model}: ${resp.status} ${raw.slice(0, 200)}`;
        console.warn(`generateImage ${model} failed:`, lastError);
        continue;
      }

      const data = await resp.json();
      const items = Array.isArray(data?.data) ? data.data : [];
      const b64 = items[0]?.b64_json ?? "";
      const url = items[0]?.url ?? "";
      if (!b64 && !url) {
        lastError = `${model}: empty result`;
        continue;
      }
      console.log(`generateImage succeeded with model=${model}`);
      return { b64_json: b64, url, model };
    } catch (err) {
      lastError = `${model}: ${err instanceof Error ? err.message : String(err)}`;
      console.warn(`generateImage ${model} error:`, lastError);
    }
  }

  // 全部失败，降级到 Pollinations
  console.warn("All OpenAI image models failed, falling back to Pollinations");
  const pollinationsToken = Deno.env.get("POLLINATIONS_API_KEY") ?? "";
  const pollinationsModel = Deno.env.get("POLLINATIONS_MODEL") ?? "flux";
  const seed = Math.floor(Math.random() * 2147483647);
  const query = new URLSearchParams({
    model: pollinationsModel,
    width: "1024",
    height: "1024",
    seed: String(seed),
    nologo: "true",
    safe: "true",
    enhance: "true",
  });
  if (pollinationsToken) query.set("token", pollinationsToken);
  const encodedPrompt = encodeURIComponent(prompt.slice(0, 2000));
  const pollinationsUrl = `https://image.pollinations.ai/prompt/${encodedPrompt}?${query.toString()}`;

  const polResp = await fetch(pollinationsUrl, {
    method: "GET",
    headers: { Accept: "image/*" },
    signal: AbortSignal.timeout(60_000),
  });
  if (!polResp.ok) {
    throw new Error(`All image generation failed. Last error: ${lastError}. Pollinations: ${polResp.status}`);
  }
  const finalUrl = polResp.url || pollinationsUrl;
  return { b64_json: "", url: finalUrl, model: `pollinations:${pollinationsModel}` };
}

/**
 * 把 base64 图片上传到 Supabase Storage，返回公开 URL。
 * 如果输入已经是 URL，直接返回。
 */
async function uploadPortraitToStorage(
  supabase: any,
  userId: string,
  imageData: { b64_json: string; url: string },
  style: string,
): Promise<string> {
  // 如果有 URL 直接用（DALL-E 3 或 Pollinations 返回的）
  if (imageData.url) return imageData.url;
  // 如果有 b64_json，上传到 Storage
  if (!imageData.b64_json) throw new Error("No image data to upload");

  const bytes = Uint8Array.from(atob(imageData.b64_json), (c) => c.charCodeAt(0));
  const fileName = `portraits/${userId}/${style}-${Date.now()}.png`;

  const { error } = await supabase.storage
    .from("guide-assets")
    .upload(fileName, bytes, {
      contentType: "image/png",
      upsert: true,
    });
  if (error) {
    if (error.message?.includes("not found") || error.statusCode === 404) {
      await supabase.storage.createBucket("guide-assets", { public: true });
      const { error: retryError } = await supabase.storage
        .from("guide-assets")
        .upload(fileName, bytes, {
          contentType: "image/png",
          upsert: true,
        });
      if (retryError) throw retryError;
    } else {
      throw error;
    }
  }

  const { data: urlData } = supabase.storage
    .from("guide-assets")
    .getPublicUrl(fileName);
  return urlData?.publicUrl ?? "";
}

async function touchImage(url: string) {
  return url;
}

/** 将错误转为可读字符串 */
function toErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}

/**
 * 查询指定用户上一张画像的 summary（不同 epoch 中最新的一张）。
 * 无上一张画像时返回 null。
 */
async function fetchPreviousPortraitSummary(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  currentEpoch: string,
): Promise<string | null> {
  try {
    const { data } = await supabase
      .from("guide_portraits")
      .select("summary,epoch")
      .eq("user_id", userId)
      .neq("epoch", currentEpoch)
      .order("epoch", { ascending: false })
      .limit(1)
      .maybeSingle();
    return data?.summary ?? null;
  } catch (err) {
    // 查询失败视为首张画像，不阻塞生成流程
    console.warn(`fetchPreviousPortraitSummary failed for user=${userId}:`, toErrorMessage(err));
    return null;
  }
}

/**
 * 为单个用户生成画像。
 * 包含 epoch 计算、上一张画像注入、upsert 逻辑。
 * 生成失败时记录错误日志，不写入空白记录。
 */
async function generatePortraitForUser(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  options: {
    scene: string;
    style: string;
    isEnglish: boolean;
    forceRefresh: boolean;
  },
): Promise<{
  success: boolean;
  data?: Record<string, unknown>;
  error?: string;
}> {
  const { scene, style, isEnglish, forceRefresh } = options;
  const epoch = currentIsoWeek();

  // 非强制刷新时，查询同 epoch 是否已有画像，有则直接返回缓存
  if (!forceRefresh) {
    const { data: existingPortrait } = await supabase
      .from("guide_portraits")
      .select("image_url,model,seed,style,summary,memory_refs,epoch")
      .eq("user_id", userId)
      .eq("epoch", epoch)
      .eq("style", style)
      .limit(1)
      .maybeSingle();
    if (existingPortrait) {
      return {
        success: true,
        data: {
          image_url: existingPortrait.image_url,
          model: existingPortrait.model,
          seed: existingPortrait.seed,
          style: existingPortrait.style,
          summary: existingPortrait.summary,
          memory_refs: existingPortrait.memory_refs ?? [],
          epoch: existingPortrait.epoch,
          trace_id: crypto.randomUUID(),
          cached: true,
        },
      };
    }
  }

  // 收集记忆上下文
  const memory = await gatherGuideMemoryBundle(supabase, userId, {
    scene,
    userMessage: `portrait:${style}`,
    maxRawItems: 60,
    maxPackedChars: 14000,
  });

  // 查询上一张画像的 summary 注入 prompt
  const prevSummary = await fetchPreviousPortraitSummary(supabase, userId, epoch);
  const prompt = buildPrompt(memory, style, prevSummary);
  const summary = buildSummary(memory, isEnglish);
  const seed = Math.floor(Math.random() * 2147483647);

  // 调用图像生成 API（失败时抛出异常，由调用方捕获）
  let imageResult: { b64_json: string; url: string; model: string };
  try {
    imageResult = await generateImageViaOpenAI(prompt);
  } catch (err) {
    // 画像生成失败：记录错误日志，不写入空白记录
    console.error(`generatePortraitForUser image generation failed for user=${userId}:`, toErrorMessage(err));
    return { success: false, error: toErrorMessage(err) };
  }

  // 上传图片到 Storage
  let resolvedImageUrl: string;
  try {
    resolvedImageUrl = await uploadPortraitToStorage(supabase, userId, imageResult, style);
  } catch (err) {
    console.error(`generatePortraitForUser upload failed for user=${userId}:`, toErrorMessage(err));
    return { success: false, error: toErrorMessage(err) };
  }

  // 使用 upsert 写入画像记录：同 (user_id, epoch) 覆盖旧记录
  const upsertPayload = {
    user_id: userId,
    style,
    prompt,
    summary,
    image_url: resolvedImageUrl,
    model: imageResult.model,
    seed,
    memory_refs: memory.memory_refs.slice(0, 120),
    epoch,
  };

  const { error: upsertError } = await supabase
    .from("guide_portraits")
    .upsert(upsertPayload, {
      onConflict: "user_id,epoch",
      ignoreDuplicates: false,
    });

  if (upsertError) {
    console.error(`generatePortraitForUser upsert failed for user=${userId}:`, upsertError.message);
    return { success: false, error: upsertError.message };
  }

  return {
    success: true,
    data: {
      image_url: resolvedImageUrl,
      model: imageResult.model,
      seed,
      style,
      summary,
      memory_refs: memory.memory_refs.slice(0, 120),
      epoch,
      trace_id: crypto.randomUUID(),
    },
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { success: false, error: "Method Not Allowed" });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !supabaseAnonKey || !serviceRole) {
      throw new Error("Missing SUPABASE env");
    }

    let body: Record<string, unknown> = {};
    try {
      body = await req.json();
    } catch {
      body = {};
    }

    const batchMode = toBool(body.batch_mode, false);
    const scene = toText(body.scene) || "profile";
    const style = toText(body.style) || "pencil_sketch";
    const forceRefresh = toBool(body.force_refresh, false);
    const languageCode = toText(body.language_code).toLowerCase();
    const isEnglish = body.is_english === true || languageCode.startsWith("en");

    const supabase = createClient(supabaseUrl, serviceRole);

    // ── 批量模式：遍历活跃用户逐一生成 ──
    if (batchMode) {
      const sevenDaysAgo = new Date(Date.now() - 7 * 86400_000)
        .toISOString()
        .slice(0, 10);
      const { data: activeLogs } = await supabase
        .from("daily_logs")
        .select("user_id")
        .gte("date_id", sevenDaysAgo)
        .limit(500);

      const userIds = activeLogs && activeLogs.length > 0
        ? [...new Set((activeLogs as Array<{ user_id: string }>).map((r) => r.user_id))]
        : [];

      if (userIds.length === 0) {
        return json(200, { success: true, processed: 0, errors: [] });
      }

      // 逐用户串行生成，单用户失败不影响其他用户
      const errors: string[] = [];
      let processed = 0;

      for (const userId of userIds) {
        const result = await generatePortraitForUser(supabase, userId, {
          scene,
          style,
          isEnglish,
          forceRefresh,
        });
        if (result.success) {
          processed++;
        } else {
          errors.push(`${userId}: ${result.error}`);
        }
      }

      console.log(
        `guide-portrait-generate batch done: total=${userIds.length} processed=${processed} errors=${errors.length}`,
      );

      return json(200, { success: true, processed, errors });
    }

    // ── 单用户模式：需要 JWT 认证 ──
    const authHeader = req.headers.get("Authorization") ?? "";
    const accessToken = authHeader.replace("Bearer", "").trim();
    if (!accessToken) {
      return json(401, { success: false, error: "Missing bearer token" });
    }

    const authClient = createClient(supabaseUrl, supabaseAnonKey);
    const { data: authData, error: authError } = await authClient.auth.getUser(
      accessToken,
    );
    if (authError || !authData.user) {
      return json(401, { success: false, error: "Invalid JWT" });
    }

    const result = await generatePortraitForUser(supabase, authData.user.id, {
      scene,
      style,
      isEnglish,
      forceRefresh,
    });

    if (!result.success) {
      return json(500, { success: false, error: result.error });
    }

    return json(200, { success: true, ...result.data });
  } catch (error) {
    return json(500, {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    });
  }
});
