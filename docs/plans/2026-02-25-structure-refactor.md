# Project Structure Refactoring Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor the Flutter frontend and Supabase backend project structure according to the agreed-upon Feature-First architecture.

**Architecture:**
- **Frontend (Flutter):** Move files to `lib/core`, `lib/features`, and `lib/shared`.
- **Backend (Supabase):** Organize SQL into `migrations` and create `_shared` for Edge Functions.

---

### Task 1: Frontend Structure Setup & File Migration

**Step 1: Create Directory Structure**
- Create `frontend/lib/core/constants`
- Create `frontend/lib/core/services`
- Create `frontend/lib/core/theme`
- Create `frontend/lib/features/quest/models`
- Create `frontend/lib/features/quest/screens`
- Create `frontend/lib/features/quest/widgets`
- Create `frontend/lib/features/binding/screens`
- Create `frontend/lib/shared/widgets`

**Step 2: Move Files**
- Move `frontend/lib/theme/quest_theme.dart` -> `frontend/lib/core/theme/quest_theme.dart`
- Move `frontend/lib/services/quest_service.dart` -> `frontend/lib/core/services/quest_service.dart`
- Move `frontend/lib/models/quest_node.dart` -> `frontend/lib/features/quest/models/quest_node.dart`
- Move `frontend/lib/widgets/quest_board.dart` -> `frontend/lib/features/quest/widgets/quest_board.dart`
- Move `frontend/lib/widgets/quest_item.dart` -> `frontend/lib/features/quest/widgets/quest_item.dart`
- Move `frontend/lib/widgets/sub_quest_list.dart` -> `frontend/lib/features/quest/widgets/sub_quest_list.dart`
- Move `frontend/lib/widgets/tier_section.dart` -> `frontend/lib/features/quest/widgets/tier_section.dart`
- Move `frontend/lib/widgets/binding_view.dart` -> `frontend/lib/features/binding/screens/binding_view.dart`
- Move `frontend/lib/widgets/sync_indicator.dart` -> `frontend/lib/shared/widgets/sync_indicator.dart`
- Extract `HomePage` from `frontend/lib/main.dart` -> `frontend/lib/features/quest/screens/home_page.dart`

**Step 3: Update Imports**
- Update all moved files to fix relative and package imports.
- Update `frontend/lib/main.dart` to point to the new location of `HomePage`.

### Task 2: Supabase Structure Setup

**Step 1: Create Directory Structure**
- Create `supabase/migrations`
- Create `supabase/functions/_shared`

**Step 2: Migrate SQL**
- Consolidate `schema.sql`, `schema_v2.sql`, `schema_v3.sql` into a single migration file in `supabase/migrations/20240225000000_initial_schema.sql`.
- (Optional) Remove old `.sql` files from root.

**Step 3: Shared Function Logic (Optional Placeholder)**
- Create a placeholder `cors.ts` in `supabase/functions/_shared/` if needed for future use.

### Task 3: Verification

- Verify `flutter run` builds successfully.
- Verify Supabase structure is clean.
