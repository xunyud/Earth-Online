export const weeklySummaryCorsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

export type WeeklySummaryJobRow = {
  id: string;
  user_id: string;
  status: string;
  summary?: string | null;
  summary_date_id?: string | null;
  error_message?: string | null;
  created_at?: string | null;
  started_at?: string | null;
  finished_at?: string | null;
  notified_at?: string | null;
};

export function toText(value: unknown): string {
  if (typeof value === "string") return value.trim();
  if (value == null) return "";
  return String(value).trim();
}

export function toErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}

export function formatDateId(date: Date): string {
  const y = date.getUTCFullYear().toString().padStart(4, "0");
  const m = (date.getUTCMonth() + 1).toString().padStart(2, "0");
  const d = date.getUTCDate().toString().padStart(2, "0");
  return `${y}-${m}-${d}`;
}

export function isWeeklySummaryJobActive(status: string): boolean {
  return status === "queued" || status === "running";
}

export function shouldNotifyWeeklySummaryJob(
  row: Partial<WeeklySummaryJobRow> | null,
): boolean {
  if (!row) return false;
  return (row.status === "succeeded" || row.status === "failed") &&
    !toText(row.notified_at);
}

export function serializeWeeklySummaryJob(
  row: Partial<WeeklySummaryJobRow> | null,
): WeeklySummaryJobRow | null {
  if (!row?.id) return null;
  return {
    id: toText(row.id),
    user_id: toText(row.user_id),
    status: toText(row.status),
    summary: toText(row.summary) || null,
    summary_date_id: toText(row.summary_date_id) || null,
    error_message: toText(row.error_message) || null,
    created_at: toText(row.created_at) || null,
    started_at: toText(row.started_at) || null,
    finished_at: toText(row.finished_at) || null,
    notified_at: toText(row.notified_at) || null,
  };
}

export function runFireAndForget(task: Promise<unknown>) {
  const edgeRuntime = (globalThis as unknown as {
    EdgeRuntime?: { waitUntil?: (promise: Promise<unknown>) => void };
  }).EdgeRuntime;
  if (edgeRuntime?.waitUntil) {
    edgeRuntime.waitUntil(task);
    return;
  }
  task.catch((error) =>
    console.warn("weekly-summary background error:", toErrorMessage(error))
  );
}
