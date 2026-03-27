import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import {
  acceptLatestSuggestedTask,
  buildGuideChatPayload,
} from "../_shared/guide_engine.ts";
import {
  formatWechatGuideReply,
  parseBoundWechatMessage,
} from "../_shared/wechat_agent.ts";

function escapeXmlText(input: string) {
  return input
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function formatPostgrestError(err: any) {
  if (!err) return "";
  const code = err.code ? `code=${err.code}` : "";
  const msg = err.message ? `message=${err.message}` : String(err);
  const details = err.details ? `details=${err.details}` : "";
  const hint = err.hint ? `hint=${err.hint}` : "";
  return [code, msg, details, hint].filter(Boolean).join(" | ");
}

type InsertResult = { ok: true; id: string } | { ok: false; error: any };

function isFourDigits(content: string) {
  return /^\d{4}$/.test(content);
}

async function insertQuestNodeWithFallbacks(
  supabase: any,
  base: Record<string, unknown>,
): Promise<InsertResult> {
  const baseWithDefaults: Record<string, unknown> = {
    description: "",
    due_date: null,
    completed_at: null,
    original_context: [],
    xp_reward: 0,
    is_completed: false,
    is_deleted: false,
    is_expanded: true,
    is_reward: false,
    ...base,
  };

  const variants: Array<Record<string, unknown>> = [
    { ...baseWithDefaults, node_type: "task" },
    baseWithDefaults,
    (() => {
      const { xp_reward, ...rest } = baseWithDefaults;
      return { ...rest, exp: xp_reward, node_type: "task" };
    })(),
    (() => {
      const { xp_reward, ...rest } = baseWithDefaults;
      return { ...rest, exp: xp_reward };
    })(),
  ];

  let lastErr: any = null;
  for (const payload of variants) {
    const { data, error } = await supabase
      .from("quest_nodes")
      .insert(payload)
      .select("id")
      .single();
    if (!error) {
      const id = (data as any)?.id;
      if (typeof id === "string" && id) return { ok: true, id };
      return { ok: true, id: String(id ?? "") };
    }
    lastErr = error;
  }
  return { ok: false, error: lastErr };
}

async function updateQuestNodeWithFallbacks(
  supabase: any,
  questId: string,
  updates: Record<string, unknown>,
): Promise<void> {
  const variants: Array<Record<string, unknown>> = [
    updates,
    (() => {
      const { xp_reward, ...rest } = updates as any;
      if (xp_reward === undefined) return updates;
      return { ...rest, exp: xp_reward };
    })(),
  ];

  let lastErr: any = null;
  for (const payload of variants) {
    const { error } = await supabase.from("quest_nodes").update(payload).eq(
      "id",
      questId,
    );
    if (!error) return;
    lastErr = error;
  }
  throw lastErr ?? new Error("Failed to update quest node");
}

function scheduleBackground(task: Promise<unknown>) {
  const edgeRuntime = (globalThis as any).EdgeRuntime;
  if (edgeRuntime?.waitUntil) {
    edgeRuntime.waitUntil(task);
    return;
  }
  task.catch((error) => console.error(error));
}

async function handleTaskCapture(
  supabase: any,
  userId: string,
  text: string,
) {
  const sortOrder = -Date.now();
  const insertRes = await insertQuestNodeWithFallbacks(supabase, {
    user_id: userId,
    parent_id: null,
    title: text,
    quest_tier: "Main_Quest",
    sort_order: sortOrder,
    xp_reward: 0,
    description: "",
  });

  if (!insertRes.ok || !insertRes.id) {
    return `记录失败：${
      formatPostgrestError(insertRes.ok ? null : insertRes.error)
    }`;
  }

  const placeholderId = insertRes.id;
  scheduleBackground((async () => {
    const { data, error } = await supabase.functions.invoke("parse-quest", {
      body: { text, user_id: userId },
    });

    if (error || !data) {
      console.error("parse-quest error:", formatPostgrestError(error));
      return;
    }

    const tasksRaw = Array.isArray((data as any).tasks)
      ? (data as any).tasks
      : [];
    if (tasksRaw.length === 0) return;

    const cheerRaw = typeof (data as any).cheer === "string"
      ? (data as any).cheer.trim()
      : "";
    const cheer = cheerRaw && cheerRaw.length <= 200 ? cheerRaw : "";

    const tasks: Array<{
      title: string;
      parent_index: number | null;
      xpReward: number;
    }> = [];
    for (let i = 0; i < tasksRaw.length; i++) {
      const item = tasksRaw[i] ?? {};
      const title = typeof item.title === "string" ? item.title.trim() : "";
      if (!title) continue;
      const parentIndex = Number.isInteger(item.parent_index)
        ? item.parent_index
        : null;
      const xpReward = Number.isFinite(item.xpReward)
        ? Math.round(item.xpReward)
        : 0;
      tasks.push({ title, parent_index: parentIndex, xpReward });
    }
    if (tasks.length === 0) return;

    const idByIndex = new Map<number, string>();
    const rootSortBase = -Date.now();
    idByIndex.set(0, placeholderId);

    const first = tasks[0];
    await updateQuestNodeWithFallbacks(supabase, placeholderId, {
      title: first.title,
      xp_reward: first.xpReward,
      description: cheer || "",
      due_date: null,
      completed_at: null,
      quest_tier: "Main_Quest",
      parent_id: null,
      sort_order: rootSortBase,
      is_deleted: false,
      is_expanded: true,
      is_completed: false,
      is_reward: false,
    });

    for (let i = 1; i < tasks.length; i++) {
      idByIndex.set(i, crypto.randomUUID());
    }

    const roots: Array<Record<string, unknown>> = [];
    const children: Array<Record<string, unknown>> = [];

    for (let i = 1; i < tasks.length; i++) {
      const task = tasks[i];
      const id = idByIndex.get(i)!;
      const parentId = task.parent_index != null
        ? idByIndex.get(task.parent_index) ?? null
        : null;
      const row: Record<string, unknown> = {
        id,
        user_id: userId,
        parent_id: parentId,
        title: task.title,
        quest_tier: parentId == null ? "Main_Quest" : "Side_Quest",
        sort_order: rootSortBase + i,
        xp_reward: task.xpReward,
        description: "",
        due_date: null,
        completed_at: null,
        original_context: [],
        is_completed: false,
        is_deleted: false,
        is_expanded: true,
        is_reward: false,
      };
      if (parentId == null) roots.push(row);
      else children.push(row);
    }

    const tryRows = async (rows: Array<Record<string, unknown>>) => {
      if (rows.length === 0) return null;
      const withNodeType = rows.map((row) => ({ ...row, node_type: "task" }));
      const { error: firstError } = await supabase.from("quest_nodes").insert(
        withNodeType,
      );
      if (!firstError) return null;
      const { error: secondError } = await supabase.from("quest_nodes").insert(
        rows,
      );
      return secondError ?? firstError;
    };

    const rootsError = await tryRows(roots);
    if (rootsError) {
      console.error("insert roots error:", formatPostgrestError(rootsError));
    }
    const childrenError = await tryRows(children);
    if (childrenError) {
      console.error(
        "insert children error:",
        formatPostgrestError(childrenError),
      );
    }

    try {
      await supabase.rpc("check_and_unlock_achievements", {
        p_user_id: userId,
        p_category: "special",
      });
    } catch (error) {
      console.error("achievement check error:", error);
    }
  })());

  return `✅ 任务已收到，正在由 AI 解析中...（id: ${placeholderId}）`;
}

async function handleBoundWechatMessage(
  supabase: any,
  userId: string,
  content: string,
) {
  if (isFourDigits(content)) {
    return "你的账号已经绑定成功啦！直接发文字就可以记录为任务。";
  }

  const parsedMessage = parseBoundWechatMessage(content);
  if (parsedMessage.kind === "empty") {
    return `如果要记任务，直接发内容就可以。如果想聊天，请发送\u201C问村长：...\u201D`;
  }

  if (parsedMessage.kind === "accept_suggestion") {
    const result = await acceptLatestSuggestedTask(supabase, userId, "wechat");
    if (result.accepted && result.task) {
      return `✅ 已帮你创建任务：${result.task.title}`;
    }
    return `暂时没有可以收下的建议任务，先发\u201C问村长：...\u201D和我聊聊吧。`;
  }

  if (parsedMessage.kind === "guide_chat") {
    try {
      const guidePayload = await buildGuideChatPayload(
        supabase,
        userId,
        "wechat",
        parsedMessage.message,
        { channel: "wechat", source: "wechat-webhook" },
      );
      return formatWechatGuideReply(
        guidePayload.guide_display_name,
        guidePayload.reply,
        guidePayload.suggested_task,
      );
    } catch (error) {
      console.error("wechat guide chat error:", error);
      return "村长刚刚离开去翻记忆了，稍后再试试吧。";
    }
  }

  return await handleTaskCapture(supabase, userId, parsedMessage.text);
}

serve(async (req) => {
  const url = new URL(req.url);

  if (req.method === "GET") {
    const echostr = url.searchParams.get("echostr");
    if (echostr) {
      return new Response(echostr, { status: 200 });
    }
    return new Response("Invalid Request", { status: 400 });
  }

  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const xmlString = await req.text();
  const fromUserNameMatch = xmlString.match(
    /<FromUserName><!\[CDATA\[(.*?)\]\]><\/FromUserName>/,
  );
  const contentMatch = xmlString.match(
    /<Content><!\[CDATA\[(.*?)\]\]><\/Content>/,
  );
  const toUserNameMatch = xmlString.match(
    /<ToUserName><!\[CDATA\[(.*?)\]\]><\/ToUserName>/,
  );

  if (!fromUserNameMatch || !contentMatch) {
    return new Response("success", { status: 200 });
  }

  const openId = fromUserNameMatch[1];
  const content = contentMatch[1].trim();
  const myWechatId = toUserNameMatch ? toUserNameMatch[1] : "";

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, supabaseKey);

  let replyText = "收到消息";

  const { data: profile, error: profileErr } = await supabase
    .from("profiles")
    .select("id,wechat_openid")
    .eq("wechat_openid", openId)
    .maybeSingle();

  if (!profileErr && profile?.id) {
    supabase
      .from("profiles")
      .update({ last_wechat_interaction: new Date().toISOString() })
      .eq("id", profile.id)
      .then(({ error }: any) => {
        if (error) {
          console.error("update last_wechat_interaction:", error.message);
        }
      });

    replyText = await handleBoundWechatMessage(supabase, profile.id, content);
  } else if (isFourDigits(content)) {
    const { data: bindRecord, error } = await supabase
      .from("wechat_bind_codes")
      .select("user_id, expires_at")
      .eq("code", content)
      .single();

    if (error || !bindRecord) {
      replyText = "验证码无效，请在 App 中重新生成。";
    } else if (new Date(bindRecord.expires_at) < new Date()) {
      replyText = "验证码已过期，请在 App 中重新生成。";
    } else {
      await supabase
        .from("profiles")
        .update({
          wechat_openid: openId,
          last_wechat_interaction: new Date().toISOString(),
        })
        .eq("id", bindRecord.user_id);

      await supabase
        .from("wechat_bind_codes")
        .delete()
        .eq("code", content);

      replyText =
        "🎉 绑定成功！以后你在这里发的消息，都会自动同步到 App 里变成任务啦！";
    }
  } else {
    replyText = "欢迎！如需绑定账号，请发送 App 中的 4 位验证码。";
  }

  const now = Math.floor(Date.now() / 1000);
  const xmlResponse = `
      <xml>
        <ToUserName><![CDATA[${openId}]]></ToUserName>
        <FromUserName><![CDATA[${myWechatId}]]></FromUserName>
        <CreateTime>${now}</CreateTime>
        <MsgType><![CDATA[text]]></MsgType>
        <Content><![CDATA[${escapeXmlText(replyText)}]]></Content>
      </xml>
    `;

  return new Response(xmlResponse, {
    headers: { "Content-Type": "application/xml" },
    status: 200,
  });
});
