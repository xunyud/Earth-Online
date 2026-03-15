# Chat-to-Timeline Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a "Chat-to-Timeline" application that converts chat messages into actionable tasks using LLM, with real-time updates on a Flutter frontend.

**Architecture:**
- **Frontend:** Flutter app with `TimelineView`, `TaskCard`, and `WeChatSyncIndicator`. Uses Supabase Realtime for updates.
- **Backend:** Node.js/TypeScript server (or Supabase Edge Functions) handling Webhooks, Redis for debouncing, and LLM for task extraction.
- **Database:** Supabase (PostgreSQL) for storing `RawMessage` and `ParsedTask`.

**Tech Stack:** Flutter, TypeScript, Node.js, Supabase, Redis, LLM API (e.g., OpenAI/Gemini).

---

### Task 1: Project Initialization & Backend Setup

**Files:**
- Create: `backend/package.json`
- Create: `backend/tsconfig.json`
- Create: `backend/src/index.ts`
- Create: `backend/.env`

**Step 1: Initialize Node.js Project**

Initialize a new Node.js project in the `backend` directory.

```bash
mkdir backend
cd backend
npm init -y
npm install typescript ts-node @types/node express body-parser cors dotenv @supabase/supabase-js redis openai
npx tsc --init
```

**Step 2: Create Basic Server Structure**

Create `backend/src/index.ts` with a basic Express server.

```typescript
import express from 'express';
import bodyParser from 'body-parser';
import cors from 'cors';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(bodyParser.json());

app.get('/', (req, res) => {
  res.send('Chat-to-Timeline Backend is running');
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
```

**Step 3: Verify Server**

Run the server and check if it responds.

```bash
npx ts-node src/index.ts
# In another terminal
curl http://localhost:3000/
```

### Task 2: Supabase Schema & Client Setup

**Files:**
- Create: `backend/src/supabase.ts`
- Create: `schema.sql` (for documentation/execution)

**Step 1: Define Database Schema**

Create `schema.sql` with the provided schema.

```sql
-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- RawMessage Table
create table if not exists raw_messages (
  id uuid primary key default uuid_generate_v4(),
  user_id text not null,
  content text not null,
  received_at timestamptz default now()
);

-- ParsedTask Table
create table if not exists parsed_tasks (
  id uuid primary key default uuid_generate_v4(),
  user_id text not null,
  title text not null,
  original_context text[] default '{}',
  start_time timestamptz,
  duration_minutes int,
  priority text check (priority in ('low', 'medium', 'high')),
  dependencies text[] default '{}',
  status text check (status in ('pending', 'in_progress', 'done')) default 'pending',
  created_at timestamptz default now()
);
```

**Step 2: Setup Supabase Client**

Create `backend/src/supabase.ts` to initialize the Supabase client.

```typescript
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey = process.env.SUPABASE_KEY || '';

export const supabase = createClient(supabaseUrl, supabaseKey);
```

### Task 3: Webhook & Redis Debounce Logic

**Files:**
- Modify: `backend/src/index.ts`
- Create: `backend/src/redis.ts`
- Create: `backend/src/processor.ts`

**Step 1: Setup Redis Client**

Create `backend/src/redis.ts`.

```typescript
import { createClient } from 'redis';
import dotenv from 'dotenv';

dotenv.config();

const redisClient = createClient({
  url: process.env.REDIS_URL
});

redisClient.on('error', (err) => console.log('Redis Client Error', err));

(async () => {
  await redisClient.connect();
})();

export default redisClient;
```

**Step 2: Implement Webhook Endpoint**

Modify `backend/src/index.ts` to add `/webhook` endpoint.

