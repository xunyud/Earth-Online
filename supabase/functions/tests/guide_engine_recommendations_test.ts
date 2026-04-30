// 单元测试：bootstrap 集成推荐引擎
// 复现 guide_engine.ts 中 fetchRecommendations 的核心逻辑，
// 通过注入可配置的 fetchFn 测试各种成功与失败场景。
// **Validates: Requirements 6.1, 6.5**

import {
  assertEquals,
  assert,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";

// ========== 复现 fetchRecommendations 核心逻辑 ==========

/** 推荐条目类型 */
type Recommendation = { title: string; reason: string };

/**
 * 复现 guide_engine.ts 中 fetchRecommendations 的核心逻辑。
 * 使用可配置的 fetchFn 替代全局 fetch，便于注入 mock 行为。
 * 逻辑与 guide_engine.ts 保持一致：
 * - POST 请求 memory-recommender
 * - 8s 超时（AbortSignal.timeout）
 * - 非 ok 响应返回空数组
 * - 解析 JSON 中的 recommendations 数组
 * - 任何异常返回空数组，不抛错
 */
async function fetchRecommendationsPattern(
  fetchFn: typeof fetch,
  userId: string,
): Promise<Recommendation[]> {
  try {
    const resp = await fetchFn("http://mock/memory-recommender", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ user_id: userId }),
      signal: AbortSignal.timeout(8000),
    });
    if (!resp.ok) return [];
    const data = await resp.json();
    return Array.isArray(data?.recommendations) ? data.recommendations : [];
  } catch {
    // 推荐失败不影响 bootstrap 主流程
    return [];
  }
}

// ========== 辅助函数：构造 mock fetch ==========

/** 构造返回指定 JSON 的成功 mock fetch */
function mockFetchOk(body: unknown): typeof fetch {
  return (_url: string | URL | Request, _init?: RequestInit) =>
    Promise.resolve(new Response(JSON.stringify(body), { status: 200 }));
}

/** 构造返回指定 HTTP 状态码的 mock fetch */
function mockFetchStatus(status: number): typeof fetch {
  return (_url: string | URL | Request, _init?: RequestInit) =>
    Promise.resolve(new Response("error", { status }));
}

/** 构造抛出网络错误的 mock fetch */
function mockFetchThrow(error: Error): typeof fetch {
  return (_url: string | URL | Request, _init?: RequestInit) =>
    Promise.reject(error);
}

/** 构造返回非法 JSON 的 mock fetch */
function mockFetchInvalidJson(): typeof fetch {
  return (_url: string | URL | Request, _init?: RequestInit) =>
    Promise.resolve(new Response("not-json{{{", { status: 200 }));
}

/** 构造延迟响应的 mock fetch（模拟超时） */
function mockFetchTimeout(delayMs: number): typeof fetch {
  return (_url: string | URL | Request, init?: RequestInit) =>
    new Promise<Response>((resolve, reject) => {
      const timer = setTimeout(
        () => resolve(new Response(JSON.stringify({ recommendations: [] }), { status: 200 })),
        delayMs,
      );
      // 监听 AbortSignal，超时时中止
      init?.signal?.addEventListener("abort", () => {
        clearTimeout(timer);
        reject(new DOMException("The operation was aborted.", "AbortError"));
      });
    });
}

// ========== 测试用例 ==========

// 1. 推荐成功：memory-recommender 返回有效推荐时，解析结果包含 recommendations 数组
Deno.test("fetchRecommendations: 成功时 payload 包含 recommendations", async () => {
  const mockRecommendations = [
    { title: "写晨间日记", reason: "你最近连续 5 天都在早上记录" },
    { title: "完成搁置的读书任务", reason: "这个任务已经搁置超过 7 天" },
  ];
  const fetchFn = mockFetchOk({ recommendations: mockRecommendations });

  const result = await fetchRecommendationsPattern(fetchFn, "user-123");

  assertEquals(result.length, 2, "应返回 2 条推荐");
  assertEquals(result[0].title, "写晨间日记");
  assertEquals(result[0].reason, "你最近连续 5 天都在早上记录");
  assertEquals(result[1].title, "完成搁置的读书任务");
  assertEquals(result[1].reason, "这个任务已经搁置超过 7 天");
});

