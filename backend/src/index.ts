import express from 'express';
import bodyParser from 'body-parser';
import cors from 'cors';
import dotenv from 'dotenv';
import redisClient from './redis';
import { processUserMessages } from './processor';
import { freeformChat } from './llm';

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(bodyParser.json());

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

app.post('/webhook', async (req, res) => {
  const { user_id, content } = req.body;
  
  if (!user_id || !content) {
    res.status(400).send('Missing user_id or content');
    return;
  }

  // Store message in Redis list
  if (redisClient.isOpen) {
      await redisClient.rPush(`messages:${user_id}`, content);
  } else {
      console.warn('Redis not connected, skipping storage');
  }

  handleDebounce(user_id);

  res.status(200).send('Message received');
});

app.post('/agent/free-chat', async (req, res) => {
  const { message, systemPrompt, model } = req.body ?? {};
  if (!message || !systemPrompt) {
    res.status(400).json({ error: 'Missing message or systemPrompt' });
    return;
  }

  try {
    const reply = await freeformChat(String(message), {
      systemPrompt: String(systemPrompt),
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
