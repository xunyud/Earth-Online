import { createClient } from 'redis';
import dotenv from 'dotenv';

dotenv.config();

const redisClient = createClient({
  url: process.env.REDIS_URL
});

redisClient.on('error', (err) => console.log('Redis Client Error', err));

(async () => {
  if (process.env.REDIS_URL) {
      await redisClient.connect();
  } else {
      console.log('Redis URL not found, skipping connection');
  }
})();

export default redisClient;
