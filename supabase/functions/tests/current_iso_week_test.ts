// 单元测试：验证 currentIsoWeek 函数在已知日期下返回正确的 ISO 周标识。
// 覆盖常规日期、跨年边界、闰年等场景。

import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { currentIsoWeek } from "../guide-portrait-generate/helpers.ts";

Deno.test("currentIsoWeek — 常规日期返回正确 ISO 周", () => {
  // 2026-06-01 是周一，ISO 周 23
  assertEquals(currentIsoWeek(new Date("2026-06-01")), "2026-W23");
  // 2026-01-01 是周四，属于 2026-W01
  assertEquals(currentIsoWeek(new Date("2026-01-01")), "2026-W01");
});

Deno.test("currentIsoWeek — 跨年边界：年末日期可能属于下一年的 ISO 周", () => {
  // 2025-12-29 是周一，属于 2026-W01（因为该周的周四是 2026-01-01）
  assertEquals(currentIsoWeek(new Date("2025-12-29")), "2026-W01");
});

Deno.test("currentIsoWeek — 跨年边界：年初日期可能属于上一年的 ISO 周", () => {
  // 2016-01-01 是周五，属于 2015-W53
  assertEquals(currentIsoWeek(new Date("2016-01-01")), "2015-W53");
});

Deno.test("currentIsoWeek — 返回格式匹配 YYYY-Wnn", () => {
  const result = currentIsoWeek(new Date("2026-04-22"));
  const pattern = /^\d{4}-W\d{2}$/;
  assertEquals(pattern.test(result), true, `格式不匹配: ${result}`);
});

Deno.test("currentIsoWeek — 同一日期始终返回相同结果（幂等性）", () => {
  const d = new Date("2026-07-15");
  assertEquals(currentIsoWeek(d), currentIsoWeek(d));
});

Deno.test("currentIsoWeek — 不修改传入的 Date 对象", () => {
  const d = new Date("2026-03-10T15:30:00Z");
  const originalTime = d.getTime();
  currentIsoWeek(d);
  assertEquals(d.getTime(), originalTime, "传入的 Date 对象不应被修改");
});

Deno.test("currentIsoWeek — 无参数时使用当前时间（不抛错）", () => {
  const result = currentIsoWeek();
  const pattern = /^\d{4}-W\d{2}$/;
  assertEquals(pattern.test(result), true, `无参数调用格式不匹配: ${result}`);
});
