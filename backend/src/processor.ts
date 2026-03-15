import redisClient from './redis';
import { extractTasks } from './llm';
import { supabase } from './supabase';

export async function processUserMessages(userId: string) {
  console.log(`Processing messages for user ${userId}`);
  
  let messages: string[] = [];

  if (redisClient.isOpen) {
    // Pop all messages
    messages = await redisClient.lRange(`messages:${userId}`, 0, -1);
    await redisClient.del(`messages:${userId}`);
  } else {
    console.warn('Redis not connected, cannot retrieve messages');
    return;
  }
  
  if (messages.length === 0) return;
  
  const aggregatedText = messages.join('\n');
  console.log('Aggregated Text:', aggregatedText);
  
  const tasks = await extractTasks(aggregatedText);
  
  if (tasks.length > 0) {
    const tasksWithUser = tasks.map(t => ({ ...t, user_id: userId }));
    const { error } = await supabase.from('parsed_tasks').insert(tasksWithUser);
    
    if (error) console.error('Supabase Insert Error:', error);
    else console.log('Tasks inserted successfully');
  } else {
      console.log("No tasks extracted.");
  }
}
