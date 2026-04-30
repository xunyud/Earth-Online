export type EverMemMemoryType =
  | "episodic_memory"
  | "semantic_memory"
  | "procedural_memory";
export type EverMemMemoryKind =
  | "task_event"
  | "dialog_event"
  | "profile_signal"
  | "generic";
export type EverMemSourceStatus = "active" | "inactive" | "muted";

export type EverMemMemoryMetadata = {
  memoryKind?: EverMemMemoryKind;
  sourceTaskId?: string;
  sourceTaskTitle?: string;
  sourceStatus?: EverMemSourceStatus;
  summary?: string;
  extra?: Record<string, unknown>;
};

export type EverMemCreateMemoryInput = {
  userId: string;
  eventType: string;
  content: string;
  messageId?: string;
  createTime?: string;
  metadata?: EverMemMemoryMetadata;
};

export type EverMemSearchInput = {
  userId: string;
  query: string;
  memoryTypes?: EverMemMemoryType[];
  retrieveMethod?: "hybrid" | "dense" | "sparse" | "agentic";
  limit?: number;
  /** group scope 检索：传入 group_id 时检索该组的共享记忆 */
  groupId?: string;
  /** agent scope 检索：传入 agent_id 时检索该 agent 的私有记忆 */
  agentId?: string;
};

/** Sender 身份注册输入 */
export type EverMemSenderInput = {
  name: string;
  metadata?: Record<string, unknown>;
};

/** Sender 身份信息 */
export type EverMemSender = {
  sender_id: string;
  name: string;
  metadata?: Record<string, unknown>;
};

export const SMART_MEMORY_ENVELOPE_PREFIX = "[smart-p-memory:v1]";

export type ParsedSmartMemoryEnvelope = {
  eventType: string;
  content: string;
  summary: string;
  memoryKind: EverMemMemoryKind;
  sourceTaskId: string;
  sourceTaskTitle: string;
  sourceStatus: string;
  extra: Record<string, unknown>;
  rawText: string;
  /** 写入源标识，如 user-manual、guide-assistant 等 */
  sender?: string;
  /** 是否标记为重要 */
  pinned?: boolean;
};

function toText(v: unknown): string {
  if (typeof v === "string") return v.trim();
  if (v == null) return "";
  return String(v).trim();
}

function toRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
}

function joinUrl(baseUrl: string, path: string) {
  return `${baseUrl.replace(/\/+$/, "")}/${path.replace(/^\/+/, "")}`;
}

function getOptionalAuthHeaders(): Record<string, string> {
  // 优先读取 EVERMEMOS_API_KEY，其次兼容旧的 EVERMEMOS_AUTH_TOKEN
  const apiKey = Deno.env.get("EVERMEMOS_API_KEY") ?? "";
  const authToken = Deno.env.get("EVERMEMOS_AUTH_TOKEN") ?? "";
  const token = apiKey || authToken;
  if (!token) return {};
  return { Authorization: `Bearer ${token}` };
}

function normalizeMemoryKind(value: unknown): EverMemMemoryKind {
  const text = toText(value);
  switch (text) {
    case "task_event":
    case "dialog_event":
    case "profile_signal":
      return text;
    default:
      return "generic";
  }
}

function normalizeSourceStatus(value: unknown): EverMemSourceStatus {
  const text = toText(value);
  switch (text) {
    case "inactive":
    case "muted":
      return text;
    default:
      return "active";
  }
}

function buildMemorySummary(input: EverMemCreateMemoryInput) {
  const provided = toText(input.metadata?.summary);
  if (provided) return provided;
  const title = toText(input.metadata?.sourceTaskTitle) ||
    toText(input.content);
  switch (toText(input.eventType)) {
    case "quest_completed":
      return title ? `任务「${title}」已完成。` : "记录了一次任务完成。";
    case "quest_deleted":
      return title
        ? `任务「${title}」已从当前任务板移除。`
        : "记录了一次任务移除。";
    case "quest_restored":
      return title
        ? `任务「${title}」已恢复到当前任务板。`
        : "记录了一次任务恢复。";
    default:
      return toText(input.content);
  }
}

