import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { gatherGuideMemoryBundle } from "./guide_memory.ts";

type QueryResult = {
  data: unknown;
  error: unknown;
};

function buildQuery(result: QueryResult) {
  const chain = {
    select() {
      return this;
    },
    eq() {
      return this;
    },
    neq() {
      return this;
    },
    gte() {
      return this;
    },
    order() {
      return this;
    },
    limit() {
      // limit 后可能还会链式调用 maybeSingle，所以返回 thenable 对象而非纯 Promise
      return {
        then: (resolve: (v: QueryResult) => void, reject?: (e: unknown) => void) =>
          Promise.resolve(result).then(resolve, reject),
        maybeSingle() {
          return Promise.resolve(result);
        },
      };
    },
    maybeSingle() {
      return Promise.resolve(result);
    },
  };
  return chain;
}

Deno.test("gatherGuideMemoryBundle excludes completed tasks from active titles and strips generated encouragement", async () => {
  const todayIso = new Date().toISOString();
  const sevenDayId = todayIso.slice(0, 10);

  const supabase = {
    from(table: string) {
      switch (table) {
        case "quest_nodes":
          return buildQuery({
            data: [
              {
                id: "task-active",
                title: "仍在推进的任务",
                is_deleted: false,
                is_reward: false,
                is_completed: false,
              },
              {
                id: "task-done",
                title: "已经完成的任务",
                is_deleted: false,
                is_reward: false,
                is_completed: true,
              },
              {
                id: "task-deleted",
                title: "已删除任务",
                is_deleted: true,
                is_reward: false,
                is_completed: false,
              },
              {
                id: "task-today-done",
                title: "今天收尾的任务",
                description: "完成收尾",
                completed_at: todayIso,
                xp_reward: 12,
                exp: 12,
                is_completed: true,
                is_deleted: false,
              },
            ],
            error: null,
          });
        case "daily_logs":
          return buildQuery({
            data: [
              {
                date_id: sevenDayId,
                completed_count: 3,
                is_perfect: false,
                encouragement: "这是系统自动鼓励语",
                streak_day: 2,
                xp_multiplier: 1,
              },
            ],
            error: null,
          });
        case "profiles":
          return buildQuery({
            data: {
              id: "user-1",
              total_xp: 100,
              gold: 20,
              current_streak: 2,
              longest_streak: 5,
              last_checkin_date: sevenDayId,
            },
            error: null,
          });
        case "guide_dialog_logs":
          return buildQuery({
            data: [],
            error: null,
          });
        case "guide_portraits":
          return buildQuery({
            data: null,
            error: null,
          });
        default:
          throw new Error(`unexpected table: ${table}`);
      }
    },
  };

  const bundle = await gatherGuideMemoryBundle(supabase, "user-1", {
    scene: "home",
    maxRawItems: 20,
    maxPackedChars: 4000,
  });

  const recentContext = bundle.recent_context.join("\n");
  const digest = bundle.memory_digest;

  assert(recentContext.includes("仍在推进的任务"));
  assert(!recentContext.includes("已经完成的任务"));
  assert(!recentContext.includes("这是系统自动鼓励语"));
  assert(digest.includes("当前任务板任务数：1"));
  assertEquals(bundle.long_term_callbacks.length > 0, true);
});
