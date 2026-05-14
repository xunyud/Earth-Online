import express from 'express';
import bodyParser from 'body-parser';
import cors from 'cors';
import dotenv from 'dotenv';
import redisClient from './redis';
import { processUserMessages } from './processor';
import { freeformChat } from './llm';
import { requireAuth, AuthenticatedRequest } from './auth';

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(bodyParser.json({ limit: '100kb' }));

app.get('/', (req, res) => {
  res.send('Chat-to-Timeline Backend is running');
});

const userTimers: Record<string, NodeJS.Timeout> = {};

function handleDebounce(userId: string) {
  if (userTimers[userId]) {
    clearTimeout(userTimers[userId]);
  }

  userTimers[userId] = setTimeout(() => {
    processUserMessages(userId);
    delete userTimers[userId];
  }, 15000); // 15 seconds
}

app.post('/webhook', requireAuth, async (req: AuthenticatedRequest, res) => {
  const userId = req.userId!;
  const { content } = req.body;

  if (!content || typeof content !== 'string' || content.length > 10000) {
    res.status(400).json({ error: 'content must be a string (1-10000 chars)' });
    return;
  }

  if (redisClient.isOpen) {
    await redisClient.rPush(`messages:${userId}`, content.trim());
  } else {
    console.warn('Redis not connected, skipping storage');
  }

  handleDebounce(userId);

  res.status(200).json({ success: true });
});

app.post('/agent/free-chat', requireAuth, async (req: AuthenticatedRequest, res) => {
  const { message, systemPrompt, model } = req.body ?? {};
  if (!message || typeof message !== 'string' || message.length > 5000) {
    res.status(400).json({ error: 'message must be a string (1-5000 chars)' });
    return;
  }
  if (!systemPrompt || typeof systemPrompt !== 'string' || systemPrompt.length > 2000) {
    res.status(400).json({ error: 'systemPrompt must be a string (1-2000 chars)' });
    return;
  }

  try {
    const reply = await freeformChat(message, {
      systemPrompt,
      model: model ? String(model) : undefined,
    });
    res.status(200).json({ success: true, reply });
  } catch (error) {
    const text = error instanceof Error ? error.message : String(error);
    res.status(500).json({ success: false, error: text });
  }
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