/** 构建 Smart_Memory_Envelope 信封文本，包含结构化元数据的 JSON 载荷 */
export function buildSmartMemoryEnvelope(
  input: EverMemCreateMemoryInput & { sender?: string; pinned?: boolean },
) {
  const summary = buildMemorySummary(input);
  const payload: Record<string, unknown> = {
    event_type: toText(input.eventType),
    content: toText(input.content),
    summary,
    memory_kind: normalizeMemoryKind(input.metadata?.memoryKind),
    source_task_id: toText(input.metadata?.sourceTaskId),
    source_task_title: toText(input.metadata?.sourceTaskTitle),
    source_status: normalizeSourceStatus(input.metadata?.sourceStatus),
    extra: toRecord(input.metadata?.extra),
  };
  // 写入源标识：非空时追加到载荷
  const sender = toText(input.sender);
  if (sender) {
    payload.sender = sender;
  }
  // 重要标记：非 undefined 时追加到载荷
  if (input.pinned !== undefined && input.pinned !== null) {
    payload.pinned = Boolean(input.pinned);
  }
  return `${summary}\n${SMART_MEMORY_ENVELOPE_PREFIX} ${
    JSON.stringify(payload)
  }`;
}

/** 解析 Smart_Memory_Envelope 信封文本，提取结构化元数据 */
export function parseSmartMemoryEnvelope(
  rawText: unknown,
): ParsedSmartMemoryEnvelope | null {
  const text = toText(rawText);
  if (!text) return null;
  const markerIndex = text.lastIndexOf(SMART_MEMORY_ENVELOPE_PREFIX);
  if (markerIndex < 0) return null;
  const jsonText = text.slice(markerIndex + SMART_MEMORY_ENVELOPE_PREFIX.length)
    .trim();
  if (!jsonText) return null;
  try {
    const data = JSON.parse(jsonText) as Record<string, unknown>;
    const summary = toText(data.summary);
    const content = toText(data.content);
    const result: ParsedSmartMemoryEnvelope = {
      eventType: toText(data.event_type),
      content,
      summary: summary || content,
      memoryKind: normalizeMemoryKind(data.memory_kind),
      sourceTaskId: toText(data.source_task_id),
      sourceTaskTitle: toText(data.source_task_title),
      sourceStatus: normalizeSourceStatus(data.source_status),
      extra: toRecord(data.extra),
      rawText: text,
    };
    // 解析写入源标识
    const sender = toText(data.sender);
    if (sender) {
      result.sender = sender;
    }
    // 解析重要标记
    if (data.pinned !== undefined && data.pinned !== null) {
      result.pinned = data.pinned === true || data.pinned === "true";
    }
    return result;
  } catch {
    return null;
  }
}

type EverMemMessage = {
  role: "user" | "assistant" | "system";
  content: string;
};

export class EverMemOSClient {
  private readonly baseUrl: string;
  private readonly isMemoriesBase: boolean;

  constructor(baseUrl?: string) {
    const resolved = toText(baseUrl ?? Deno.env.get("EVERMEMOS_API_URL"));
    if (!resolved) {
      throw new Error("Missing EVERMEMOS_API_URL environment variable");
    }
    this.baseUrl = resolved.replace(/\/+$/, "");
    this.isMemoriesBase = /\/memories$/i.test(this.baseUrl);
  }

  private memoriesPath(path = "") {
    if (this.isMemoriesBase) {
      if (!path) return this.baseUrl;
      return joinUrl(this.baseUrl, path);
    }
    return joinUrl(this.baseUrl, `/memories${path}`);
  }

