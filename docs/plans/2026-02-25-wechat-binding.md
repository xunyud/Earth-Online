# User-WeChat Binding Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a secure, one-time code binding mechanism to link App users with their WeChat OpenID, enabling personalized task generation from chat logs.

**Architecture:**
- **Database:** New `profiles` table extending `auth.users` with `wechat_openid` and temporary `binding_code`.
- **Backend (Edge Functions):**
    - `generate-binding-code`: Securely generates and stores a 6-char alphanumeric code (15-min TTL).
    - `webhook` (Updated): Intercepts binding codes to link accounts; otherwise routes chat messages to the correct user via OpenID lookup.
- **Frontend (Flutter):** `BindingView` with code display and real-time status updates via Supabase Realtime.

**Tech Stack:** Supabase (Postgres, Edge Functions, Realtime), Flutter.

---

### Task 1: Database Schema Update

**Files:**
- Create: `schema_v3.sql`

**Step 1: Define Profiles Table**

Create `schema_v3.sql` to create the `profiles` table and RLS policies.
- `id` (references `auth.users`)
- `wechat_openid` (unique, nullable)
- `binding_code` (nullable)
- `binding_expires_at` (timestamptz, nullable)
- Enable RLS: Users can read own profile. Edge Functions can read/update all (via service role).

### Task 2: Backend Logic - Binding Code Generation

**Files:**
- Create: `supabase/functions/generate-binding-code/index.ts`

**Step 1: Implement Generation Logic**

Create `supabase/functions/generate-binding-code/index.ts`.
- Authenticate user via JWT.
- Generate random 6-char alphanumeric code (A-Z, 0-9).
- Update `profiles` table: set `binding_code` and `binding_expires_at = now() + 15 min`.
- Return code.

### Task 3: Backend Logic - Webhook Binding & Routing

**Files:**
- Modify: `supabase/functions/webhook/index.ts`

**Step 1: Refactor Webhook Logic**

Update `supabase/functions/webhook/index.ts`.
- Parse incoming `sender_id` (OpenID) and `content`.
- **Binding Check**: If `content` matches `^[A-Z0-9]{6}$`:
    - Query `profiles` for matching `binding_code` AND `binding_expires_at > now()`.
    - If found: Update `profiles` set `wechat_openid = sender_id`, clear code. Respond "Success".
    - If not found: Respond "Invalid/Expired".
- **Standard Routing**: If NOT binding code:
    - Query `profiles` to find `id` where `wechat_openid = sender_id`.
    - If found: Proceed with existing logic (push to Redis `msgs:{user_id}`).
    - If not found: Respond "Account not bound. Please enter binding code."

### Task 4: Frontend - Binding View

**Files:**
- Create: `frontend/lib/widgets/binding_view.dart`
- Modify: `frontend/lib/main.dart`

**Step 1: Implement BindingView**

Create `frontend/lib/widgets/binding_view.dart`.
- UI: Large Text for code, "Refresh" button.
- Logic: Call `generate-binding-code` on init and refresh.
- Realtime: Subscribe to `profiles` changes for current user. If `wechat_openid` becomes non-null, show "Bound!" animation.

**Step 2: Add Navigation**

Update `frontend/lib/main.dart` to add a way to navigate to `BindingView` (e.g., an icon in AppBar or Drawer).
