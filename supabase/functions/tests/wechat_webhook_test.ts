// supabase/functions/tests/wechat_webhook_test.ts
// 测试 wechat-webhook 中的纯函数：XML 解析、验证、转义、fallback insert/update

import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

// ── 从 wechat-webhook 提取的纯函数（内联复制以避免 import Deno.serve 依赖）──

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

function isFourDigits(content: string) {
  return /^\d{4}$/.test(content);
}

// ── XML 解析逻辑（复制自 handler）──

function parseWechatXml(xmlString: string) {
  const fromUserNameMatch = xmlString.match(
    /<FromUserName><!\[CDATA\[(.*?)\]\]><\/FromUserName>/,
  );
  const contentMatch = xmlString.match(
    /<Content><!\[CDATA\[(.*?)\]\]><\/Content>/,
  );
  const toUserNameMatch = xmlString.match(
    /<ToUserName><!\[CDATA\[(.*?)\]\]><\/ToUserName>/,
  );
  return {
    openId: fromUserNameMatch?.[1] ?? null,
    content: contentMatch?.[1]?.trim() ?? null,
    toUserName: toUserNameMatch?.[1] ?? null,
  };
}

// ── insertQuestNodeWithFallbacks 逻辑 ──

type InsertResult = { ok: true; id: string } | { ok: false; error: any };

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

// ═══════════════ 测试 ═══════════════

Deno.test("escapeXmlText escapes all XML special characters", () => {
  assertEquals(escapeXmlText("a&b"), "a&amp;b");
  assertEquals(escapeXmlText("<tag>"), "&lt;tag&gt;");
  assertEquals(escapeXmlText('"hello\''), "&quot;hello&apos;");
  assertEquals(escapeXmlText("no special"), "no special");
  assertEquals(escapeXmlText("&<>'\""), "&amp;&lt;&gt;&apos;&quot;");
});

Deno.test("isFourDigits validates exactly 4-digit strings", () => {
  assertEquals(isFourDigits("1234"), true);
  assertEquals(isFourDigits("0000"), true);
  assertEquals(isFourDigits("123"), false);
  assertEquals(isFourDigits("12345"), false);
  assertEquals(isFourDigits("abcd"), false);
  assertEquals(isFourDigits(""), false);
  assertEquals(isFourDigits("12 4"), false);
});

Deno.test("formatPostgrestError builds structured error string", () => {
  assertEquals(formatPostgrestError(null), "");
  assertEquals(formatPostgrestError(undefined), "");

  const err = {
    code: "23505",
    message: "duplicate key",
    details: "Key (id)=(1) already exists",
    hint: "use upsert",
  };
  const result = formatPostgrestError(err);
  assertEquals(result.includes("code=23505"), true);
  assertEquals(result.includes("message=duplicate key"), true);
  assertEquals(result.includes("details=Key"), true);
  assertEquals(result.includes("hint=use upsert"), true);
});

Deno.test("formatPostgrestError handles partial error objects", () => {
  const result = formatPostgrestError({ message: "something broke" });
  assertEquals(result, "message=something broke");

  // When message is missing, falls back to String(err) for the msg part
  const noMsg = formatPostgrestError({ code: "42P01" });
  assertEquals(noMsg.includes("code=42P01"), true);
});

Deno.test("parseWechatXml extracts CDATA fields from WeChat XML", () => {
  const xml = `<xml>
    <ToUserName><![CDATA[gh_abc]]></ToUserName>
    <FromUserName><![CDATA[oUser123]]></FromUserName>
    <CreateTime>1234567890</CreateTime>
    <MsgType><![CDATA[text]]></MsgType>
    <Content><![CDATA[Hello World]]></Content>
  </xml>`;

  const result = parseWechatXml(xml);
  assertEquals(result.openId, "oUser123");
  assertEquals(result.content, "Hello World");
  assertEquals(result.toUserName, "gh_abc");
});

