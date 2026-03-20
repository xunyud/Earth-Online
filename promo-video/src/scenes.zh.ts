import type {PromoScene} from './scenes';

export const promoScenesZh: PromoScene[] = [
  {
    id: 'intro',
    kind: 'opener',
    kicker: '会记忆的效率系统',
    title: '很多任务工具会记录任务，却记不住你刚刚经历了什么。',
    body:
      'Earth Online 不是把每一天都当成空白页重新开始。它会保留近期上下文，让下一步建议建立在真实生活的连续性上。',
    caption:
      '记忆的价值不在于存档，而在于让人带着上下文重新启动。',
    voice:
      '很多任务工具会记录任务，却记不住你刚刚经历了什么。Earth Online 会保留近期上下文，让下一步建议从你真实的一天继续往前，而不是重新从零开始。',
    durationInFrames: 240,
    accent: '#2F8A43',
    image: 'screens/login.png',
  },
  {
    id: 'quest-board',
    kind: 'capture',
    kicker: '第一步：先记录真实行为',
    title: '一条很粗糙的想法，会先变成任务，再变成完成动作。',
    body:
      '用户可以把现实里并不完美的念头直接输入到 quest board，点击、完成、获得 XP。真正重要的是，这些动作不会在完成后消失。',
    caption:
      '输入、点击、完成。产品先理解真实行为，再去生成后续帮助。',
    voice:
      '一条很粗糙的想法，会先变成任务，再变成完成动作。Earth Online 从真实行为开始，让用户输入任务、放入任务板，再通过完成反馈看到进展。',
    durationInFrames: 285,
    accent: '#5B9E48',
    image: 'screens/board.png',
  },
  {
    id: 'memory-loop',
    kind: 'memory',
    kicker: '第二步：把行为沉淀成记忆',
    title: '完成过的事情不会消失，而会变成后续可用的记忆。',
    body:
      '已完成任务、每日记录、行为信号和之前的对话，会被整理成一份 memory bundle。在系统生成任何建议之前，这份记忆先成为依据。',
    caption:
      '记忆来自任务、日志、信号和回溯，不是随便猜出来的一层包装。',
    voice:
      '完成过的事情不会消失。Earth Online 会把已完成任务、每日记录、行为信号和之前的回溯整理成记忆包，让系统后面给出的建议有依据可查。',
    durationInFrames: 300,
    accent: '#7AAA4A',
  },
  {
    id: 'guide',
    kind: 'guide',
    kicker: '第三步：助手先读记忆，再回答你',
    title: '助手给出的不是泛泛鼓励，而是带着上下文的回应。',
    body:
      '当 guide panel 打开时，系统会先展示 memory digest，再进入对话、快捷建议和回复内容，并明确这次回应参考了多少段近期记忆。',
    caption:
      '它会先理解你最近的节奏，再给出恢复、专注或下一步建议。',
    voice:
      '当助手面板打开时，它会先读记忆，再开始回答。这样给出的就不是空泛鼓励，而是结合你最近节奏的回应，甚至还能说明引用了多少段近期记忆。',
    durationInFrames: 300,
    accent: '#2F7C39',
    image: 'screens/guide.png',
  },
  {
    id: 'event',
    kind: 'event',
    kicker: '第四步：推荐任务时，也解释为什么是现在',
    title: '每日事件不只是推荐任务，还会说明推荐理由。',
    body:
      '事件层会展示此刻为什么推荐这件事，把背后的记忆依据一起亮出来，并允许用户一键接受，直接插入任务板并获得奖励反馈。',
    caption:
      '这就是随机提醒，和基于记忆做推荐之间的差别。',
    voice:
      '每日事件不只是推荐任务，还会解释为什么是现在、为什么是这件事。系统会把记忆依据一起展示出来，并允许用户一键接受，直接加入任务板。',
    durationInFrames: 285,
    accent: '#F0B323',
    image: 'screens/event.png',
  },
  {
    id: 'outro',
    kind: 'diary',
    kicker: '第五步：把连续性真正留下来',
    title: '记忆的用处，是帮助人重新启动、恢复节奏，并继续往前。',
    body:
      'Life Diary 和 weekly summary 会把零散动作整理成一段可回看的故事。系统记得你刚经历了什么，所以重新开始的时候，阻力会更小。',
    caption:
      '更少中断，更容易恢复，也更容易得到贴近现实的下一步。',
    voice:
      'Life Diary 和周总结，会把零散动作整理成可以回看的连续故事。记忆真正的用处，是让系统知道你刚经历了什么，于是你就能更快重新启动，带着更少阻力继续往前。',
    durationInFrames: 255,
    accent: '#2C7A51',
  },
];

export const totalDurationInFramesZh = promoScenesZh.reduce(
  (sum, scene) => sum + scene.durationInFrames,
  0,
);