```typescript
import redisClient from './redis';

// ... inside app setup
app.post('/webhook', async (req, res) => {
  const { user_id, content } = req.body;
  
  if (!user_id || !content) {
    return res.status(400).send('Missing user_id or content');
  }

  // Store message in Redis list
  await redisClient.rPush(`messages:${user_id}`, content);

  // Set/Reset Debounce Timer (handled via expiration key or external job, 
  // but for simplicity we can use a delayed check or a key with expiration that triggers an event. 
  // A simpler approach for this demo: Set a key that expires in 15s. 
  // If it exists, do nothing. If not, start a timeout.)
  
  // Better approach for "Reset timer":
  // We can use a separate "processing_trigger" key.
  // Every time a message comes, we update a "last_message_at:${user_id}" timestamp.
  // And ensure a processor is running (or schedule one).
  
  // Simplified Debounce for Node.js process:
  // clear existing timeout for user, set new timeout.
  
  handleDebounce(user_id);

  res.status(200).send('Message received');
});

const userTimers: Record<string, NodeJS.Timeout> = {};
import { processUserMessages } from './processor';

function handleDebounce(userId: string) {
  if (userTimers[userId]) {
    clearTimeout(userTimers[userId]);
  }
  
  userTimers[userId] = setTimeout(() => {
    processUserMessages(userId);
    delete userTimers[userId];
  }, 15000); // 15 seconds
}
```

**Step 3: Implement Processor Stub**

Create `backend/src/processor.ts`.

```typescript
import redisClient from './redis';

export async function processUserMessages(userId: string) {
  console.log(`Processing messages for user ${userId}`);
  
  // Pop all messages
  const messages = await redisClient.lRange(`messages:${userId}`, 0, -1);
  await redisClient.del(`messages:${userId}`);
  
  if (messages.length === 0) return;
  
  const aggregatedText = messages.join('\n');
  console.log('Aggregated Text:', aggregatedText);
  
  // TODO: Call LLM
}
```

### Task 4: LLM Integration & Task Generation

**Files:**
- Modify: `backend/src/processor.ts`
- Create: `backend/src/llm.ts`

**Step 1: Setup LLM Client**

Create `backend/src/llm.ts` (Assuming OpenAI compatible API).

```typescript
import OpenAI from 'openai';
import dotenv from 'dotenv';

dotenv.config();

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
  baseURL: process.env.OPENAI_BASE_URL // Optional
});

export async function extractTasks(text: string): Promise<any[]> {
  const completion = await openai.chat.completions.create({
    messages: [
      { role: "system", content: "You are an expert executive assistant. Analyze the provided fragmented chat logs. Extract actionable tasks. Ignore casual chatter. Consolidate duplicate points. Output strictly as a JSON array adhering to the ParsedTask schema." },
      { role: "user", content: text }
    ],
    model: "gpt-3.5-turbo", // or similar
    functions: [
      {
        name: "save_tasks",
        description: "Save extracted tasks",
        parameters: {
          type: "object",
          properties: {
            tasks: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  title: { type: "string" },
                  start_time: { type: "string", format: "date-time", nullable: true },
                  duration_minutes: { type: "number" },
                  priority: { type: "string", enum: ["low", "medium", "high"] },
                  dependencies: { type: "array", items: { type: "string" } },
                  status: { type: "string", enum: ["pending", "in_progress", "done"] }
                },
                required: ["title", "duration_minutes", "priority", "status"]
              }
            }
          },
          required: ["tasks"]
        }
      }
    ],
    function_call: { name: "save_tasks" }
  });

  const functionArgs = completion.choices[0].message.function_call?.arguments;
  if (functionArgs) {
    return JSON.parse(functionArgs).tasks;
  }
  return [];
}
```

**Step 2: Integrate LLM into Processor**

Modify `backend/src/processor.ts` to call `extractTasks` and save to Supabase.

```typescript
import { extractTasks } from './llm';
import { supabase } from './supabase';

// ... inside processUserMessages
  const tasks = await extractTasks(aggregatedText);
  
  if (tasks.length > 0) {
    const tasksWithUser = tasks.map(t => ({ ...t, user_id: userId }));
    const { error } = await supabase.from('parsed_tasks').insert(tasksWithUser);
    
    if (error) console.error('Supabase Insert Error:', error);
    else console.log('Tasks inserted successfully');
  }
```

### Task 5: Flutter Frontend Setup & UI Components

**Files:**
- Create: `frontend/` (Flutter create)
- Create: `frontend/lib/models/task.dart`
- Create: `frontend/lib/widgets/task_card.dart`
- Create: `frontend/lib/widgets/timeline_view.dart`
- Create: `frontend/lib/widgets/sync_indicator.dart`

