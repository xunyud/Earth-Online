import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import {
  formatDateId,
  isWeeklySummaryJobActive,
  runFireAndForget,
  serializeWeeklySummaryJob,
  toErrorMessage,
  toText,
  weeklySummaryCorsHeaders,
} from "../_shared/weekly_summary_jobs.ts";

function getRequiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

async function findActiveJob(supabase: any, userId: string) {
  const { data, error } = await supabase
    .from("weekly_summary_jobs")
    .select("*")
    .eq("user_id", userId)
    .in("status", ["queued", "running"])
    .order("created_at", { ascending: false })
    .limit(1);

  if (error) throw error;
  const row = Array.isArray(data) ? data[0] : null;
  return serializeWeeklySummaryJob(row);
}

async function createQueuedJob(supabase: any, userId: string) {
  const { data, error } = await supabase
    .from("weekly_summary_jobs")
    .insert({
      user_id: userId,
      status: "queued",
      summary_date_id: formatDateId(new Date()),
    })
    .select("*")
    .single();

  if (error) throw error;
  return serializeWeeklySummaryJob(data);
}

async function runWeeklySummaryJob(
  supabaseUrl: string,
  serviceRole: string,
  jobId: string,
  userId: string,
) {
  const supabase = createClient(supabaseUrl, serviceRole);
  const startedAt = new Date().toISOString();
  await supabase
    .from("weekly_summary_jobs")
    .update({
      status: "running",
      started_at: startedAt,
      error_message: null,
    })
    .eq("id", jobId);

  try {
    const response = await fetch(`${supabaseUrl}/functions/v1/weekly-summary`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${serviceRole}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ user_id: userId }),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok || data?.success !== true) {
      throw new Error(
        toText(data?.error) ||
          `weekly-summary failed with HTTP ${response.status}`,
      );
    }

    await supabase
      .from("weekly_summary_jobs")
      .update({
        status: "succeeded",
        summary: toText(data.summary) || null,
        finished_at: new Date().toISOString(),
        error_message: null,
      })
      .eq("id", jobId);
  } catch (error) {
    await supabase
      .from("weekly_summary_jobs")
      .update({
        status: "failed",
        error_message: toErrorMessage(error),
        finished_at: new Date().toISOString(),
      })
      .eq("id", jobId);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: weeklySummaryCorsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ success: false, error: "Method Not Allowed" }),
      {
        status: 405,
        headers: {
          ...weeklySummaryCorsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }

  try {
    const supabaseUrl = getRequiredEnv("SUPABASE_URL");
    const serviceRole = getRequiredEnv("SUPABASE_SERVICE_ROLE_KEY");
    const supabase = createClient(supabaseUrl, serviceRole);
    const body = await req.json().catch(() => ({}));
    const userId = toText(body?.user_id);
    if (!userId) throw new Error("Missing user_id");

    const existingJob = await findActiveJob(supabase, userId);
    if (existingJob != null && isWeeklySummaryJobActive(existingJob.status)) {
      return new Response(
        JSON.stringify({ success: true, queued: false, job: existingJob }),
        {
          headers: {
            ...weeklySummaryCorsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const queuedJob = await createQueuedJob(supabase, userId);
    if (queuedJob == null) {
      throw new Error("Failed to create weekly summary job");
    }

    runFireAndForget(
      runWeeklySummaryJob(supabaseUrl, serviceRole, queuedJob.id, userId),
    );

    return new Response(
      JSON.stringify({ success: true, queued: true, job: queuedJob }),
      {
        headers: {
          ...weeklySummaryCorsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: toErrorMessage(error) }),
      {
        status: 500,
        headers: {
          ...weeklySummaryCorsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }
});
