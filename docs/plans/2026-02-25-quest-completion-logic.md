# Quest Completion Logic & UI Update Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 修改任务完成逻辑，确保完成的任务保留在列表中并呈现“已失效”视觉效果，而不是直接消失。

**Architecture:**
- **State Layer (`QuestController`):** 修改 `completeQuest` 方法，移除删除逻辑，改为更新状态。同时确保初始化获取数据时包含已完成的任务（或者根据需求过滤，但当前需求是保留在列表中）。
- **UI Layer (`QuestItem`):** 修改 `build` 方法，根据 `isCompleted` 状态应用 `Opacity` 和文本样式。

**Tech Stack:** Flutter, Provider/ChangeNotifier.

---

### Task 1: 修改逻辑层 (QuestController)

**Files:**
- Modify: `frontend/lib/features/quest/controllers/quest_controller.dart`

**Step 1: 修改 fetch 逻辑**
- 修改 `_fetchQuests`：移除 `.eq('is_completed', false)` 过滤条件，以便加载所有任务（包括已完成的）。

**Step 2: 修改完成逻辑**
- 重命名 `completeQuest` 为 `toggleQuestCompletion`（语义更准确）。
- 移除 `_quests.removeWhere(...)`。
- 实现：找到对应任务 -> `isCompleted = !isCompleted` -> `notifyListeners()`。
- 确保 Supabase 更新逻辑同步发送 `is_completed` 的新值。

### Task 2: 修改表现层 (QuestItem)

**Files:**
- Modify: `frontend/lib/features/quest/widgets/quest_item.dart`

**Step 1: 应用视觉样式**
- 在最外层（`MouseRegion` 或 `AnimatedContainer`）包裹 `Opacity` 组件。
    - `opacity: widget.quest.isCompleted ? 0.5 : 1.0`。
- 确认 `ListTile` 中的 `title` 样式：
    - `decoration: widget.quest.isCompleted ? TextDecoration.lineThrough : null`。
    - `color: widget.quest.isCompleted ? AppColors.textHint : null`。

**Step 2: 交互优化**
- 确保点击 Checkbox 时触发的是 `toggleQuestCompletion`，并且 UI 能够平滑过渡。

### Task 3: 适配 QuestBoard

**Files:**
- Modify: `frontend/lib/features/quest/widgets/quest_board.dart`
- Modify: `frontend/lib/features/quest/screens/home_page.dart`

**Step 1: 更新回调传递**
- 确保 `QuestBoard` 和 `HomePage` 传递的是新的 `toggleQuestCompletion` 方法（如果改名了）。

---

### Execution Steps

1.  **Logic**: Update `QuestController`.
2.  **UI**: Update `QuestItem` visual states.
3.  **Verify**: Run and test toggling.
