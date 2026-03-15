# Quest Drag & Drop Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement drag-and-drop functionality for `QuestItem` to support quest nesting (dropping onto another quest) and tier changes (dropping into a tier zone) with optimistic updates.

**Architecture:**
- **UI:** Wrap `QuestItem` in `LongPressDraggable`. Create `DragTarget` areas for nesting (on quests) and tier headers.
- **State:** Optimistic UI updates handled in `QuestBoard` or parent `HomePage` state.
- **Backend:** Supabase calls to update `parent_id` and `quest_tier` asynchronously.

**Tech Stack:** Flutter, Supabase.

---

### Task 1: Refactor QuestItem for Dragging & Nesting

**Files:**
- Modify: `frontend/lib/widgets/quest_item.dart`

**Step 1: Wrap with LongPressDraggable**
Wrap the `Card` widget with `LongPressDraggable<QuestNode>`.
- `data`: The current `quest`.
- `feedback`: A semi-transparent clone of the card (use `Material` widget to ensure styling).
- `childWhenDragging`: A greyed-out placeholder or the original card.

**Step 2: Wrap with DragTarget for Nesting**
Wrap the draggable widget (or the Card) with `DragTarget<QuestNode>`.
- `onWillAccept`: Return true if `data.id != quest.id` (cannot drop on self) and ideally check for circular dependency (optional for MVP).
- `onAccept`: Invoke a callback `onQuestNest(QuestNode parent, QuestNode child)`.
- `builder`: Change appearance (border highlight) when `candidateData` is not empty to indicate a drop zone.

**Step 3: Update Constructor**
Add `onQuestNest` callback to `QuestItem` constructor.

### Task 2: Implement Tier Drop Zones

**Files:**
- Create: `frontend/lib/widgets/tier_section.dart`
- Modify: `frontend/lib/widgets/quest_board.dart`

**Step 1: Create TierSection Widget**
Create a widget that represents a Tier Header (e.g., "Main Quests") and acts as a `DragTarget`.
- Accepts `title`, `questTier` (enum/string), `color`.
- `DragTarget<QuestNode>` logic:
    - `onAccept`: Invoke `onQuestTierChange(QuestNode quest, String newTier)`.
    - Visual feedback on hover.

**Step 2: Update QuestBoard Layout**
Refactor `QuestBoard` to use a `CustomScrollView` with `SliverList` or just a `ListView` with section headers.
- Group quests by tier.
- Render `TierSection` followed by the list of quests for that tier.

### Task 3: State Management & Supabase Sync

**Files:**
- Modify: `frontend/lib/main.dart`
- Modify: `frontend/lib/widgets/quest_board.dart`

**Step 1: Add Callbacks to QuestBoard**
Update `QuestBoard` to accept `onQuestNest` and `onQuestTierChange` callbacks. Pass them down to `TierSection` and `QuestItem`.

**Step 2: Implement Logic in HomePage**
- `_handleQuestNest(QuestNode parent, QuestNode child)`:
    - Update local state: `child.parentId = parent.id`.
    - Async Supabase: `update({ parent_id: parent.id }).eq('id', child.id)`.
    - Error handling: Revert on exception.
- `_handleQuestTierChange(QuestNode quest, String newTier)`:
    - Update local state: `quest.questTier = newTier`, `quest.parentId = null`.
    - Async Supabase: `update({ quest_tier: newTier, parent_id: null }).eq('id', quest.id)`.
    - Error handling: Revert.

**Step 3: Handle Recursion/Circular Dependency (Basic)**
- Prevent dropping a parent onto its own child (visual check or logical check).

### Task 4: Visual Polish

**Files:**
- Modify: `frontend/lib/widgets/quest_item.dart`

**Step 1: Feedback Widget Styling**
Ensure the dragged feedback widget looks good (width constraints, opacity).

**Step 2: Drop Zone Highlighting**
Add a border or background color change when hovering over a drop target.
