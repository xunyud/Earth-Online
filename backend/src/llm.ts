import OpenAI from 'openai';
import dotenv from 'dotenv';

dotenv.config();

function normalizeOpenAIBaseUrl(baseUrl: string) {
  const normalized = baseUrl.trim().replace(/\/+$/, '');
  return normalized.endsWith('/v1') ? normalized : `${normalized}/v1`;
}

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
  baseURL: normalizeOpenAIBaseUrl(
    process.env.OPENAI_BASE_URL || 'https://api.86gamestore.com',
  )
});

export async function freeformChat(
  message: string,
  options: {
    systemPrompt: string;
    model?: string;
  },
): Promise<string> {
  if (!process.env.OPENAI_API_KEY) {
    throw new Error('OPENAI_API_KEY not set');
  }

  const completion = await openai.chat.completions.create({
    model: options.model || process.env.OPENAI_CHAT_MODEL || 'deepseek-chat',
    temperature: 0.4,
    messages: [
      { role: 'system', content: options.systemPrompt },
      { role: 'user', content: message },
    ],
  });

  const reply = completion.choices[0]?.message?.content?.trim() || '';
  if (!reply) {
    throw new Error('Empty freeform chat reply');
  }
  return reply;
}

export async function extractTasks(text: string): Promise<any[]> {
  if (!process.env.OPENAI_API_KEY) {
      console.warn("OPENAI_API_KEY not set. Returning empty tasks.");
      return [];
  }
  try {
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
  } catch (error) {
      console.error("LLM Error:", error);
  }
  return [];
}
