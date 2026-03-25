# Earth Online README Refresh Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the bilingual README files into a portfolio-grade project presentation with synchronized structure and real repository-backed content.

**Architecture:** Replace the current short-form README narrative with a product-case-study flow. Use the English README as the base structure, mirror it into Chinese, and verify that both files reference the same real assets, links, and module ordering.

**Tech Stack:** Markdown, Flutter, Supabase, Node.js, Remotion

---

## Chunk 1: Documentation Rewrite

### Task 1: Rewrite `README.md`

**Files:**
- Modify: `README.md`
- Reference: `frontend/pubspec.yaml`
- Reference: `backend/package.json`
- Reference: `promo-video/package.json`

- [ ] Replace the current short overview with the approved 11-section product-case-study structure.
- [ ] Keep the core positioning around memory-aware productivity, companion-like guidance, and evolving quest-log experience.
- [ ] Add real demo entry points, deployment link, architecture summary, and runnable local setup notes.

### Task 2: Rewrite `README.zh-CN.md`

**Files:**
- Modify: `README.zh-CN.md`
- Reference: `README.md`

- [ ] Mirror the English README structure exactly.
- [ ] Rewrite the content in natural Chinese while preserving section order and emphasis.
- [ ] Reference the Chinese demo assets where appropriate.

## Chunk 2: Verification

### Task 3: Validate structure and references

**Files:**
- Verify: `README.md`
- Verify: `README.zh-CN.md`

- [ ] Confirm both files contain the same section ordering.
- [ ] Confirm demo links and asset paths exist and are spelled correctly.
- [ ] Confirm Getting Started only uses commands and directories present in the repo.
