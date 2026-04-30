// Feature: memory-system-evolution, Property 7: ISO week epoch computation
// **Validates: Requirements 3.1, 3.2**
//
// 属性测试：验证 currentIsoWeek 对任意有效日期返回格式正确、周数合法、
// 结果幂等且同一 ISO 周内日期产出相同 epoch 字符串。

import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import * as fc from "https://esm.sh/fast-check@3.15.0";
import { currentIsoWeek } from "../guide-portrait-generate/helpers.ts";

// --- 属性 7a：格式匹配 YYYY-Wnn ---
Deno.test("Property 7a: 任意有效日期返回格式匹配 /^\\d{4}-W\\d{2}$/", () => {
  const pattern = /^\d{4}-W\d{2}$/;
  fc.assert(
    fc.property(
      fc.date({ min: new Date("2000-01-01"), max: new Date("2099-12-31") }),
      (d: Date) => {
        const result = currentIsoWeek(d);
        assertEquals(
          pattern.test(result),
          true,
          `日期 ${d.toISOString()} 返回 "${result}"，不匹配 YYYY-Wnn 格式`,
        );
      },
    ),
    { numRuns: 200 },
  );
});

// --- 属性 7b：周数范围 01–53 ---
Deno.test("Property 7b: 周数 nn 在 01–53 范围内", () => {
  fc.assert(
    fc.property(
      fc.date({ min: new Date("2000-01-01"), max: new Date("2099-12-31") }),
      (d: Date) => {
        const result = currentIsoWeek(d);
        const weekStr = result.split("-W")[1];
        const weekNum = parseInt(weekStr, 10);
        assertEquals(
          weekNum >= 1 && weekNum <= 53,
          true,
          `日期 ${d.toISOString()} 返回周数 ${weekNum}，超出 1–53 范围`,
        );
      },
    ),
    { numRuns: 200 },
  );
});

// --- 属性 7c：幂等性 — 同一日期始终返回相同结果 ---
Deno.test("Property 7c: 同一日期多次调用返回相同结果（幂等性）", () => {
  fc.assert(
    fc.property(
      fc.date({ min: new Date("2000-01-01"), max: new Date("2099-12-31") }),
      (d: Date) => {
        const r1 = currentIsoWeek(d);
        const r2 = currentIsoWeek(d);
        const r3 = currentIsoWeek(new Date(d.getTime()));
        assertEquals(r1, r2, `同一 Date 对象两次调用结果不同: "${r1}" vs "${r2}"`);
        assertEquals(r1, r3, `相同时间戳的新 Date 对象结果不同: "${r1}" vs "${r3}"`);
      },
    ),
    { numRuns: 200 },
  );
});

// --- 属性 7d：同一 ISO 周内（周一到周日）产出相同 epoch ---
Deno.test("Property 7d: 同一 ISO 周内的日期产出相同 epoch 字符串", () => {
  fc.assert(
    fc.property(
      // 生成一个周一日期，然后验证该周一到周日都返回相同 epoch
      fc.date({ min: new Date("2000-01-05"), max: new Date("2099-12-25") }),
      (d: Date) => {
        // 将日期调整到所在周的周一（ISO 周从周一开始）
        const day = d.getDay(); // 0=周日, 1=周一, ..., 6=周六
        const diffToMonday = day === 0 ? -6 : 1 - day;
        const monday = new Date(d.getTime());
        monday.setDate(monday.getDate() + diffToMonday);
        monday.setHours(0, 0, 0, 0);

        const mondayEpoch = currentIsoWeek(monday);

        // 验证周一到周日（共 7 天）都返回相同 epoch
        for (let offset = 0; offset < 7; offset++) {
          const dayInWeek = new Date(monday.getTime());
          dayInWeek.setDate(dayInWeek.getDate() + offset);
          const dayEpoch = currentIsoWeek(dayInWeek);
          assertEquals(
            dayEpoch,
            mondayEpoch,
            `周一 ${monday.toISOString().slice(0, 10)} epoch="${mondayEpoch}"，` +
              `偏移 ${offset} 天后 ${dayInWeek.toISOString().slice(0, 10)} epoch="${dayEpoch}"`,
          );
        }
      },
    ),
    { numRuns: 100 },
  );
});
