# Chat-to-Timeline Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Chat-to-Timeline application that converts chat messages into actionable tasks and reflects them in a Flutter timeline UI.

**Architecture:**
- **Frontend:** Flutter app with timeline cards and realtime updates.
- **Backend:** Node.js / TypeScript server or Supabase Edge Functions for webhook handling, debounce, and task extraction.
- **Database:** Supabase for raw messages and parsed tasks.
- **LLM Provider:** DeepSeek.

**Tech Stack:** Flutter, TypeScript, Node.js, Supabase, Redis, DeepSeek API.

---

### Task 1: Backend Setup

Create the Node.js backend skeleton in `backend/` and wire Express, Supabase, Redis, and dotenv.

### Task 2: Redis Debounce

Implement webhook ingestion and per-user debounce buffering.

### Task 3: LLM Integration

Create `backend/src/llm.ts` using DeepSeek's OpenAI-compatible API:

```typescript
import OpenAI from 'openai';
import dotenv from 'dotenv';

dotenv.config();

const openai = new OpenAI({
  apiKey: process.env.DEEPSEEK_API_KEY,
  baseURL: process.env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com',
});
```

Use model `deepseek-chat` for task extraction.

### Task 4: Save Parsed Tasks

Persist extracted tasks to Supabase and surface them via realtime updates to Flutter.

### Task 5: Frontend

Build task cards, timeline view, and sync indicator in Flutter.

### Environment Variables

- `DEEPSEEK_API_KEY`
- `DEEPSEEK_BASE_URL=https://api.deepseek.com`
- `SUPABASE_URL`
- `SUPABASE_KEY`
- `REDIS_URL`
- `PORT`

### Security Note

The real DeepSeek key must never be committed into docs or source files. Keep it in local env files excluded from git or in your deployment secret store.
