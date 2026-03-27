# System Shop Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a system shop to the existing Flutter reward shop so fixed system products appear on the left, custom rewards remain on the right, and redeemed system rewards continue through the existing inventory-to-reward-task flow.

**Architecture:** Reuse the existing `rewards` / `inventory` / `buy_reward` pipeline. Extend the Flutter reward UI to render responsive dual sections while keeping `RewardController` as the single data source, then add a Supabase migration that seeds daily-life system rewards without introducing new tables or parallel logic.

**Tech Stack:** Flutter, Dart, flutter_test, Supabase SQL migrations, existing ChangeNotifier architecture

---

## Chunk 1: Controller And Data Safety

### Task 1: Strengthen reward controller tests for system rewards

**Files:**
- Modify: `frontend/test/reward_controller_test.dart`
- Modify: `frontend/lib/features/reward/controllers/reward_controller.dart`

- [ ] **Step 1: Write the failing test**

Add tests that cover:
- `RewardController.isDeprecatedSystemReward` still filters only legacy theme rewards
- non-legacy system rewards with low price remain valid
- the controller logic does not reject a `1`-gold reward as an invalid boundary

Prefer a narrow test around controller-visible behavior or helper logic rather than UI.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/reward_controller_test.dart
```

Expected:
- at least one new assertion fails because current code or coverage does not yet support the intended system-shop behavior

- [ ] **Step 3: Write minimal implementation**

If needed, adjust `RewardController` so purchase validation only rejects negative prices or otherwise no longer blocks the approved low-price system reward path. Do not add a new service or state layer.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
flutter test test/reward_controller_test.dart
```

Expected:
- all tests in `reward_controller_test.dart` pass

- [ ] **Step 5: Commit**

```bash
git add frontend/test/reward_controller_test.dart frontend/lib/features/reward/controllers/reward_controller.dart
git commit -m "test: cover system shop reward controller behavior"
```

## Chunk 2: Reward Shop UI

### Task 2: Add source test for dual-column reward shop layout

**Files:**
- Create: `frontend/test/reward_shop_page_source_test.dart`
- Modify: `frontend/lib/features/reward/screens/reward_shop_page.dart`
- Modify: `frontend/lib/core/i18n/app_locale_controller.dart`

- [ ] **Step 1: Write the failing test**

Add a source-oriented Flutter test that checks the reward shop page for:
- a system-shop section label
- a custom-reward section label
- a dedicated builder or structure for system rewards
- no delete action in the system reward rendering path
- the custom reward rendering path still contains delete behavior

Use source assertions if direct widget pumping would be disproportionately expensive.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/reward_shop_page_source_test.dart
```

Expected:
- fail because the current page only renders custom rewards

- [ ] **Step 3: Write minimal implementation**

Update `RewardShopPage` to:
- render a responsive dual-section layout
- show system rewards on the left and custom rewards on the right for wide screens
- collapse to stacked sections on narrow screens
- preserve the existing add/delete flow for custom rewards
- keep system rewards redeem-only
- add any missing locale keys in `app_locale_controller.dart`

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
flutter test test/reward_shop_page_source_test.dart
```

Expected:
- the new source test passes

- [ ] **Step 5: Commit**

```bash
git add frontend/test/reward_shop_page_source_test.dart frontend/lib/features/reward/screens/reward_shop_page.dart frontend/lib/core/i18n/app_locale_controller.dart
git commit -m "feat: render system shop alongside custom rewards"
```

## Chunk 3: Seed Data And Regression

### Task 3: Seed daily-life system rewards and run regression tests

**Files:**
- Create: `supabase/migrations/20260324120000_add_daily_system_rewards.sql`
- Modify: `frontend/test/reward_controller_test.dart`
- Reference: `frontend/test/reward_model_test.dart`
- Reference: `frontend/test/reward_shop_page_source_test.dart`

- [ ] **Step 1: Write the failing test**

Before adding the migration, ensure the regression suite covers the intended UI and controller behavior. If the regression suite is already red from earlier steps, do not add more implementation before confirming the failure reasons are expected.

- [ ] **Step 2: Run targeted tests to confirm the red state is understood**

Run:

```bash
flutter test test/reward_controller_test.dart
flutter test test/reward_shop_page_source_test.dart
```

Expected:
- either both are already green from prior steps, or any remaining failure points directly to missing seed-related expectations you are about to implement

- [ ] **Step 3: Write minimal implementation**

Add a new migration that seeds these active system rewards with cost >= 1:
- 听一首歌
- 散步二十分钟
- 看一集喜欢的内容
- 买一杯喜欢的饮料
- 躺平放空半小时
- 喝杯奶茶
- 点一份喜欢的小甜点
- 玩游戏一小时

Implementation requirements:
- mark them as `is_system = true`
- keep them compatible with inventory-to-task conversion by leaving `effect_type` and `effect_value` null
- make the migration idempotent and avoid touching user-created rewards

- [ ] **Step 4: Run regression tests**

Run:

```bash
flutter test test/reward_controller_test.dart test/reward_model_test.dart test/reward_shop_page_source_test.dart
```

Expected:
- all targeted reward-related tests pass

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260324120000_add_daily_system_rewards.sql frontend/test/reward_controller_test.dart frontend/test/reward_model_test.dart frontend/test/reward_shop_page_source_test.dart
git commit -m "feat: seed daily system shop rewards"
```
