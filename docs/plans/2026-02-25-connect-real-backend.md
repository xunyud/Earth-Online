# Frontend-Backend Integration Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将前端 Mock 逻辑替换为真实的 `parse-quest` Edge Function 调用。

**Architecture:**
- **Service Layer (`QuestService`):** 封装 Supabase Edge Function 调用。
- **State Layer (`QuestController`):** 调用 Service，处理返回数据并更新 UI。

**Tech Stack:** Flutter, Supabase Client.

---

### Task 1: 更新 QuestService

**Files:**
- Modify: `frontend/lib/core/services/quest_service.dart`

**Step 1: 增加 parseAndCreateQuest 方法**
- 输入: `String text`, `String userId`.
- 逻辑: 调用 `supabase.functions.invoke('parse-quest', body: {'text': text, 'user_id': userId})`.
- 返回: `List<QuestNode>`.
- 错误处理: Try-catch 块，抛出自定义异常或返回空列表。

### Task 2: 更新 QuestController

**Files:**
- Modify: `frontend/lib/features/quest/controllers/quest_controller.dart`

**Step 1: 替换 simulateAIParsing**
- 获取当前用户 ID (`_supabase.auth.currentUser?.id`).
- 调用 `QuestService.parseAndCreateQuest`.
- 成功: 将返回的 `List<QuestNode>` 添加到 `_quests` 列表（注意：因为 Realtime 也会推送，可能会有重复，但通常 Edge Function 写入数据库后 Realtime 才会推送。这里我们可能只需要依赖 Realtime，或者为了响应速度先 Optimistic Add。鉴于 `parse-quest` 已经写入数据库，最佳实践是**等待 Realtime 推送**，或者如果 Realtime 有延迟，手动 fetch 一次。但题目要求 "获取返回的新任务后，更新本地状态"，为了即时反馈，我们可以手动合并）。
- **优化策略**: Edge Function 返回的是 DB 记录。如果 Realtime 很快，我们可能会看到两次添加（一次手动，一次 Realtime）。
    - 方案 A: 只依赖 Realtime（UI 响应慢一点点，但在 Edge Function 返回前 Realtime 可能已经到了）。
    - 方案 B: 手动添加，并处理去重。
    - **决定**: 手动添加，因为 Realtime 监听逻辑里有 `add`。为了防止重复，我们可以检查 ID 是否存在。

**Step 2: 错误处理**
- 如果 Service 抛出异常，`_isAnalyzing = false`，并可能通过 `notifyListeners` 或 callback 通知 UI 显示错误（比如 Snackbar）。

---

### Execution Steps

1.  **Service**: Update `QuestService` with API call.
2.  **Controller**: Update `QuestController` to use Service.
3.  **Verify**: Run app and test input.
