# Optimize LLM System Prompt Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 优化 `parse-quest` 的 System Prompt，解决语言漂移和层级识别问题。

**Architecture:**
- **Prompt Engineering:** 使用 Few-Shot Prompting 和更严格的约束条件。
- **Output Validation:** 确保 JSON 结构符合要求。

**Tech Stack:** Deno, Supabase Edge Functions.

---

### Task 1: 更新 System Prompt

**Files:**
- Modify: `supabase/functions/parse-quest/index.ts`

**Step 1: 定义新 Prompt**
- **Role**: RPG Task Master.
- **Rules**:
    1.  **Language**: STRICTLY same language as input.
    2.  **Hierarchy**: Identify Main Goal vs Steps. Use `parent_index`.
    3.  **Format**: Pure JSON Array.
- **Few-Shot Examples**: 提供中英文对照示例，明确父子关系。

**Step 2: 部署**
- 重新部署 Function。

---

### Execution Steps

1.  **Code**: Update `index.ts` with new Prompt.
2.  **Deploy**: Run `supabase functions deploy parse-quest`.
