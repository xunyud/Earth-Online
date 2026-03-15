# Gamified Quest Log Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor the "Chat-to-Timeline" app into a "Gamified Quest Log" with hierarchical quest structures, theming support, and gamification elements (XP).

**Architecture:**
- **Frontend (Flutter):** Implement `ThemeExtension` for theme switching. Replace `TimelineView` with `QuestBoard` (tree view). Add `QuestItem` with `SubQuestList`.
- **Backend (Supabase Edge Functions):** Update `process-tasks` to support hierarchical task extraction (Main/Side/Sub-quests) and XP assignment via LLM.
- **Database (Supabase):** Migrate `parsed_tasks` to `quest_nodes` with `parent_id` and `quest_tier`.

**Tech Stack:** Flutter, Supabase Edge Functions (Deno), Upstash Redis, OpenAI API, PostgreSQL.

---

### Task 1: Database Schema Migration

**Files:**
- Create: `schema_v2.sql`

**Step 1: Define New Schema**

Create `schema_v2.sql` to define the `quest_nodes` table.

```sql
-- Create Quest Nodes Table
create table if not exists quest_nodes (
  id uuid primary key default uuid_generate_v4(),
  user_id text not null,
  parent_id uuid references quest_nodes(id), -- Hierarchical link
  title text not null,
  quest_tier text check (quest_tier in ('Main_Quest', 'Side_Quest', 'Daily')),
  original_context text[] default '{}',
  is_completed boolean default false,
  xp_reward int default 0,
  created_at timestamptz default now()
);

-- Optional: Create index for performance
create index idx_quest_nodes_user_parent on quest_nodes(user_id, parent_id);
```

### Task 2: Backend Logic Update (LLM & Processor)

**Files:**
- Modify: `supabase/functions/process-tasks/index.ts`

**Step 1: Update LLM Prompt & Function Schema**

Update `supabase/functions/process-tasks/index.ts` to instruct the LLM to generate hierarchical quests with XP.

```typescript
// ... inside extractTasks function
// Update system prompt
const systemPrompt = `You are the "Quest Master" AI of an RPG game. Your job is to analyze chaotic chat logs from the user and synthesize them into a structured Quest Tree.
Rules:
1. Identify Tiers: "Main_Quest" (crucial), "Side_Quest" (minor), "Daily".
2. Breakdown Sub-quests: If a message implies multiple steps, create a parent node and multiple child nodes.
3. Assign XP: 10-100 based on difficulty.
4. Output a flat JSON array of QuestNode objects. Use temporary IDs (e.g., "temp_1", "temp_2") for linking parent_id. Root nodes have parent_id: null.`;

// Update function definition parameters
const functionParams = {
    type: "object",
    properties: {
        quests: {
            type: "array",
            items: {
                type: "object",
                properties: {
                    temp_id: { type: "string", description: "Temporary ID for linking children" },
                    parent_temp_id: { type: "string", nullable: true, description: "Temporary ID of parent node" },
                    title: { type: "string" },
                    quest_tier: { type: "string", enum: ["Main_Quest", "Side_Quest", "Daily"] },
                    xp_reward: { type: "number" },
                    // ... other fields
                },
                required: ["temp_id", "title", "quest_tier", "xp_reward"]
            }
        }
    },
    required: ["quests"]
};
```

**Step 2: Implement ID Resolution Logic**

Since the LLM returns temporary IDs, we need to resolve them to real UUIDs before inserting into Supabase.

```typescript
// ... inside process-tasks/index.ts

// Logic to map temp_ids to real UUIDs (using crypto.randomUUID() or similar)
// 1. Generate real UUID for each node
// 2. Map parent_temp_id to the real UUID of the parent
// 3. Insert into DB (order matters: parents first or defer constraints, but parents first is safer)
```

### Task 3: Flutter Theme Architecture

**Files:**
- Create: `frontend/lib/theme/quest_theme.dart`
- Modify: `frontend/lib/main.dart`

**Step 1: Create Theme Extension**

Create `frontend/lib/theme/quest_theme.dart`.

```dart
import 'package:flutter/material.dart';

@immutable
class QuestTheme extends ThemeExtension<QuestTheme> {
  final Color mainQuestColor;
  final Color sideQuestColor;
  final Color dailyQuestColor;
  final TextStyle questTitleStyle;

  const QuestTheme({
    required this.mainQuestColor,
    required this.sideQuestColor,
    required this.dailyQuestColor,
    required this.questTitleStyle,
  });

  @override
  QuestTheme copyWith({Color? mainQuestColor, Color? sideQuestColor, Color? dailyQuestColor, TextStyle? questTitleStyle}) {
    return QuestTheme(
      mainQuestColor: mainQuestColor ?? this.mainQuestColor,
      sideQuestColor: sideQuestColor ?? this.sideQuestColor,
      dailyQuestColor: dailyQuestColor ?? this.dailyQuestColor,
      questTitleStyle: questTitleStyle ?? this.questTitleStyle,
    );
  }

  @override
  QuestTheme lerp(ThemeExtension<QuestTheme>? other, double t) {
    if (other is! QuestTheme) return this;
    return QuestTheme(
      mainQuestColor: Color.lerp(mainQuestColor, other.mainQuestColor, t)!,
      sideQuestColor: Color.lerp(sideQuestColor, other.sideQuestColor, t)!,
      dailyQuestColor: Color.lerp(dailyQuestColor, other.dailyQuestColor, t)!,
      questTitleStyle: TextStyle.lerp(questTitleStyle, other.questTitleStyle, t)!,
    );
  }
}
```

**Step 2: Define Themes**

Add factory constructors for `DarkSouls` and `BrightWorld` themes in `QuestTheme`.

### Task 4: Flutter Quest Models & Logic

**Files:**
- Create: `frontend/lib/models/quest_node.dart`
- Create: `frontend/lib/services/quest_service.dart`

**Step 1: Create QuestNode Model**

`frontend/lib/models/quest_node.dart` matching `schema_v2`.

**Step 2: Tree Construction Logic**

Implement logic in `QuestService` (or `QuestBoard` controller) to fetch flat list and build a tree.

```dart
List<QuestNode> buildTree(List<QuestNode> flatList) {
  // 1. Map all nodes by ID
  // 2. Assign children to parents
  // 3. Return list of root nodes
}
```

### Task 5: Flutter UI Components

**Files:**
- Create: `frontend/lib/widgets/quest_item.dart`
- Create: `frontend/lib/widgets/sub_quest_list.dart`
- Create: `frontend/lib/widgets/quest_board.dart`

**Step 1: Implement QuestItem**

`QuestItem` renders the card, checkbox, and expasion logic.

**Step 2: Implement SubQuestList**

Recursive or simple list rendering for children.

**Step 3: Implement QuestBoard**

Main view that uses `QuestService` to fetch data and renders `ListView` of root `QuestItem`s.

### Task 6: Completion Logic & Animation

**Files:**
- Modify: `frontend/lib/widgets/quest_item.dart`

**Step 1: Add Animation**

Implement `CompletionAnimation` (e.g., scale transition or particle effect) when checkbox is checked.

**Step 2: Handle Completion**

Call Supabase to update `is_completed = true`.
Logic: "If ALL child nodes of a parent are complete, auto-prompt the user or auto-complete the parent." -> Handle this in frontend state management or backend trigger. For MVP, frontend check is easier.
```

