import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  acceptLatestSuggestedTask,
  buildGuideAssistantExtraPayload,
  getLatestSuggestedTask,
  resolveGuideDisplayName,
  writeGuideDialogLog,
} from "./guide_engine.ts";

Deno.test("writeGuideDialogLog 兼容 Supabase insert 返回普通结果对象", async () => {
  let insertedTable = "";
  let insertedPayload: any = null;
  const supabase = {
    from(table: string) {
      insertedTable = table;
      return {
        async insert(payload: Record<string, unknown>) {
          insertedPayload = payload;
          return { data: null, error: null };
        },
      };
    },
  };

  await writeGuideDialogLog(supabase, {
    userId: "user-1",
    scene: "home",
    role: "assistant",
    content: "继续聊今天",
    memoryRefs: ["m1"],
  });

  assertEquals(insertedTable, "guide_dialog_logs");
  assertEquals(insertedPayload?.user_id, "user-1");
  assertEquals(insertedPayload?.content, "继续聊今天");
});

Deno.test("buildGuideAssistantExtraPayload 会保留 suggested_task 与 quick_actions", () => {
  const payload = buildGuideAssistantExtraPayload({
    quickActions: ["继续聊今天", "给我一个恢复任务"],
    suggestedTask: {
      title: "恢复支线：拉伸 8 分钟",
      description: "先把节奏稳下来",
      xp_reward: 18,
      quest_tier: "Daily",
    },
    channel: "wechat",
  });

  assertEquals(payload?.channel, "wechat");
  assertEquals(payload?.quick_actions, ["继续聊今天", "给我一个恢复任务"]);
  assertEquals(payload?.suggested_task?.title, "恢复支线：拉伸 8 分钟");
});

Deno.test("writeGuideDialogLog 会写入 extra_payload", async () => {
  let insertedPayload: any = null;
  const supabase = {
    from() {
      return {
        async insert(payload: Record<string, unknown>) {
          insertedPayload = payload;
          return { data: null, error: null };
        },
      };
    },
  };

  await writeGuideDialogLog(supabase, {
    userId: "user-2",
    scene: "wechat",
    role: "assistant",
    content: "可以，先收下这条建议任务。",
    extraPayload: {
      channel: "wechat",
      suggested_task: {
        title: "恢复支线：散步 10 分钟",
        description: "离开屏幕，稍微透口气",
        xp_reward: 20,
        quest_tier: "Daily",
      },
    },
  });

  assertEquals(insertedPayload?.extra_payload?.channel, "wechat");
  assertEquals(
    insertedPayload?.extra_payload?.suggested_task?.title,
    "恢复支线：散步 10 分钟",
  );
});

Deno.test("getLatestSuggestedTask 会读取最近一次 assistant 建议任务", async () => {
  const supabase = {
    from(table: string) {
      assertEquals(table, "guide_dialog_logs");
      return {
        select(columns: string) {
          assertEquals(columns, "extra_payload,created_at");
          return {
            eq(column: string, value: string) {
              assertExists(column);
              assertExists(value);
              return this;
            },
            order(column: string, options: { ascending: boolean }) {
              assertEquals(column, "created_at");
              assertEquals(options.ascending, false);
              return this;
            },
            limit(count: number) {
              assertEquals(count, 5);
              return Promise.resolve({
                data: [
                  {
                    extra_payload: {
                      suggested_task: {
                        title: "恢复支线：喝水并站起来",
                        description: "先恢复身体状态",
                        xp_reward: 12,
                        quest_tier: "Daily",
                      },
                    },
                    created_at: "2026-03-23T10:00:00.000Z",
                  },
                ],
                error: null,
              });
            },
          };
        },
      };
    },
  };

  const task = await getLatestSuggestedTask(supabase, "user-1", "wechat");

  assertEquals(task?.title, "恢复支线：喝水并站起来");
  assertEquals(task?.quest_tier, "Daily");
});

Deno.test("acceptLatestSuggestedTask 会把最近建议任务写入 quest_nodes", async () => {
  let insertedQuestPayload: Record<string, unknown> | null = null;
  const supabase = {
    from(table: string) {
      if (table === "guide_dialog_logs") {
        return {
          select(columns: string) {
            assertEquals(columns, "extra_payload,created_at");
            return {
              eq() {
                return this;
              },
              order() {
                return this;
              },
              limit() {
                return Promise.resolve({
                  data: [
                    {
                      extra_payload: {
                        suggested_task: {
                          title: "恢复支线：闭眼呼吸 3 分钟",
                          description: "给大脑一点缓冲",
                          xp_reward: 16,
                          quest_tier: "Daily",
                        },
                      },
                      created_at: "2026-03-23T10:00:00.000Z",
                    },
                  ],
                  error: null,
                });
              },
            };
          },
        };
      }

      if (table === "quest_nodes") {
        return {
          insert(payload: Record<string, unknown>) {
            insertedQuestPayload = payload;
            return {
              select() {
                return {
                  single() {
                    return Promise.resolve({
                      data: { id: "quest-1" },
                      error: null,
                    });
                  },
                };
              },
            };
          },
        };
      }

      throw new Error(`unexpected table: ${table}`);
    },
  };

  const result = await acceptLatestSuggestedTask(supabase, "user-1", "wechat");

  assertEquals(result.accepted, true);
  assertEquals(result.inserted_quest_id, "quest-1");
  assertEquals(insertedQuestPayload?.["title"], "恢复支线：闭眼呼吸 3 分钟");
});

Deno.test("resolveGuideDisplayName 会优先使用服务端 display_name", async () => {
  const supabase = {
    from(table: string) {
      assertEquals(table, "guide_user_settings");
      return {
        upsert(payload: Record<string, unknown>) {
          assertEquals(payload.user_id, "user-1");
          return {
            select() {
              return {
                single() {
                  return Promise.resolve({
                    data: {
                      ...payload,
                      display_name: "阿木",
                    },
                    error: null,
                  });
                },
              };
            },
          };
        },
      };
    },
  };

  const name = await resolveGuideDisplayName(supabase, "user-1", {
    guide_name: "小忆",
  });

  assertEquals(name, "阿木");
});

Deno.test("resolveGuideDisplayName 会在服务端缺失时回退到客户端名字", async () => {
  const supabase = {
    from() {
      return {
        upsert(payload: Record<string, unknown>) {
          return {
            select() {
              return {
                single() {
                  return Promise.resolve({
                    data: payload,
                    error: null,
                  });
                },
              };
            },
          };
        },
      };
    },
  };

  const name = await resolveGuideDisplayName(supabase, "user-1", {
    guide_name: "小忆",
  });

  assertEquals(name, "小忆");
});
