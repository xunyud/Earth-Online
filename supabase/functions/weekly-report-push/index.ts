// PRD-07: 微信周报推送 Edge Function
// 功能：查询符合条件的用户 → 生成周报 → 通过微信客服消息 API 推送
// 触发方式：pg_cron 定时（每周日 20:00 UTC+8）或前端手动调用（传 user_id）

import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

// ---------- 微信 access_token 缓存 ----------

let _cachedToken = ""
let _tokenExpiresAt = 0 // Unix ms

async function getWechatAccessToken(): Promise<string> {
  if (_cachedToken && Date.now() < _tokenExpiresAt - 60_000) {
    return _cachedToken
  }

  const appId = Deno.env.get("WECHAT_APP_ID") ?? ""
  const appSecret = Deno.env.get("WECHAT_APP_SECRET") ?? ""
  if (!appId || !appSecret) {
    throw new Error("缺少 WECHAT_APP_ID 或 WECHAT_APP_SECRET 环境变量")
  }

  const url = `https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=${appId}&secret=${appSecret}`
  const resp = await fetch(url)
  if (!resp.ok) {
    throw new Error(`获取 access_token 失败: HTTP ${resp.status}`)
  }

  const data = await resp.json()
  if (data.errcode) {
    throw new Error(`获取 access_token 失败: errcode=${data.errcode} errmsg=${data.errmsg}`)
  }

  _cachedToken = data.access_token
  _tokenExpiresAt = Date.now() + (data.expires_in ?? 7200) * 1000
  return _cachedToken
}

// ---------- 微信客服消息发送 ----------

type SendResult = { ok: true } | { ok: false; errcode: number; errmsg: string }

async function sendWechatTextMessage(
  accessToken: string,
  openId: string,
  content: string,
): Promise<SendResult> {
  const url = `https://api.weixin.qq.com/cgi-bin/message/custom/send?access_token=${accessToken}`
  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      touser: openId,
      msgtype: "text",
      text: { content },
    }),
  })

  if (!resp.ok) {
    return { ok: false, errcode: resp.status, errmsg: `HTTP ${resp.status}` }
  }

  const data = await resp.json()
  if (data.errcode && data.errcode !== 0) {
    return { ok: false, errcode: data.errcode, errmsg: data.errmsg ?? "" }
  }
  return { ok: true }
}

// ---------- Markdown → 纯文本 ----------

function stripMarkdown(md: string): string {
  return md
    .replace(/#{1,6}\s*/g, "")          // 标题
    .replace(/\*\*(.+?)\*\*/g, "$1")    // 粗体
    .replace(/\*(.+?)\*/g, "$1")        // 斜体
    .replace(/__(.+?)__/g, "$1")        // 粗体
    .replace(/_(.+?)_/g, "$1")          // 斜体
    .replace(/~~(.+?)~~/g, "$1")        // 删除线
    .replace(/`(.+?)`/g, "$1")          // 行内代码
    .replace(/\[(.+?)\]\(.+?\)/g, "$1") // 链接
    .replace(/^[-*+]\s+/gm, "• ")       // 无序列表
    .replace(/^\d+\.\s+/gm, "")         // 有序列表（保留数字内容）
    .replace(/^>\s*/gm, "")             // 引用
    .replace(/---+/g, "")               // 分隔线
    .replace(/\n{3,}/g, "\n\n")         // 多余空行
    .trim()
}

// ---------- 工具函数 ----------

function toText(v: unknown): string {
  if (typeof v === "string") return v.trim()
  if (v == null) return ""
  return String(v).trim()
}

function toErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message
  try { return JSON.stringify(error) } catch { return String(error) }
}

