# Fix UUID Error via Anonymous Sign-in Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 通过启用 Supabase 匿名登录，确保应用内所有 API 调用都使用合法的 UUID，修复 `mock_user` 导致的数据库错误。

**Architecture:**
- **Auth Flow:** App Start -> Check `currentUser` -> If null, `signInAnonymously()`.
- **Data Flow:** All `QuestController` and `BindingView` logic uses `currentUser.id`.

**Tech Stack:** Flutter, Supabase Auth.

---

### Task 1: 实现匿名登录

**Files:**
- Modify: `frontend/lib/main.dart`

**Step 1: 初始化时检查登录状态**
- 在 `main` 函数或 `MyApp` 初始化逻辑中，增加 `_checkAuth` 方法。
- 如果 `Supabase.instance.client.auth.currentUser` 为空，调用 `signInAnonymously()`。

### Task 2: 清理 Mock Data

**Files:**
- Modify: `frontend/lib/features/quest/controllers/quest_controller.dart`
- Check: `frontend/lib/features/binding/screens/binding_view.dart` (确认是否使用了 mock)

**Step 1: 替换 QuestController 中的 mock_user**
- 在 `simulateAIParsing` (现为真实调用) 中，将 `userId` 的回退值 `'mock_user'` 移除，改为强制获取当前用户 ID，如果为空则抛出异常（理论上 Task 1 保证了不为空）。

**Step 2: 检查其他位置**
- 搜索整个项目，确保没有遗留的 `'mock_user'` 字符串。

---

### Execution Steps

1.  **Auth**: Update `main.dart` to ensure anonymous sign-in.
2.  **Cleanup**: Remove `'mock_user'` from `QuestController`.
3.  **Verify**: Run app, check logs for successful sign-in and valid UUID usage.