**Step 1: Initialize Flutter App**

```bash
flutter create frontend
cd frontend
flutter pub add supabase_flutter google_fonts intl
```

**Step 2: Define Task Model**

Create `frontend/lib/models/task.dart`.

```dart
class ParsedTask {
  final String id;
  final String title;
  final DateTime? startTime;
  final int durationMinutes;
  final String priority;
  final String status;

  ParsedTask({required this.id, required this.title, this.startTime, required this.durationMinutes, required this.priority, required this.status});

  factory ParsedTask.fromJson(Map<String, dynamic> json) {
    return ParsedTask(
      id: json['id'],
      title: json['title'],
      startTime: json['start_time'] != null ? DateTime.parse(json['start_time']) : null,
      durationMinutes: json['duration_minutes'],
      priority: json['priority'],
      status: json['status'],
    );
  }
}
```

**Step 3: Implement TaskCard**

Create `frontend/lib/widgets/task_card.dart`.

```dart
import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final ParsedTask task;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TaskCard({Key? key, required this.task, this.onTap, this.onLongPress}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: ListTile(
        title: Text(task.title),
        subtitle: Text('${task.durationMinutes} mins - ${task.priority}'),
        onTap: onTap,
        onLongPress: onLongPress,
        trailing: Icon(
          task.status == 'done' ? Icons.check_circle : Icons.circle_outlined,
          color: task.status == 'done' ? Colors.green : Colors.grey,
        ),
      ),
    );
  }
}
```

**Step 4: Implement TimelineView**

Create `frontend/lib/widgets/timeline_view.dart`.

```dart
import 'package:flutter/material.dart';
import 'task_card.dart';
import '../models/task.dart';

class TimelineView extends StatelessWidget {
  final List<ParsedTask> tasks;

  const TimelineView({Key? key, required this.tasks}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return Row(
          children: [
            // Vertical Line
            Container(
              width: 2,
              height: 80, // Approximate height
              color: Colors.grey,
              margin: EdgeInsets.symmetric(horizontal: 16),
            ),
            Expanded(child: TaskCard(task: tasks[index])),
          ],
        );
      },
    );
  }
}
```

**Step 5: Implement Sync Indicator**

Create `frontend/lib/widgets/sync_indicator.dart`.

```dart
import 'package:flutter/material.dart';

class WeChatSyncIndicator extends StatefulWidget {
  final bool isSyncing;
  const WeChatSyncIndicator({Key? key, required this.isSyncing}) : super(key: key);

  @override
  _WeChatSyncIndicatorState createState() => _WeChatSyncIndicatorState();
}

class _WeChatSyncIndicatorState extends State<WeChatSyncIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSyncing) return SizedBox.shrink();
    return FadeTransition(
      opacity: _controller,
      child: Icon(Icons.sync, color: Colors.blue),
    );
  }
}
```

### Task 6: Frontend Logic Integration

**Files:**
- Modify: `frontend/lib/main.dart`

**Step 1: Setup Supabase in Flutter**

Modify `frontend/lib/main.dart` to initialize Supabase and listen to Realtime changes.

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/task.dart';
import 'widgets/timeline_view.dart';
import 'widgets/sync_indicator.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _supabase = Supabase.instance.client;
  List<ParsedTask> _tasks = [];
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
    _setupRealtime();
  }

  Future<void> _fetchTasks() async {
    final response = await _supabase.from('parsed_tasks').select().order('created_at');
    setState(() {
      _tasks = (response as List).map((e) => ParsedTask.fromJson(e)).toList();
    });
  }

  void _setupRealtime() {
    _supabase.channel('public:parsed_tasks').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'parsed_tasks',
      callback: (payload) {
        setState(() {
          _tasks.add(ParsedTask.fromJson(payload.newRecord));
          _isSyncing = true;
        });
        Future.delayed(Duration(seconds: 2), () => setState(() => _isSyncing = false));
      },
    ).subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat-to-Timeline'),
        actions: [WeChatSyncIndicator(isSyncing: _isSyncing)],
      ),
      body: TimelineView(tasks: _tasks),
    );
  }
}
```

