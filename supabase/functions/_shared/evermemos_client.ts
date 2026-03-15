export type EverMemMemoryType = "episodic_memory" | "semantic_memory" | "procedural_memory"

export type EverMemCreateMemoryInput = {
  userId: string
  eventType: string
  content: string
  messageId?: string
  createTime?: string
}

export type EverMemSearchInput = {
  userId: string
  query: string
  memoryTypes?: EverMemMemoryType[]
  retrieveMethod?: "hybrid" | "dense" | "sparse"
  limit?: number
}

function toText(v: unknown): string {
  if (typeof v === "string") return v.trim()
  if (v == null) return ""
  return String(v).trim()
}

function joinUrl(baseUrl: string, path: string) {
  return `${baseUrl.replace(/\/+$/, "")}/${path.replace(/^\/+/, "")}`
}

function getOptionalAuthHeaders() {
  const apiKey = toText(Deno.env.get("EVERMEMOS_API_KEY"))
  if (!apiKey) return {}
  return { Authorization: `Bearer ${apiKey}` }
}

type EverMemMessage = {
  role: "user" | "assistant" | "system"
  content: string
}

export class EverMemOSClient {
  private readonly baseUrl: string
  private readonly isMemoriesBase: boolean

  constructor(baseUrl?: string) {
    const resolved = toText(baseUrl ?? Deno.env.get("EVERMEMOS_API_URL"))
    if (!resolved) {
      throw new Error("缺少 EVERMEMOS_API_URL 环境变量")
    }
    this.baseUrl = resolved.replace(/\/+$/, "")
    this.isMemoriesBase = /\/memories$/i.test(this.baseUrl)
  }

  private memoriesPath(path = "") {
    if (this.isMemoriesBase) {
      if (!path) return this.baseUrl
      return joinUrl(this.baseUrl, path)
    }
    return joinUrl(this.baseUrl, `/memories${path}`)
  }

  async createMemoryFromMessages(userId: string, messages: EverMemMessage[], signal?: AbortSignal) {
    const uid = toText(userId)
    if (!uid) throw new Error("createMemoryFromMessages 缺少 userId")
    const normalized = messages
      .map((m) => ({
        role: m.role,
        content: toText(m.content),
      }))
      .filter((m) => m.content.length > 0)
    if (normalized.length === 0) throw new Error("createMemoryFromMessages 缺少 messages")

    const payload = {
      user_id: uid,
      messages: normalized,
    }

    const endpoints = [
      this.memoriesPath(""),
      this.memoriesPath("/extract"),
      joinUrl(this.baseUrl, "/extract"),
      joinUrl(this.baseUrl, "/messages"),
    ]
    let lastError = ""
    for (const endpoint of endpoints) {
      const resp = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...getOptionalAuthHeaders(),
        },
        body: JSON.stringify(payload),
        signal,
      })
      if (resp.ok) {
        const rawText = await resp.text()
        if (!rawText) return { ok: true, data: null, endpoint }
        try {
          return { ok: true, data: JSON.parse(rawText), endpoint }
        } catch {
          return { ok: true, data: rawText, endpoint }
        }
      }
      const raw = await resp.text()
      lastError = `${endpoint}: ${resp.status} ${raw}`
      if (resp.status !== 404 && resp.status !== 405) {
        break
      }
    }
    throw new Error(`EverMemOS createMemoryFromMessages 失败: ${lastError || "unknown"}`)
  }

  async createMemory(input: EverMemCreateMemoryInput, signal?: AbortSignal) {
    const userId = toText(input.userId)
    const eventType = toText(input.eventType)
    const content = toText(input.content)
    if (!userId || !eventType || !content) {
      throw new Error("createMemory 缺少必要参数")
    }
    const wrapped = `我今天的地球Online记录是：[${eventType}] ${content}`
    try {
      return await this.createMemoryFromMessages(userId, [{ role: "user", content: wrapped }], signal)
    } catch (messagesErr) {
      const legacyPayload = {
        message_id: toText(input.messageId) || crypto.randomUUID(),
        create_time: toText(input.createTime) || new Date().toISOString(),
        sender: userId,
        content: wrapped,
      }
      const endpoint = this.memoriesPath("")
      const resp = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...getOptionalAuthHeaders(),
        },
        body: JSON.stringify(legacyPayload),
        signal,
      })
      if (!resp.ok) {
        const raw = await resp.text()
        throw new Error(
          `EverMemOS createMemory 双协议失败: messages=${messagesErr instanceof Error ? messagesErr.message : String(messagesErr)} | legacy=${resp.status} ${raw}`,
        )
      }
      const rawText = await resp.text()
      if (!rawText) return { ok: true, data: null, endpoint, protocol: "legacy" }
      try {
        return { ok: true, data: JSON.parse(rawText), endpoint, protocol: "legacy" }
      } catch {
        return { ok: true, data: rawText, endpoint, protocol: "legacy" }
      }
    }
  }

  async searchMemories(input: EverMemSearchInput, signal?: AbortSignal) {
    const userId = toText(input.userId)
    const query = toText(input.query)
    if (!userId || !query) {
      throw new Error("searchMemories 缺少必要参数")
    }

    const memoryTypes = input.memoryTypes?.length
      ? input.memoryTypes
      : ["episodic_memory"]
    const retrieveMethod = input.retrieveMethod ?? "hybrid"

    const params = new URLSearchParams({
      query,
      user_id: userId,
      retrieve_method: retrieveMethod,
    })
    if (typeof input.limit === "number" && Number.isFinite(input.limit)) {
      params.set("limit", String(input.limit))
    }
    for (const type of memoryTypes) {
      params.append("memory_types", type)
    }

    const endpoint = this.memoriesPath("/search")
    const getResp = await fetch(`${endpoint}?${params.toString()}`, {
      method: "GET",
      headers: { ...getOptionalAuthHeaders() },
      signal,
    })

    if (getResp.ok) {
      return await getResp.json()
    }

    if (getResp.status !== 405) {
      const raw = await getResp.text()
      throw new Error(`EverMemOS searchMemories 失败: ${getResp.status} ${raw}`)
    }

    const postResp = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...getOptionalAuthHeaders(),
      },
      body: JSON.stringify({
        query,
        user_id: userId,
        memory_types: memoryTypes,
        retrieve_method: retrieveMethod,
        limit: input.limit,
      }),
      signal,
    })

    if (!postResp.ok) {
      const raw = await postResp.text()
      throw new Error(`EverMemOS searchMemories 失败: ${postResp.status} ${raw}`)
    }

    return await postResp.json()
  }
}
