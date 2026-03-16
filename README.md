# Earth Online

Earth Online is a memory-aware productivity game that turns everyday planning into a living quest log. The project combines a Flutter client, a lightweight Node backend, and Supabase functions so users can capture daily context, revisit recent memory, and receive task suggestions that stay grounded in what they have already done.

## Competition Submission

### 1. All Source Code of the Project

This repository contains the full source code for Earth Online.

- `frontend/`: the Flutter application, including the quest board, memory guide dialog, profile customization, WeChat binding flow, diary, recycle bin, stats, rewards, and achievement screens.
- `backend/`: a Node.js / Express service for webhook ingestion and debounced message processing.
- `supabase/`: database migrations, shared guide logic, and Supabase Edge Functions for task parsing, guide chat, memory sync, weekly summaries, portrait generation, and WeChat-related flows.
- `docs/`: product notes, implementation plans, and project references used during development.

Core product capabilities currently present in the source code include:

- A gamified quest board for creating, organizing, and completing tasks.
- A memory-aware guide that reads recent signals and proposes recovery or progress tasks in a conversational flow.
- A life diary and recycle bin for preserving short-term context and recovering deleted work.
- Profile customization with avatar upload and editable nickname.
- WeChat binding for bridging reminders and status updates into a real-world messaging channel.
- Progress systems such as XP, levels, rewards, inventory, achievements, and stats.

### 2. Project Introduction Video

Video link: **TBD before final competition submission**

The project introduction video for the Memory Genesis Competition 2026 should cover:

1. The main features of Earth Online.
2. How Earth Online uses memory, including recent context, long-term signals, and guide references.
3. How that memory helps users restart, recover, and keep moving through real tasks with less friction.

### 3. Deployed URL

Deployed URL: https://earth-online-wine.vercel.app

This repository already contains the main application code and backend/Supabase components required for deployment. A public deployment link should be added here once the final hosted environment is available.

## Tech Stack

- Flutter + Dart
- Supabase
- Node.js + Express
- Redis
- TypeScript

## Repository Status

- GitHub repository: https://github.com/xunyud/Earth-Online
- Primary branch: `main`
- License: MIT