Deno.test("parseWechatXml returns null for missing fields", () => {
  const result = parseWechatXml("<xml></xml>");
  assertEquals(result.openId, null);
  assertEquals(result.content, null);
  assertEquals(result.toUserName, null);
});

Deno.test("parseWechatXml trims content whitespace", () => {
  const xml = `<xml>
    <FromUserName><![CDATA[u1]]></FromUserName>
    <Content><![CDATA[  spaces  ]]></Content>
  </xml>`;
  const result = parseWechatXml(xml);
  assertEquals(result.content, "spaces");
});

Deno.test("insertQuestNodeWithFallbacks succeeds on first variant", async () => {
  let insertCalls = 0;
  const mockSupabase = {
    from: () => ({
      insert: (payload: any) => {
        insertCalls++;
        return {
          select: () => ({
            single: () => Promise.resolve({ data: { id: "abc-123" }, error: null }),
          }),
        };
      },
    }),
  };

  const result = await insertQuestNodeWithFallbacks(mockSupabase, {
    user_id: "u1",
    title: "test",
  });
  assertEquals(result.ok, true);
  if (result.ok) assertEquals(result.id, "abc-123");
  assertEquals(insertCalls, 1);
});

Deno.test("insertQuestNodeWithFallbacks retries with exp fallback", async () => {
  let insertCalls = 0;
  let lastPayload: any;
  const mockSupabase = {
    from: () => ({
      insert: (payload: any) => {
        insertCalls++;
        lastPayload = payload;
        // First two calls fail (node_type issue), third succeeds
        if (insertCalls <= 2) {
          return {
            select: () => ({
              single: () => Promise.resolve({ data: null, error: { code: "42703", message: "column does not exist" } }),
            }),
          };
        }
        return {
          select: () => ({
            single: () => Promise.resolve({ data: { id: "retry-id" }, error: null }),
          }),
        };
      },
    }),
  };

  const result = await insertQuestNodeWithFallbacks(mockSupabase, {
    user_id: "u1",
    title: "retry test",
  });
  assertEquals(result.ok, true);
  assertEquals(insertCalls, 3);
});

Deno.test("insertQuestNodeWithFallbacks returns error after all variants fail", async () => {
  const mockSupabase = {
    from: () => ({
      insert: () => ({
        select: () => ({
          single: () => Promise.resolve({ data: null, error: { code: "P0001", message: "fatal" } }),
        }),
      }),
    }),
  };

  const result = await insertQuestNodeWithFallbacks(mockSupabase, {
    user_id: "u1",
    title: "fail",
  });
  assertEquals(result.ok, false);
});

Deno.test("updateQuestNodeWithFallbacks succeeds on first try", async () => {
  let updateCalls = 0;
  const mockSupabase = {
    from: () => ({
      update: (payload: any) => {
        updateCalls++;
        return { eq: () => Promise.resolve({ error: null }) };
      },
    }),
  };

  await updateQuestNodeWithFallbacks(mockSupabase, "q1", { title: "updated" });
  assertEquals(updateCalls, 1);
});

Deno.test("updateQuestNodeWithFallbacks retries with exp fallback", async () => {
  let updateCalls = 0;
  const mockSupabase = {
    from: () => ({
      update: (payload: any) => {
        updateCalls++;
        if (updateCalls === 1) {
          return { eq: () => Promise.resolve({ error: { code: "42703", message: "column" } }) };
        }
        return { eq: () => Promise.resolve({ error: null }) };
      },
    }),
  };

  await updateQuestNodeWithFallbacks(mockSupabase, "q1", { xp_reward: 10 });
  assertEquals(updateCalls, 2);
});

Deno.test("updateQuestNodeWithFallbacks throws after all variants fail", async () => {
  const mockSupabase = {
    from: () => ({
      update: () => ({
        eq: () => Promise.resolve({ error: { message: "fail" } }),
      }),
    }),
  };

  let threw = false;
  try {
    await updateQuestNodeWithFallbacks(mockSupabase, "q1", { title: "x" });
  } catch {
    threw = true;
  }
  assertEquals(threw, true);
});