// ---------- 主逻辑 ----------

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
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    if (!supabaseUrl || !serviceRole) {
      throw new Error("缺少 SUPABASE_URL 或 SUPABASE_SERVICE_ROLE_KEY")
    }

    const supabase = createClient(supabaseUrl, serviceRole)

    // 解析请求体：如果包含 user_id 则为手动推送单用户，否则为批量推送
    let body: Record<string, unknown> = {}
    try { body = await req.json() } catch { /* 空 body，批量模式 */ }
    const singleUserId = toText(body?.user_id)

    // ---------- 1. 查询推送候选用户 ----------
    let query = supabase
      .from("profiles")
      .select("id, wechat_openid, last_wechat_interaction")
      .eq("weekly_push_enabled", true)
      .not("wechat_openid", "is", null)

    if (singleUserId) {
      // 手动推送：指定用户（仍需满足绑定 + 48h 窗口）
      query = query.eq("id", singleUserId)
    }

    const { data: candidates, error: queryErr } = await query
    if (queryErr) throw new Error(`查询候选用户失败: ${queryErr.message}`)

    const now = Date.now()
    const FORTY_EIGHT_HOURS = 48 * 60 * 60 * 1000

    // 过滤 48h 窗口内的用户
    const eligible = (candidates ?? []).filter((u: any) => {
      if (!u.last_wechat_interaction) return false
      const lastInteraction = new Date(u.last_wechat_interaction).getTime()
      return now - lastInteraction < FORTY_EIGHT_HOURS
    })

    if (eligible.length === 0) {
      const reason = singleUserId
        ? "该用户不满足推送条件（未绑定微信 / 未开启推送 / 超出 48 小时交互窗口）"
        : "暂无符合条件的推送用户"
      return new Response(JSON.stringify({ success: true, pushed: 0, message: reason }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    // ---------- 2. 获取微信 access_token ----------
    let accessToken: string
    try {
      accessToken = await getWechatAccessToken()
    } catch (e) {
      // access_token 获取失败 → 全部标记 failed
      for (const u of eligible) {
        await supabase.from("push_logs").insert({
          user_id: u.id,
          push_type: "weekly_report",
          status: "failed",
          error_message: `access_token 获取失败: ${toErrorMessage(e)}`,
        })
      }
      throw e
    }

    // ---------- 3. 逐用户：生成周报 → 推送 → 记录 ----------
    const results: Array<{ user_id: string; status: string; error?: string }> = []

    for (const user of eligible) {
      const userId = user.id as string
      const openId = user.wechat_openid as string

      // 创建 push_log 记录（pending 状态）
      const { data: logRow } = await supabase
        .from("push_logs")
        .insert({ user_id: userId, push_type: "weekly_report", status: "pending" })
        .select("id")
        .single()
      const logId = logRow?.id

      try {
        // 3a. 调用 weekly-summary 生成周报
        const summaryResp = await fetch(`${supabaseUrl}/functions/v1/weekly-summary`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${serviceRole}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ user_id: userId }),
        })

        const summaryData = await summaryResp.json()
        if (!summaryData.success || !summaryData.summary) {
          throw new Error(summaryData.error || "周报生成失败")
        }

        // 3b. Markdown → 纯文本，截断到 600 字
        const plainText = stripMarkdown(summaryData.summary)
        const truncated = plainText.length > 600 ? plainText.slice(0, 597) + "..." : plainText
        const messageContent = `📊 本周冒险周报\n\n${truncated}`

        // 3c. 发送微信客服消息
        const sendResult = await sendWechatTextMessage(accessToken, openId, messageContent)

        if (!sendResult.ok) {
          // errcode 45015 = 48h 窗口过期
          const status = sendResult.errcode === 45015 ? "skipped" : "failed"
          const errMsg = `errcode=${sendResult.errcode} errmsg=${sendResult.errmsg}`

          if (logId) {
            await supabase.from("push_logs").update({
              status,
              error_message: errMsg,
              content_preview: truncated.slice(0, 200),
            }).eq("id", logId)
          }

          results.push({ user_id: userId, status, error: errMsg })
          continue
        }

        // 3d. 推送成功
        if (logId) {
          await supabase.from("push_logs").update({
            status: "sent",
            content_preview: truncated.slice(0, 200),
            sent_at: new Date().toISOString(),
          }).eq("id", logId)
        }

        results.push({ user_id: userId, status: "sent" })
      } catch (err) {
        const errMsg = toErrorMessage(err)
        if (logId) {
          await supabase.from("push_logs").update({
            status: "failed",
            error_message: errMsg,
          }).eq("id", logId)
        }
        results.push({ user_id: userId, status: "failed", error: errMsg })
      }
    }

    const sentCount = results.filter((r) => r.status === "sent").length
    return new Response(
      JSON.stringify({ success: true, pushed: sentCount, total: eligible.length, results }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  } catch (error) {
    const msg = toErrorMessage(error)
    console.error("weekly-report-push error:", msg)
    return new Response(
      JSON.stringify({ success: false, error: msg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    )
  }
})