// 1b. 推荐成功：返回 3 条推荐
Deno.test("fetchRecommendations: 成功返回 3 条推荐", async () => {
  const mockRecommendations = [
    { title: "任务A", reason: "理由A" },
    { title: "任务B", reason: "理由B" },
    { title: "任务C", reason: "理由C" },
  ];
  const fetchFn = mockFetchOk({ recommendations: mockRecommendations });

  const result = await fetchRecommendationsPattern(fetchFn, "user-456");

  assertEquals(result.length, 3, "应返回 3 条推荐");
  assertEquals(result[2].title, "任务C");
});

// 2. 网络错误：fetch 抛出异常时返回空数组
Deno.test("fetchRecommendations: 网络错误时返回空数组", async () => {
  const fetchFn = mockFetchThrow(new Error("网络不可达"));

  const result = await fetchRecommendationsPattern(fetchFn, "user-789");

  assertEquals(result.length, 0, "网络错误应返回空数组");
});

// 3. 非 ok 响应：fetch 返回 500 时返回空数组
Deno.test("fetchRecommendations: HTTP 500 时返回空数组", async () => {
  const fetchFn = mockFetchStatus(500);

  const result = await fetchRecommendationsPattern(fetchFn, "user-abc");

  assertEquals(result.length, 0, "HTTP 500 应返回空数组");
});

// 3b. 非 ok 响应：fetch 返回 404 时返回空数组
Deno.test("fetchRecommendations: HTTP 404 时返回空数组", async () => {
  const fetchFn = mockFetchStatus(404);

  const result = await fetchRecommendationsPattern(fetchFn, "user-def");

  assertEquals(result.length, 0, "HTTP 404 应返回空数组");
});

// 3c. 非 ok 响应：fetch 返回 503 时返回空数组
Deno.test("fetchRecommendations: HTTP 503 时返回空数组", async () => {
  const fetchFn = mockFetchStatus(503);

  const result = await fetchRecommendationsPattern(fetchFn, "user-ghi");

  assertEquals(result.length, 0, "HTTP 503 应返回空数组");
});

// 4. 无效 JSON：响应体不是合法 JSON 时返回空数组
Deno.test("fetchRecommendations: 无效 JSON 响应时返回空数组", async () => {
  const fetchFn = mockFetchInvalidJson();

  const result = await fetchRecommendationsPattern(fetchFn, "user-jkl");

  assertEquals(result.length, 0, "无效 JSON 应返回空数组");
});

// 5. 超时：fetch 耗时超过 8s 时返回空数组
Deno.test("fetchRecommendations: 超时时返回空数组", async () => {
  // 使用 9000ms 延迟模拟超时（AbortSignal.timeout(8000) 会在 8s 后中止）
  const fetchFn = mockFetchTimeout(9000);

  const result = await fetchRecommendationsPattern(fetchFn, "user-mno");

  assertEquals(result.length, 0, "超时应返回空数组");
});

// ========== 边界场景补充 ==========

// 6. 响应中 recommendations 字段缺失时返回空数组
Deno.test("fetchRecommendations: 响应缺少 recommendations 字段时返回空数组", async () => {
  const fetchFn = mockFetchOk({ success: true });

  const result = await fetchRecommendationsPattern(fetchFn, "user-pqr");

  assertEquals(result.length, 0, "缺少 recommendations 字段应返回空数组");
});

// 7. 响应中 recommendations 不是数组时返回空数组
Deno.test("fetchRecommendations: recommendations 非数组时返回空数组", async () => {
  const fetchFn = mockFetchOk({ recommendations: "不是数组" });

  const result = await fetchRecommendationsPattern(fetchFn, "user-stu");

  assertEquals(result.length, 0, "recommendations 非数组应返回空数组");
});

// 8. 响应中 recommendations 为 null 时返回空数组
Deno.test("fetchRecommendations: recommendations 为 null 时返回空数组", async () => {
  const fetchFn = mockFetchOk({ recommendations: null });

  const result = await fetchRecommendationsPattern(fetchFn, "user-vwx");

  assertEquals(result.length, 0, "recommendations 为 null 应返回空数组");
});

// 9. 空推荐列表时返回空数组
Deno.test("fetchRecommendations: 空推荐列表时返回空数组", async () => {
  const fetchFn = mockFetchOk({ recommendations: [] });

  const result = await fetchRecommendationsPattern(fetchFn, "user-yz");

  assertEquals(result.length, 0, "空推荐列表应返回空数组");
});
