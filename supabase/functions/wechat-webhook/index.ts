import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

function escapeXmlText(input: string) {
  return input
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
}

function formatPostgrestError(err: any) {
  if (!err) return '';
  const code = err.code ? `code=${err.code}` : '';
  const msg = err.message ? `message=${err.message}` : String(err);
  const details = err.details ? `details=${err.details}` : '';
  const hint = err.hint ? `hint=${err.hint}` : '';
  return [code, msg, details, hint].filter(Boolean).join(' | ');
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
    description: '',
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
    { ...baseWithDefaults, node_type: 'task' },
    baseWithDefaults,
    (() => {
      const { xp_reward, ...rest } = baseWithDefaults;
      return { ...rest, exp: xp_reward, node_type: 'task' };
    })(),
    (() => {
      const { xp_reward, ...rest } = baseWithDefaults;
      return { ...rest, exp: xp_reward };
    })(),
  ];

  let lastErr: any = null;
  for (const payload of variants) {
    const { data, error } = await supabase
      .from('quest_nodes')
      .insert(payload)
      .select('id')
      .single();
    if (!error) {
      const id = (data as any)?.id;
      if (typeof id === 'string' && id) return { ok: true, id };
      return { ok: true, id: String(id ?? '') };
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
    const { error } = await supabase.from('quest_nodes').update(payload).eq('id', questId);
    if (!error) return;
    lastErr = error;
  }
  throw lastErr ?? new Error('Failed to update quest node');
}

function scheduleBackground(p: Promise<unknown>) {
  const er = (globalThis as any).EdgeRuntime;
  if (er?.waitUntil) {
    er.waitUntil(p);
  } else {
    p.catch((e) => console.error(e));
  }
}

