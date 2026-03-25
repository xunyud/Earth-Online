import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  isWeeklySummaryJobActive,
  serializeWeeklySummaryJob,
  shouldNotifyWeeklySummaryJob,
} from "./weekly_summary_jobs.ts";

Deno.test("isWeeklySummaryJobActive 会识别排队与执行中的任务", () => {
  assertEquals(isWeeklySummaryJobActive("queued"), true);
  assertEquals(isWeeklySummaryJobActive("running"), true);
  assertEquals(isWeeklySummaryJobActive("succeeded"), false);
});

Deno.test("shouldNotifyWeeklySummaryJob 仅为未提醒的结束任务返回 true", () => {
  assertEquals(
    shouldNotifyWeeklySummaryJob({ status: "succeeded", notified_at: null }),
    true,
  );
  assertEquals(
    shouldNotifyWeeklySummaryJob({ status: "failed", notified_at: "" }),
    true,
  );
  assertEquals(
    shouldNotifyWeeklySummaryJob({ status: "running", notified_at: null }),
    false,
  );
  assertEquals(
    shouldNotifyWeeklySummaryJob({
      status: "succeeded",
      notified_at: "2026-03-25T12:00:00.000Z",
    }),
    false,
  );
});

Deno.test("serializeWeeklySummaryJob 会归一化空字符串字段", () => {
  const row = serializeWeeklySummaryJob({
    id: "job-1",
    user_id: "user-1",
    status: "succeeded",
    summary_date_id: " 2026-03-25 ",
    error_message: " ",
  });

  assertEquals(row?.summary_date_id, "2026-03-25");
  assertEquals(row?.error_message, null);
});
