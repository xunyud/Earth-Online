import express from 'express';
import bodyParser from 'body-parser';
import cors from 'cors';
import dotenv from 'dotenv';
import redisClient from './redis';
import { processUserMessages } from './processor';

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

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
