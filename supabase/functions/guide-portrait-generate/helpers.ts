export type ImageUrlProbe = (url: string) => Promise<string>;

export async function resolveAccessibleImageUrl(
  imageUrl: string,
  probe: ImageUrlProbe,
) {
  const rawUrl = imageUrl.trim();
  if (!rawUrl) return "";
  try {
    const resolvedUrl = (await probe(rawUrl)).trim();
    return resolvedUrl.length > 0 ? resolvedUrl : rawUrl;
  } catch {
    return rawUrl;
  }
}
/**
 * 计算给定日期的 ISO 8601 周标识字符串。
 *
 * 返回格式：`YYYY-Wnn`，其中 YYYY 为 ISO 年份，nn 为零填充的周数（01–53）。
 *
 * ISO 周规则：
 * - 每周从周一开始
 * - 第 1 周是包含该年第一个周四的那一周
 * - 年末/年初边界处 ISO 年份可能与日历年份不同
 *
 * @param date 可选日期参数，默认为当前时间（便于测试注入）
 */
export function currentIsoWeek(date?: Date): string {
  const d = date ? new Date(date.getTime()) : new Date();
  d.setHours(0, 0, 0, 0);
  // 调整到最近的周四（ISO 周的基准日）
  d.setDate(d.getDate() + 3 - ((d.getDay() + 6) % 7));
  const isoYear = d.getFullYear();
  // 该年 1 月 4 日所在周的周四（即第 1 周的周四）
  const yearStart = new Date(isoYear, 0, 4);
  yearStart.setDate(yearStart.getDate() + 3 - ((yearStart.getDay() + 6) % 7));
  // 周数 = 两个周四之间的天数 / 7 + 1
  const weekNum = 1 + Math.round((d.getTime() - yearStart.getTime()) / (7 * 86400000));
  return `${isoYear}-W${String(weekNum).padStart(2, "0")}`;
}
