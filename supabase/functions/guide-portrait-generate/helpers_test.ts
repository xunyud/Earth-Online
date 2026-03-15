import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { resolveAccessibleImageUrl } from "./helpers.ts";

Deno.test("resolveAccessibleImageUrl 在探测成功时返回探测后的地址", async () => {
  const result = await resolveAccessibleImageUrl(
    "https://example.com/raw.png",
    async (url: string) => `${url}?resolved=1`,
  );

  assertEquals(result, "https://example.com/raw.png?resolved=1");
});

Deno.test("resolveAccessibleImageUrl 在探测失败时回退原始地址", async () => {
  const result = await resolveAccessibleImageUrl(
    "https://example.com/raw.png",
    async () => {
      throw new Error("probe failed");
    },
  );

  assertEquals(result, "https://example.com/raw.png");
});
