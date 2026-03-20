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
  retrieveMethod?: "hybrid" | "dense" | "sparse";
  limit?: number;
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

function getOptionalAuthHeaders() {
  const apiKey = toText(Deno.env.get("EVERMEMOS_API_KEY"));
  if (!apiKey) return {};
  return { Authorization: `Bearer ${apiKey}` };
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

export function buildSmartMemoryEnvelope(input: EverMemCreateMemoryInput) {
  const summary = buildMemorySummary(input);
  const payload = {
    event_type: toText(input.eventType),
    content: toText(input.content),
    summary,
    memory_kind: normalizeMemoryKind(input.metadata?.memoryKind),
    source_task_id: toText(input.metadata?.sourceTaskId),
    source_task_title: toText(input.metadata?.sourceTaskTitle),
    source_status: normalizeSourceStatus(input.metadata?.sourceStatus),
    extra: toRecord(input.metadata?.extra),
  };
  return `${summary}\n${SMART_MEMORY_ENVELOPE_PREFIX} ${
    JSON.stringify(payload)
  }`;
}

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
    return {
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
}
