# Quick Create Modal Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Flutter quick-create modal so one dialog supports new main-plus-side creation, side attachment to an existing main quest, and daily quest creation with a daily HH:mm deadline.

**Architecture:** Keep the change centered in `frontend/lib/features/quest/screens/home_page.dart`. Reuse the existing `QuestDialogShell` UI shell and `QuestController.createManualQuest(...)`, expanding the dialog result model so the page can sequence main-quest creation first and then create side quests against the returned id.

**Tech Stack:** Flutter, Dart, flutter_test, existing ChangeNotifier quest flow

---

## Chunk 1: Specs And Logging

### Task 1: Persist approved design context before implementation

**Files:**
- Create: `docs/superpowers/specs/2026-04-01-quick-create-modal-design.md`
- Create: `docs/superpowers/plans/2026-04-01-quick-create-modal-redesign.md`
- Modify: `.codex/operations-log.md`

- [ ] **Step 1: Write the approved design spec**

Capture the approved visual direction, the three flows, and the requirement that the existing “attach side quest to an existing main quest” path must remain inside the same modal.

- [ ] **Step 2: Record the execution plan**

Document the file scope, implementation order, and verification commands.

- [ ] **Step 3: Append a progress log entry**

Record that the task is not blocked and has moved from design approval into implementation.

## Chunk 2: Modal Structure And Submission Flow

### Task 2: Replace the old quick-create structure with a unified creation panel

**Files:**
- Modify: `frontend/lib/features/quest/screens/home_page.dart`
- Reference: `frontend/lib/shared/widgets/quest_dialog_shell.dart`
- Reference: `frontend/lib/core/theme/quest_theme.dart`

- [ ] **Step 1: Write the failing source test**

Update or add a source test that looks for:
- a dedicated new-main-with-sides flow
- a preserved attach-to-existing-main flow
- a daily flow with `showTimePicker`
- removal of `DropdownButtonFormField<String>` from the quick-create modal path

- [ ] **Step 2: Run the source test to verify the red state**

Run:

```bash
flutter test test/quest_manual_creation_source_test.dart
```

Expected:
- the new source assertions fail until the modal is reworked

- [ ] **Step 3: Implement the modal redesign**

In `home_page.dart`:
- expand the dialog result payload to support the three flows
- add a polished segmented/card-based mode selector
- add inline side-draft editing for the new-main flow
- add a custom existing-main selector for the attach flow
- keep the daily time picker flow and restyle its presentation
- sequence `createManualQuest(...)` calls so the main quest is created before any drafted side quests

- [ ] **Step 4: Run the source test again**

Run:

```bash
flutter test test/quest_manual_creation_source_test.dart
```

Expected:
- the quick-create source test passes with the new structure

## Chunk 3: Validation And Documentation

### Task 3: Format, analyze, and verify the redesigned modal

**Files:**
- Modify: `frontend/test/quest_manual_creation_source_test.dart`
- Modify: `.codex/testing.md`
- Modify: `verification.md`

- [ ] **Step 1: Run formatting**

Run:

```bash
dart format lib/features/quest/screens/home_page.dart test/quest_manual_creation_source_test.dart
```

Expected:
- formatting completes without errors

- [ ] **Step 2: Run analysis**

Run:

```bash
dart analyze lib/features/quest/screens/home_page.dart
```

Expected:
- no new analyzer errors in the quick-create implementation

- [ ] **Step 3: Run targeted tests**

Run:

```bash
flutter test test/quest_manual_creation_source_test.dart test/quest_controller_daily_reset_source_test.dart test/quest_node_test.dart
```

Expected:
- all targeted quest creation tests pass

- [ ] **Step 4: Update verification records**

Append commands and outcomes to `.codex/testing.md` and `verification.md`.