  async createMemoryFromMessages(
    userId: string,
    messages: EverMemMessage[],
    signal?: AbortSignal,
  ) {
    const uid = toText(userId);
    if (!uid) throw new Error("createMemoryFromMessages missing userId");
    const normalized = messages
      .map((m) => ({
        role: m.role,
        content: toText(m.content),
        // EverMemOS v1 要求每条 message 带 timestamp（Unix 毫秒）
        timestamp: Date.now(),
      }))
      .filter((m) => m.content.length > 0);
    if (normalized.length === 0) {
      throw new Error("createMemoryFromMessages missing messages");
    }

    const payload = {
      user_id: uid,
      messages: normalized,
    };

    const endpoints = [
      this.memoriesPath(""),
      this.memoriesPath("/extract"),
      joinUrl(this.baseUrl, "/extract"),
      joinUrl(this.baseUrl, "/messages"),
    ];
    let lastError = "";
    for (const endpoint of endpoints) {
      const resp = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...getOptionalAuthHeaders(),
        },
        body: JSON.stringify(payload),
        signal,
      });
      if (resp.ok) {
        const rawText = await resp.text();
        if (!rawText) return { ok: true, data: null, endpoint };
        try {
          return { ok: true, data: JSON.parse(rawText), endpoint };
        } catch {
          return { ok: true, data: rawText, endpoint };
        }
      }
      const raw = await resp.text();
      lastError = `${endpoint}: ${resp.status} ${raw}`;
      if (resp.status !== 404 && resp.status !== 405) {
        break;
      }
    }
    throw new Error(
      `EverMemOS createMemoryFromMessages failed: ${lastError || "unknown"}`,
    );
  }

  async createMemory(input: EverMemCreateMemoryInput, signal?: AbortSignal) {
    const userId = toText(input.userId);
    const eventType = toText(input.eventType);
    const content = toText(input.content);
    if (!userId || !eventType || !content) {
      throw new Error("createMemory missing required params");
    }
    const wrapped = buildSmartMemoryEnvelope({
      ...input,
      userId,
      eventType,
      content,
    });
    try {
      return await this.createMemoryFromMessages(userId, [{
        role: "user",
        content: wrapped,
      }], signal);
    } catch (messagesErr) {
      const legacyPayload = {
        message_id: toText(input.messageId) || crypto.randomUUID(),
        create_time: toText(input.createTime) || new Date().toISOString(),
        sender: userId,
        content: wrapped,
      };
      const endpoint = this.memoriesPath("");
      const resp = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...getOptionalAuthHeaders(),
        },
        body: JSON.stringify(legacyPayload),
        signal,
      });
      if (!resp.ok) {
        const raw = await resp.text();
        throw new Error(
          `EverMemOS createMemory failed for both protocols: messages=${
            messagesErr instanceof Error
              ? messagesErr.message
              : String(messagesErr)
          } | legacy=${resp.status} ${raw}`,
        );
      }
      const rawText = await resp.text();
      if (!rawText) {
        return { ok: true, data: null, endpoint, protocol: "legacy" };
      }
      try {
        return {
          ok: true,
          data: JSON.parse(rawText),
          endpoint,
          protocol: "legacy",
        };
      } catch {
        return { ok: true, data: rawText, endpoint, protocol: "legacy" };
      }
    }
  }

  async searchMemories(input: EverMemSearchInput, signal?: AbortSignal) {
    const userId = toText(input.userId);
    const query = toText(input.query);
    if (!userId || !query) {
      throw new Error("searchMemories missing required params");
    }

    // agentic 模式走独立端点，不走普通 search
    if (input.retrieveMethod === "agentic") {
      return this.agenticSearch(input, signal);
    }

    const memoryTypes = input.memoryTypes?.length
      ? input.memoryTypes
      : ["episodic_memory"];
    const retrieveMethod = input.retrieveMethod ?? "hybrid";

    const params = new URLSearchParams({
      query,
      user_id: userId,
      retrieve_method: retrieveMethod,
    });
    if (typeof input.limit === "number" && Number.isFinite(input.limit)) {
      params.set("limit", String(input.limit));
    }
    // group scope 检索
    if (input.groupId) params.set("group_id", input.groupId);
    // agent scope 检索
    if (input.agentId) params.set("agent_id", input.agentId);
    for (const type of memoryTypes) {
      params.append("memory_types", type);
    }

    const endpoint = this.memoriesPath("/search");
    const getResp = await fetch(`${endpoint}?${params.toString()}`, {
      method: "GET",
      headers: { ...getOptionalAuthHeaders() },
      signal,
    });

    if (getResp.ok) {
      return await getResp.json();
    }

    if (getResp.status !== 405) {
      const raw = await getResp.text();
      throw new Error(
        `EverMemOS searchMemories failed: ${getResp.status} ${raw}`,
      );
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
        ...(input.groupId ? { group_id: input.groupId } : {}),
        ...(input.agentId ? { agent_id: input.agentId } : {}),
      }),
      signal,
    });

    if (!postResp.ok) {
      const raw = await postResp.text();
      throw new Error(
        `EverMemOS searchMemories failed: ${postResp.status} ${raw}`,
      );
    }

    return await postResp.json();
  }

  /**
   * Agentic 检索：基于当前任务上下文做语义推理后返回最相关记忆片段。
   * 对应 EverOS v1 的 POST /memories/search/ 中 search_type=agentic。
   */
  async agenticSearch(input: EverMemSearchInput, signal?: AbortSignal) {
    const userId = toText(input.userId);
    const query = toText(input.query);
    if (!userId || !query) {
      throw new Error("agenticSearch missing required params");
    }

    const endpoint = this.memoriesPath("/search");
    const resp = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...getOptionalAuthHeaders(),
      },
      body: JSON.stringify({
        query,
        user_id: userId,
        search_type: "agentic",
        top_k: input.limit ?? 10,
        ...(input.groupId ? { group_id: input.groupId } : {}),
        ...(input.agentId ? { agent_id: input.agentId } : {}),
      }),
      signal,
    });

    if (!resp.ok) {
      const raw = await resp.text();
      throw new Error(`EverMemOS agenticSearch failed: ${resp.status} ${raw}`);
    }
    return await resp.json();
  }

  /**
   * 注册 sender 身份，用于记忆写入的审计追踪。
   * 对应 EverOS v1 POST /senders/
   */
  async createSender(
    input: EverMemSenderInput,
    signal?: AbortSignal,
  ): Promise<EverMemSender> {
    const endpoint = joinUrl(this.baseUrl, "/senders/");
    const resp = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...getOptionalAuthHeaders(),
      },
      body: JSON.stringify({
        name: input.name,
        metadata: input.metadata ?? {},
      }),
      signal,
    });
    if (!resp.ok) {
      const raw = await resp.text();
      throw new Error(`EverMemOS createSender failed: ${resp.status} ${raw}`);
    }
    const data = await resp.json();
    // 兼容 { data: { sender_id, name, metadata } } 和直接返回对象两种格式
    const inner = (data?.data ?? data) as Record<string, unknown>;
    return {
      sender_id: toText(inner.sender_id),
      name: toText(inner.name) || input.name,
      metadata: (inner.metadata as Record<string, unknown>) ?? {},
    };
  }

  /**
   * 获取 sender 信息。
   * 对应 EverOS v1 GET /senders/{sender_id}
   */
  async getSender(
    senderId: string,
    signal?: AbortSignal,
  ): Promise<EverMemSender> {
    const endpoint = joinUrl(this.baseUrl, `/senders/${senderId}`);
    const resp = await fetch(endpoint, {
      method: "GET",
      headers: { ...getOptionalAuthHeaders() },
      signal,
    });
    if (!resp.ok) {
      const raw = await resp.text();
      throw new Error(`EverMemOS getSender failed: ${resp.status} ${raw}`);
    }
    const data = await resp.json();
    const inner = (data?.data ?? data) as Record<string, unknown>;
    return {
      sender_id: toText(inner.sender_id) || senderId,
      name: toText(inner.name),
      metadata: (inner.metadata as Record<string, unknown>) ?? {},
    };
  }

  /**
   * 触发知识提取：调用 EverMemOS Flush API，从具体记忆中抽象出行为模式并存为 semantic_memory。
   * 对应 EverOS v1 POST /memories/flush
   */
  async flushMemories(userId: string, signal?: AbortSignal): Promise<void> {
    const uid = toText(userId);
    if (!uid) throw new Error("flushMemories missing userId");
    const endpoint = this.memoriesPath("/flush");
    const resp = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...getOptionalAuthHeaders(),
      },
      body: JSON.stringify({ user_id: uid }),
      signal,
    });
    if (!resp.ok) {
      const raw = await resp.text();
      throw new Error(`EverMemOS flushMemories failed: ${resp.status} ${raw}`);
    }
  }

  /**
   * 更新 sender 元数据（如标记 run 完成状态）。
   * 对应 EverOS v1 PUT /senders/{sender_id}
   */
  async updateSender(
    senderId: string,
    metadata: Record<string, unknown>,
    signal?: AbortSignal,
  ): Promise<EverMemSender> {
    const endpoint = joinUrl(this.baseUrl, `/senders/${senderId}`);
    const resp = await fetch(endpoint, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        ...getOptionalAuthHeaders(),
      },
      body: JSON.stringify({ metadata }),
      signal,
    });
    if (!resp.ok) {
      const raw = await resp.text();
      throw new Error(`EverMemOS updateSender failed: ${resp.status} ${raw}`);
    }
    const data = await resp.json();
    const inner = (data?.data ?? data) as Record<string, unknown>;
    return {
      sender_id: toText(inner.sender_id) || senderId,
      name: toText(inner.name),
      metadata: (inner.metadata as Record<string, unknown>) ?? {},
    };
  }
}
