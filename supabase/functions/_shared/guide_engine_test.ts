import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { writeGuideDialogLog } from "./guide_engine.ts";

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
