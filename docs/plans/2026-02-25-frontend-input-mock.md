# Frontend Input & Mock State Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现前端输入逻辑和模拟状态流转，增加 `QuickAddBar` 和 `QuestProvider`，以测试纯前端的数据流和交互。

**Architecture:**
- **State Management:** 使用 `ChangeNotifier` (QuestProvider) 管理任务列表和解析状态。
- **UI Components:**
    - `QuickAddBar`: 底部输入框。
    - `QuestBoard`: 适配 Loading 状态。
- **Mock Logic:** 本地模拟 AI 解析过程，生成测试数据。

**Tech Stack:** Flutter, Provider (or native ChangeNotifier).

---

### Task 1: 状态管理层 (QuestProvider)

**Files:**
- Create: `frontend/lib/features/quest/providers/quest_provider.dart`
- Modify: `frontend/lib/main.dart` (注册 Provider，如果使用 Provider 包；或者是将 State 提升)
- **Note:** 为了保持简单且无需额外引入 `provider` 包（如果尚未引入），我们将使用 `ChangeNotifier` 配合 `AnimatedBuilder` 或者直接在 `HomePage` 的 State 中维护，但为了解耦，建议创建一个独立的 Controller 类。鉴于用户提到 "Simple State Management"，我们将创建一个 `QuestController` (extends ChangeNotifier)。

**Step 1: 创建 QuestController**

创建 `frontend/lib/features/quest/controllers/quest_controller.dart`。
- `quests`: `List<QuestNode>`
- `isAnalyzing`: `bool`
- `simulateAIParsing(String input)`: 模拟逻辑。

```dart
// 伪代码
class QuestController extends ChangeNotifier {
  // ... state ...
  Future<void> simulateAIParsing(String input) async {
     isAnalyzing = true;
     notifyListeners();
     await Future.delayed(Duration(seconds: 2));
     // ... add mock quest ...
     isAnalyzing = false;
     notifyListeners();
  }
}
```

### Task 2: 底部输入组件 (QuickAddBar)

**Files:**
- Create: `frontend/lib/features/quest/widgets/quick_add_bar.dart`

**Step 1: 实现 QuickAddBar**

- `TextField`
- `IconButton` (Send)
- `onSubmitted` 回调

### Task 3: 更新 QuestBoard & 集成

**Files:**
- Modify: `frontend/lib/features/quest/screens/home_page.dart`
- Modify: `frontend/lib/features/quest/widgets/quest_board.dart`

**Step 1: 集成 Controller 到 HomePage**

- 在 `HomePage` 初始化 `QuestController`。
- 使用 `ListenableBuilder` (Flutter 原生) 监听 Controller 变化。

**Step 2: 更新 UI 布局**

- `Scaffold` body 改为 `Column`。
- `Expanded(child: QuestBoard)`
- `QuickAddBar` 放在底部。

**Step 3: 添加 Loading 状态到 QuestBoard**

- 在 `QuestBoard` 顶部添加 `if (isAnalyzing) ...` 显示 Loading Indicator。

---

### Execution Steps

1.  **Create Controller**: 实现 `QuestController` 及其 Mock 逻辑。
2.  **Create Widget**: 实现 `QuickAddBar`。
3.  **Refactor Screen**: 重构 `HomePage` 使用 Controller 和新布局。
4.  **Verify**: 运行并测试输入。
