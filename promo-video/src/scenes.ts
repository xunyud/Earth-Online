export type PromoSceneKind =
  | 'opener'
  | 'capture'
  | 'memory'
  | 'guide'
  | 'event'
  | 'progression'
  | 'diary';

export type PromoScene = {
  id: string;
  kind: PromoSceneKind;
  kicker: string;
  title: string;
  body: string;
  caption: string;
  voice: string;
  durationInFrames: number;
  accent: string;
  image?: string;
};

export const fps = 30;
export const width = 1920;
export const height = 1080;

export const promoScenes: PromoScene[] = [
  {
    id: 'intro',
    kind: 'opener',
    kicker: 'Memory-Aware Productivity',
    title: 'Most task apps record work. They do not remember your context.',
    body:
      'Earth Online is built for the moments when momentum breaks. Instead of treating every day like a blank page, it keeps recent context alive and uses it to guide the next step.',
    caption:
      'The point of memory is not storage. The point is helping people restart with context.',
    voice:
      'Most task apps record work, but they do not remember your context. Earth Online keeps recent context alive, so the next step can start from where your real day left off.',
    durationInFrames: 240,
    accent: '#2F8A43',
    image: 'screens/login.png',
  },
  {
    id: 'quest-board',
    kind: 'capture',
    kicker: 'Step 1 · Capture Real Life',
    title: 'A rough note becomes a quest, then a completed action.',
    body:
      'The user can type a messy, real-world task, drop it into the quest board, and complete it. Progress feels visible through XP and rewards, but the important part is what happens next.',
    caption:
      'Input, click, complete. The product starts from real behavior, not a polished prompt.',
    voice:
      'A rough note becomes a quest, then a completed action. Earth Online starts from real behavior: type the task, place it on the board, and finish it with visible progress.',
    durationInFrames: 285,
    accent: '#5B9E48',
    image: 'screens/board.png',
  },
  {
    id: 'memory-loop',
    kind: 'memory',
    kicker: 'Step 2 · Turn Actions Into Memory',
    title: 'Finished work does not disappear. It becomes usable memory.',
    body:
      'Completed quests, daily logs, behavior signals, and prior guide dialogue are packed into a memory bundle. That bundle becomes the system’s evidence before it generates anything new.',
    caption:
      'Memory is gathered from tasks, logs, signals, and recall. It is not a random guess layer.',
    voice:
      'Finished work does not disappear. Earth Online turns completed quests, daily logs, behavior signals, and prior recall into a memory bundle that can be used as evidence later.',
    durationInFrames: 300,
    accent: '#7AAA4A',
  },
  {
    id: 'guide',
    kind: 'guide',
    kicker: 'Step 3 · Read Memory Before Replying',
    title: 'The guide answers with context, not a generic pep talk.',
    body:
      'When the assistant opens, it shows a memory digest first. Then it replies, offers quick actions, and cites how many recent memory references it used to understand the moment.',
    caption:
      'The guide remembers recent rhythm before suggesting recovery, focus, or a next step.',
    voice:
      'When the guide opens, it reads memory before replying. Instead of a generic pep talk, it answers from recent rhythm and can show how many memory references informed that response.',
    durationInFrames: 300,
    accent: '#2F7C39',
    image: 'screens/guide.png',
  },
  {
    id: 'event',
    kind: 'event',
    kicker: 'Step 4 · Explain Why This Task, Right Now',
    title: 'Daily events do not just suggest a task. They explain the reason.',
    body:
      'The event layer shows why a task is recommended now, highlights the memory evidence behind it, and lets the user accept it directly into the board with instant reward feedback.',
    caption:
      'This is the difference between a random prompt and a recommendation grounded in memory.',
    voice:
      'Daily events do not just suggest a task. They explain why it matters right now, surface the memory evidence, and let the user accept it directly into the board.',
    durationInFrames: 285,
    accent: '#F0B323',
    image: 'screens/event.png',
  },
  {
    id: 'progression',
    kind: 'progression',
    kicker: 'Step 5 · Watch Progress Build Up',
    title: 'Check in, level up, and spend rewards on what you earned.',
    body:
      'Daily check-ins build streaks. Completed quests earn XP and gold. The growth dashboard tracks it all, and the reward shop turns effort into something tangible.',
    caption:
      'Progress is not just a number. It is a streak, a level, and a reward you chose.',
    voice:
      'Daily check-ins build streaks. Completed quests earn XP and gold. The growth dashboard tracks everything, and the reward shop turns your effort into something you can actually use.',
    durationInFrames: 285,
    accent: '#D49516',
  },
  {
    id: 'outro',
    kind: 'diary',
    kicker: 'Step 6 · Keep The Story Going',
    title: 'Memory helps people restart, recover, and keep moving forward.',
    body:
      'Life Diary and weekly summaries turn scattered work into a readable story. The benefit of memory is simple: when the system remembers what just happened, restarting feels lighter.',
    caption:
      'Less friction. Better recovery. A next step that feels grounded in real life.',
    voice:
      'Life Diary and weekly summaries keep the story going. When the system remembers what just happened, people can restart faster, recover with less friction, and keep moving forward.',
    durationInFrames: 255,
    accent: '#2C7A51',
  },
];

export const totalDurationInFrames = promoScenes.reduce(
  (sum, scene) => sum + scene.durationInFrames,
  0,
);
