import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import {
  serializeWeeklySummaryJob,
  shouldNotifyWeeklySummaryJob,
  toErrorMessage,
  toText,
  weeklySummaryCorsHeaders,
} from "../_shared/weekly_summary_jobs.ts";

function getRequiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

async function loadJobById(
  supabase: any,
  userId: string,
  jobId: string,
) {
  const { data, error } = await supabase
    .from("weekly_summary_jobs")
    .select("*")
    .eq("id", jobId)
    .eq("user_id", userId)
    .maybeSingle();

  if (error) throw error;
  return serializeWeeklySummaryJob(data);
}

async function loadLatestRelevantJob(
  supabase: any,
  userId: string,
) {
  const { data: activeRows, error: activeError } = await supabase
    .from("weekly_summary_jobs")
    .select("*")
    .eq("user_id", userId)
    .in("status", ["queued", "running"])
    .order("created_at", { ascending: false })
    .limit(1);

  if (activeError) throw activeError;
  const activeJob = serializeWeeklySummaryJob(
    Array.isArray(activeRows) ? activeRows[0] : null,
  );
  if (activeJob != null) return activeJob;

  const { data: reminderRows, error: reminderError } = await supabase
    .from("weekly_summary_jobs")
    .select("*")
    .eq("user_id", userId)
    .is("notified_at", null)
    .in("status", ["succeeded", "failed"])
    .order("finished_at", { ascending: false })
    .limit(1);

  if (reminderError) throw reminderError;
  const reminderJob = serializeWeeklySummaryJob(
    Array.isArray(reminderRows) ? reminderRows[0] : null,
  );
  if (shouldNotifyWeeklySummaryJob(reminderJob)) return reminderJob;
  return null;
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
    const jobId = toText(body?.job_id);
    const action = toText(body?.action);
    if (!userId) throw new Error("Missing user_id");

    if (action == "acknowledge") {
      if (!jobId) throw new Error("Missing job_id");
      const { error } = await supabase
        .from("weekly_summary_jobs")
        .update({ notified_at: new Date().toISOString() })
        .eq("id", jobId)
        .eq("user_id", userId);
      if (error) throw error;
      return new Response(JSON.stringify({ success: true }), {
        headers: {
          ...weeklySummaryCorsHeaders,
          "Content-Type": "application/json",
        },
      });
    }

    const job = jobId
      ? await loadJobById(supabase, userId, jobId)
      : await loadLatestRelevantJob(supabase, userId);

    return new Response(JSON.stringify({ success: true, job }), {
      headers: {
        ...weeklySummaryCorsHeaders,
        "Content-Type": "application/json",
      },
    });
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
