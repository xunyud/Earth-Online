export type EverMemOSSceneKind = 'opener' | 'video' | 'closing';

export type EverMemOSScene = {
  id: string;
  kind: EverMemOSSceneKind;
  kicker: string;
  title: string;
  body: string;
  subtitle: string;
  voice: string;
  durationInFrames: number;
  accent: string;
  clipSrc?: string;
  trimBefore?: number;
  trimAfter?: number;
  playbackRate?: number;
  proof: string;
  notes: string[];
};

export const evermemosFps = 30;
export const evermemosWidth = 1920;
export const evermemosHeight = 1080;

export const evermemosScenes: EverMemOSScene[] = [
  {
    id: 'opener',
    kind: 'opener',
    kicker: 'EverMemOS',
    title: 'Most people are not short on goals. They are short on mental space.',
    body:
      'Too many tasks, too many reminders, too many details to keep in your head at once.',
    subtitle: 'Too many tasks. Too many reminders. Too much to hold alone.',
    voice:
      'Most people are not short on goals. They are short on mental space.',
    durationInFrames: 300,
    accent: '#FF8A5B',
    clipSrc: 'evermemos-demo/登录页以及任务生成.mp4',
    trimBefore: 0,
    trimAfter: 300,
    playbackRate: 1,
    proof: 'The opening uses real product footage as a pressure backdrop instead of abstract stock visuals.',
    notes: [
      'Task backlog fills the screen',
      'The UI feels busy before relief arrives',
      'The product is framed as solving overload, not adding more work',
    ],
  },
  {
    id: 'promise',
    kind: 'video',
    kicker: 'Product Promise',
    title:
      'A memory-native companion that remembers what matters and follows up at the right time.',
    body:
      'The board comes into focus, context returns, and the interface stops feeling like a blank slate.',
    subtitle: 'Remember. Follow up. Reduce stress.',
    voice:
      'We built a memory-native companion that remembers what matters, follows up at the right time, and helps reduce daily stress.',
    durationInFrames: 570,
    accent: '#52D98C',
    clipSrc: 'evermemos-demo/登录页以及任务生成.mp4',
    trimBefore: 2250,
    trimAfter: 2910,
    playbackRate: 1,
    proof: 'The system re-enters with populated context instead of making the user start from zero.',
    notes: [
      'Tasks are already present',
      'Assistant context appears naturally',
      'The transition feels like relief, not setup',
    ],
  },
  {
    id: 'memory',
    kind: 'video',
    kicker: 'Memory Across Tasks',
    title: 'Tasks, context, and priorities stay alive over time.',
    body:
      'The product keeps prior information available so the user does not have to repeat the same setup every time.',
    subtitle: 'No repeated setup. No lost context.',
    voice:
      'Instead of asking users to repeat themselves, our system keeps track of tasks, context, and priorities over time.',
    durationInFrames: 840,
    accent: '#88E78C',
    clipSrc:
      'evermemos-demo/查看数据面板使用商城以及生成周报，快速创建任务片段需要删除，后面接上查看周报片段.mp4',
    trimBefore: 300,
    trimAfter: 1050,
    playbackRate: 0.89,
    proof: 'The selected window avoids the duplicate quick-create detour and stays focused on persistent task context.',
    notes: [
      'Board state is already populated',
      'Context survives navigation and return',
      'The product remembers more than one screen',
    ],
  },
  {
    id: 'clarity',
    kind: 'video',
    kicker: 'Less Cognitive Load',
    title: 'Memory becomes useful structure, so the next step is easier to see.',
    body:
      'The assistant layer helps the user surface what matters now instead of rereading every detail.',
    subtitle: 'Clarity, not clutter.',
    voice:
      'That memory becomes useful structure. It helps the user see what needs attention now, without carrying every detail in their head.',
    durationInFrames: 750,
    accent: '#6FC5FF',
    clipSrc: 'evermemos-demo/使用助手.mp4',
    trimBefore: 150,
    trimAfter: 750,
    playbackRate: 0.8,
    proof: 'The clip centers on structured assistance rather than raw task entry, which reinforces clarity.',
    notes: [
      'The assistant narrows the next move',
      'The interface reduces rethinking',
      'Useful structure replaces mental juggling',
    ],
  },
  {
    id: 'care',
    kind: 'video',
    kicker: 'Proactive Care',
    title: 'The real value is not just recall. It is timing.',
    body:
      'When pressure shows up, the product can check in gently, remind the user what matters, and make support feel contextual.',
    subtitle: 'The right reminder. At the right time.',
    voice:
      'But the real value is not just recall. It is timing. When the system notices pressure building, it can check in gently, remind the user what matters, and help them feel supported.',
    durationInFrames: 510,
    accent: '#FFD36C',
    clipSrc: 'evermemos-demo/上传记忆.mp4',
    trimBefore: 45,
    trimAfter: 630,
    playbackRate: 0.8,
    proof: 'This segment uses the check-in and memory dialog as the emotional peak of the demo.',
    notes: [
      'The reminder feels gentle, not robotic',
      'Support is grounded in remembered context',
      'The pace intentionally slows here',
    ],
  },
  {
    id: 'summary-setup',
    kind: 'video',
    kicker: 'Weekly Summary',
    title: 'Memory compounds into a report the user can actually act on.',
    body:
      'A week of scattered tasks turns into a readable summary and a better starting point for what comes next.',
    subtitle: 'From scattered days to clear reflection.',
    voice:
      'Because memory compounds, the product can also turn a week of scattered tasks into a clear summary and a useful report.',
    durationInFrames: 120,
    accent: '#7CE5D4',
    clipSrc:
      'evermemos-demo/查看数据面板使用商城以及生成周报，快速创建任务片段需要删除，后面接上查看周报片段.mp4',
    trimBefore: 2760,
    trimAfter: 3000,
    playbackRate: 0.53,
    proof: 'This bridge shot transitions directly into the report flow instead of re-showing quick task creation.',
    notes: [
      'The report is generated from lived activity',
      'The summary is positioned as a weekly reset',
      'This section closes the loop from task to reflection',
    ],
  },
  {
    id: 'summary-report',
    kind: 'video',
    kicker: 'Readable Reflection',
    title: 'The summary stays on screen long enough to feel calm and legible.',
    body:
      'This is where remembered activity becomes something the user can review, understand, and carry into next week.',
    subtitle: 'A better starting point for the next week.',
    voice:
      'It becomes a better starting point for the next week.',
    durationInFrames: 120,
    accent: '#68E3C8',
    clipSrc: 'evermemos-demo/查看周报.mp4',
    trimBefore: 180,
    trimAfter: 300,
    playbackRate: 0.57,
    proof: 'The composition holds on the readable report instead of rushing past the actual evidence.',
    notes: [
      'Readable summary text stays visible',
      'The tone shifts from pressure to calm',
      'Reflection becomes part of the product loop',
    ],
  },
  {
    id: 'closing',
    kind: 'closing',
    kicker: 'EverMemOS',
    title:
      'This is not just task management. It is memory that helps people feel less overwhelmed, more organized, and more cared for.',
    body:
      'A memory-native companion for everyday life.',
    subtitle: 'A memory-native companion for everyday life.',
    voice:
      'This is not just task management. It is memory that helps people feel less overwhelmed, more organized, and more cared for.',
    durationInFrames: 450,
    accent: '#8DF2AF',
    clipSrc: 'evermemos-demo/查看周报.mp4',
    trimBefore: 90,
    trimAfter: 300,
    playbackRate: 0.47,
    proof: 'The ending stays on the summary backdrop so the closing claim feels earned by the footage that came before it.',
    notes: [
      'The report remains visible behind the promise',
      'The ending is calm instead of flashy',
      'The final takeaway stays anchored in memory',
    ],
  },
];

export const evermemosTotalDurationInFrames = evermemosScenes.reduce(
  (sum, scene) => sum + scene.durationInFrames,
  0,
);