serve(async (req) => {
  const url = new URL(req.url);
  
  // ==========================================
  // 1. 响应微信的首次服务器验证 (GET 请求)
  // ==========================================
  if (req.method === 'GET') {
    const echostr = url.searchParams.get('echostr');
    if (echostr) {
      return new Response(echostr, { status: 200 });
    }
    return new Response('Invalid Request', { status: 400 });
  }

  // ==========================================
  // 2. 接收用户发来的微信消息 (POST 请求)
  // ==========================================
  if (req.method === 'POST') {
    // 微信发来的是 XML 格式，我们用 text 读取
    const xmlString = await req.text();
    
    // 用正则简单粗暴地提取所需字段
    const fromUserNameMatch = xmlString.match(/<FromUserName><!\[CDATA\[(.*?)\]\]><\/FromUserName>/);
    const contentMatch = xmlString.match(/<Content><!\[CDATA\[(.*?)\]\]><\/Content>/);
    const toUserNameMatch = xmlString.match(/<ToUserName><!\[CDATA\[(.*?)\]\]><\/ToUserName>/);

    // 如果不是文本消息，直接回 success 防止微信重复发送
    if (!fromUserNameMatch || !contentMatch) {
      return new Response('success', { status: 200 }); 
    }

    const openId = fromUserNameMatch[1];       // 用户的微信 OpenID
    const content = contentMatch[1].trim();    // 用户发的内容 (比如 "2260")
    const myWechatId = toUserNameMatch ? toUserNameMatch[1] : '';

    // 初始化 Supabase 客户端 (使用服务角色密钥绕过权限控制)
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseKey);

    let replyText = "收到消息";

    const { data: profile, error: profileErr } = await supabase
      .from('profiles')
      .select('id,wechat_openid')
      .eq('wechat_openid', openId)
      .maybeSingle();

    if (!profileErr && profile?.id) {
      // PRD-07: 记录最近微信交互时间（用于 48h 推送窗口判断）
      supabase
        .from('profiles')
        .update({ last_wechat_interaction: new Date().toISOString() })
        .eq('id', profile.id)
        .then(({ error: _e }: any) => {
          if (_e) console.error('update last_wechat_interaction:', _e.message);
        });

      if (isFourDigits(content)) {
        replyText = "你的账号已经绑定成功啦！直接发文字就可以记录为任务。";
      } else if (content.length === 0) {
        replyText = "收到空消息啦，发一段文字就可以记录为任务。";
      } else {
        const userId = profile.id;
        const sortOrder = -Date.now();

        const insertRes = await insertQuestNodeWithFallbacks(supabase, {
          user_id: userId,
          parent_id: null,
          title: content,
          quest_tier: 'Main_Quest',
          sort_order: sortOrder,
          xp_reward: 0,
          description: '',
        });

        if (!insertRes.ok || !insertRes.id) {
          replyText = `记录失败：${formatPostgrestError(insertRes.ok ? null : insertRes.error)}`;
        } else {
          const placeholderId = insertRes.id;
          replyText = `✅ 任务已收到，正在由 AI 解析中...（id: ${placeholderId}）`;

          scheduleBackground((async () => {
            const { data, error } = await supabase.functions.invoke('parse-quest', {
              body: { text: content, user_id: userId },
            });

            if (error || !data) {
              console.error('parse-quest error:', formatPostgrestError(error));
              return;
            }

            const tasksRaw = Array.isArray((data as any).tasks) ? (data as any).tasks : [];
            if (tasksRaw.length === 0) return;

            const cheerRaw = typeof (data as any).cheer === 'string' ? (data as any).cheer.trim() : '';
            const cheer = cheerRaw && cheerRaw.length <= 200 ? cheerRaw : '';

            const tasks: Array<{ title: string; parent_index: number | null; xpReward: number }> = [];
            for (let i = 0; i < tasksRaw.length; i++) {
              const t = tasksRaw[i] ?? {};
              const title = typeof t.title === 'string' ? t.title.trim() : '';
              if (!title) continue;
              const parent_index = Number.isInteger(t.parent_index) ? t.parent_index : null;
              const xpReward = Number.isFinite(t.xpReward) ? Math.round(t.xpReward) : 0;
              tasks.push({ title, parent_index, xpReward });
            }
            if (tasks.length === 0) return;

            const idByIndex = new Map<number, string>();
            const rootSortBase = -Date.now();
            idByIndex.set(0, placeholderId);

            const first = tasks[0];
            await updateQuestNodeWithFallbacks(supabase, placeholderId, {
              title: first.title,
              xp_reward: first.xpReward,
              description: cheer || '',
              due_date: null,
              completed_at: null,
              quest_tier: 'Main_Quest',
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
              const t = tasks[i];
              const id = idByIndex.get(i)!;
              const parentId = t.parent_index != null ? idByIndex.get(t.parent_index) ?? null : null;
              const row: Record<string, unknown> = {
                id,
                user_id: userId,
                parent_id: parentId,
                title: t.title,
                quest_tier: parentId == null ? 'Main_Quest' : 'Side_Quest',
                sort_order: rootSortBase + i,
                xp_reward: t.xpReward,
                description: '',
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
              const withNodeType = rows.map((r) => ({ ...r, node_type: 'task' }));
              const { error: e1 } = await supabase.from('quest_nodes').insert(withNodeType);
              if (!e1) return null;
              const { error: e2 } = await supabase.from('quest_nodes').insert(rows);
              return e2 ?? e1;
            };

            const err1 = await tryRows(roots);
            if (err1) console.error('insert roots error:', formatPostgrestError(err1));
            const err2 = await tryRows(children);
            if (err2) console.error('insert children error:', formatPostgrestError(err2));

            // 微信创建任务后检查特殊成就（first_wechat）
            try {
              await supabase.rpc('check_and_unlock_achievements', {
                p_user_id: userId,
                p_category: 'special',
              });
            } catch (e) {
              console.error('achievement check error:', e);
            }
          })());
        }
      }
    } else if (isFourDigits(content)) {
      const code = content;

      // 去查我们刚才建的表
      const { data: bindRecord, error } = await supabase
        .from('wechat_bind_codes')
        .select('user_id, expires_at')
        .eq('code', code)
        .single();

      if (error || !bindRecord) {
        replyText = "验证码无效，请在 App 中重新生成。";
      } else if (new Date(bindRecord.expires_at) < new Date()) {
        replyText = "验证码已过期，请在 App 中重新生成。";
      } else {
        // 🎉 核心逻辑：暗号对上了，执行绑定！
        const userId = bindRecord.user_id;

        // 更新用户的 profiles 表，写入微信 OpenID + 记录交互时间
        await supabase
          .from('profiles')
          .update({
            wechat_openid: openId,
            last_wechat_interaction: new Date().toISOString(),
          })
          .eq('id', userId);

        // 销毁用过的验证码（阅后即焚）
        await supabase
          .from('wechat_bind_codes')
          .delete()
          .eq('code', code);

        replyText = "🎉 绑定成功！以后你在这里发的消息，都会自动同步到 App 里变成任务啦！";
      }
    } else {
      replyText = "欢迎！如需绑定账号，请发送 App 中的 4 位验证码。";
    }

    // 拼装微信需要的 XML 回复格式
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
      headers: { 'Content-Type': 'application/xml' },
      status: 200,
    });
  }

  return new Response('Method Not Allowed', { status: 405 });
});
