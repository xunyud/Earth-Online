import React from 'react';
import {
  AbsoluteFill,
  Audio,
  Easing,
  Img,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {PromoScene, promoScenes as promoScenesEn} from './scenes';
import {promoScenesZh} from './scenes.zh';

type PromoVariant = 'en' | 'zh';

type PromoUiCopy = {
  typedTask: string;
  captureBoardTitle: string;
  captureAddLabel: string;
  captureRows: string[];
  textBadges: [string, string];
  openerTop: string;
  openerTitle: string;
  openerBody: string;
  openerChips: [string, string, string];
  memoryTitle: string;
  memoryCount: string;
  memorySources: string;
  memoryEvidenceTag: string;
  memoryIncoming: [string, string, string];
  memoryEvidence: [string, string, string];
  guideName: string;
  guideSubtitle: string;
  guideDigestLabel: string;
  guideDigestText: string;
  userMessage: string;
  guideReply: string;
  guideRefLabel: string;
  guideActions: [string, string, string];
  eventTag: string;
  eventTitle: string;
  eventReason: string;
  eventMemoryLabel: string;
  eventMemoryText: string;
  eventRewards: [string, string];
  eventAcceptLabel: string;
  eventAcceptedTag: string;
  eventAcceptedText: string;
  progressionCheckinLabel: string;
  progressionLevelLabel: string;
  progressionXpLabel: string;
  progressionStats: [string, string, string];
  progressionShopTitle: string;
  progressionShopItems: [string, string, string];
  progressionShopPrices: [string, string, string];
  progressionRedeemedLabel: string;
  diaryTitle: string;
  diaryEntries: Array<[string, string]>;
  diaryStoredLabel: string;
  diarySummaryTag: string;
  diarySummaryTitle: string;
  diarySummaryText: string;
  diaryBullets: [string, string, string];
};

type PromoCompositionProps = {
  scenes?: PromoScene[];
  audioDir?: string;
  variant?: PromoVariant;
};

const shellStyle: React.CSSProperties = {
  fontFamily: '"Segoe UI", "Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", sans-serif',
  color: '#17341A',
  background:
    'radial-gradient(circle at top left, rgba(255,255,255,0.96), rgba(233,245,221,0.94) 34%, rgba(246,236,191,0.92) 70%, rgba(221,240,206,0.95))',
};

const uiCopyEn: PromoUiCopy = {
  typedTask: 'Wrap today with one gentle closing task',
  captureBoardTitle: 'Quest Board',
  captureAddLabel: 'Add',
  captureRows: [
    'Review weekly summary copy',
    'Prepare one soft recovery quest',
    'Upload today memory snapshot',
    'Check guide opening flow',
  ],
  textBadges: ['Memory-aware flow', 'Real interaction evidence'],
  openerTop: 'Yesterday matters',
  openerTitle: 'Memory',
  openerBody: 'Use recent context before generating the next step.',
  openerChips: ['Recent rhythm', 'Daily context', 'Memory evidence'],
  memoryTitle: 'Memory bundle',
  memoryCount: '4 sources',
  memorySources: 'tasks · logs · signals · recall',
  memoryEvidenceTag: 'Evidence',
  memoryIncoming: [
    'Completed: Prepare one soft recovery quest',
    'Daily log: 3 quests done, rhythm steady',
    'Guide dialog: asked for a lighter next step',
  ],
  memoryEvidence: [
    'Recent context packaged',
    'Behavior signal: recovery is low',
    'Memory refs attached before generation',
  ],
  guideName: 'Xiaoyi',
  guideSubtitle: 'Guide panel · memory-aware',
  guideDigestLabel: 'Memory digest',
  guideDigestText:
    'Recent memory says you already pushed through several tasks today, but recovery actions are still missing.',
  userMessage: 'My energy is scattered today. Help me sort out the next step.',
  guideReply:
    'I checked what you finished recently and how today has been moving. Right now, the better next step is something light enough to restore control without adding pressure.',
  guideRefLabel: 'Based on 6 recent memory refs',
  guideActions: ['Help me sort it', 'Generate one light task', 'Open stats'],
  eventTag: 'Daily event',
  eventTitle: 'Restore control with one gentle recovery quest',
  eventReason:
    'You already pushed several things forward today, but recovery actions are still missing, so the system prioritizes one low-pressure task that can help you get back into rhythm.',
  eventMemoryLabel: 'Memory reason',
  eventMemoryText:
    'Based on recent task density, low recovery signals, and today’s guide context.',
  eventRewards: ['+30 XP', '+120 Gold'],
  eventAcceptLabel: 'Accept task',
  eventAcceptedTag: 'Inserted into board',
  eventAcceptedText: 'Gentle recovery quest is now live.',
  progressionCheckinLabel: '7-day streak',
  progressionLevelLabel: 'Lv.5 Apprentice Villager',
  progressionXpLabel: '1,260 / 1,800 XP',
  progressionStats: ['Weekly: 12 done', 'Streak: 7 days', 'Best day: 5'],
  progressionShopTitle: 'Reward Shop',
  progressionShopItems: ['30-min Break Pass', 'Dessert Voucher', 'Movie Night'],
  progressionShopPrices: ['80 Gold', '150 Gold', '300 Gold'],
  progressionRedeemedLabel: 'Redeemed!',
  diaryTitle: 'Life Diary',
  diaryEntries: [
    ['2026-03-18', 'Completed 3 quests · rhythm steady'],
    ['2026-03-17', 'Accepted a gentle recovery quest'],
    ['2026-03-16', 'Uploaded today memory snapshot'],
    ['2026-03-15', 'Weekly summary generated'],
  ],
  diaryStoredLabel: 'Stored as readable memory',
  diarySummaryTag: 'Weekly summary',
  diarySummaryTitle: 'Less friction. More forward motion.',
  diarySummaryText:
    'This week was not empty. Even on low-energy days, you still protected momentum. Memory reconnects those small actions into a line you can trust.',
  diaryBullets: [
    'Restart faster after low-energy days',
    'See why a suggestion appears now',
    'Keep real work connected across days',
  ],
};

const uiCopyZh: PromoUiCopy = {
  typedTask: '整理今天完成的事情，补一份温和的收尾计划',
  captureBoardTitle: '任务面板',
  captureAddLabel: '添加',
  captureRows: ['检查周总结文案', '准备一个轻量恢复任务', '上传今天的记忆快照', '确认助手打开流程'],
  textBadges: ['记忆驱动流程', '真实交互证据'],
  openerTop: '昨天也很重要',
  openerTitle: '记忆',
  openerBody: '先理解近期上下文，再决定下一步。',
  openerChips: ['近期节奏', '当日上下文', '记忆依据'],
  memoryTitle: '记忆包',
  memoryCount: '4 类来源',
  memorySources: '任务 · 日志 · 信号 · 回溯',
  memoryEvidenceTag: '依据',
  memoryIncoming: [
    '已完成：准备一个轻量恢复任务',
    '今日日志：完成 3 个任务，节奏稳定',
    '对话记录：用户想先整理下一步',
  ],
  memoryEvidence: ['近期上下文已整理', '行为信号显示恢复偏少', '生成前附带记忆引用'],
  guideName: '小依',
  guideSubtitle: '助手面板 · 先读记忆',
  guideDigestLabel: '记忆摘要',
  guideDigestText: '近期记忆显示你今天已经推进了几件事，但恢复动作还是偏少。',
  userMessage: '我今天状态有点散，先帮我理一下下一步。',
  guideReply:
    '我先看了你最近完成的任务和今天的节奏。现在更适合从一个更轻一点、但能帮你重新找回掌控感的动作开始。',
  guideRefLabel: '本次回答参考了 6 段近期记忆',
  guideActions: ['帮我理顺一下', '生成一个轻任务', '打开统计'],
  eventTag: '每日事件',
  eventTitle: '先用一个温和的恢复任务，把掌控感找回来',
  eventReason:
    '你今天已经推进了几件事，但恢复动作还不够，所以系统优先推荐一个负担更低、能帮你重新回到节奏里的任务。',
  eventMemoryLabel: '记忆依据',
  eventMemoryText: '综合近期任务密度、恢复信号偏低，以及今天的助手上下文得出。',
  eventRewards: ['+30 XP', '+120 金币'],
  eventAcceptLabel: '接受任务',
  eventAcceptedTag: '已插入任务板',
  eventAcceptedText: '轻量恢复任务现在已经上线。',
  progressionCheckinLabel: '连续 7 天',
  progressionLevelLabel: 'Lv.5 见习村民',
  progressionXpLabel: '1,260 / 1,800 XP',
  progressionStats: ['本周完成 12 个', '最长连续 7 天', '最佳一天 5 个'],
  progressionShopTitle: '奖励商店',
  progressionShopItems: ['30分钟摸鱼券', '甜品兑换券', '电影之夜'],
  progressionShopPrices: ['80 金币', '150 金币', '300 金币'],
  progressionRedeemedLabel: '已兑换!',
  diaryTitle: '生活日记',
  diaryEntries: [
    ['2026-03-18', '完成 3 个任务 · 节奏稳定'],
    ['2026-03-17', '接受了一个轻量恢复任务'],
    ['2026-03-16', '上传了今天的记忆快照'],
    ['2026-03-15', '生成了本周总结'],
  ],
  diaryStoredLabel: '已沉淀为可回看的记忆',
  diarySummaryTag: '周总结',
  diarySummaryTitle: '更少摩擦，更容易继续往前。',
  diarySummaryText:
    '这周你不是没有前进，而是在低能量的时候依然保住了推进。记忆把这些零散动作重新连成了一条线。',
  diaryBullets: ['低能量时更容易重新启动', '能看懂建议为什么此刻出现', '让跨天的真实工作保持连续'],
};

const copyByVariant: Record<PromoVariant, PromoUiCopy> = {
  en: uiCopyEn,
  zh: uiCopyZh,
};

const frameToOffset = (scenes: PromoScene[], id: string) => {
  let offset = 0;
  for (const scene of scenes) {
    if (scene.id === id) return offset;
    offset += scene.durationInFrames;
  }
  return 0;
};

const appear = (frame: number, start: number, duration: number) =>
  interpolate(frame, [start, start + duration], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.bezier(0.2, 0.8, 0.2, 1),
  });

const springIn = (frame: number, fps: number, start: number) => {
  if (frame < start) return 0;
  return spring({
    frame: frame - start,
    fps,
    config: {damping: 14, stiffness: 105},
  });
};

const typewriter = (text: string, frame: number, start: number, speed = 1.1) => {
  const count = Math.max(0, Math.floor((frame - start) / speed));
  return text.slice(0, count);
};

const AccentOrb: React.FC<{
  size: number;
  top: number;
  left?: number;
  right?: number;
  color: string;
  delay?: number;
}> = ({size, top, left, right, color, delay = 0}) => {
  const frame = useCurrentFrame();
  const drift = Math.sin((frame + delay) / 28) * 22;
  return (
    <div
      style={{
        position: 'absolute',
        width: size,
        height: size,
        borderRadius: size,
        top,
        left,
        right,
        background: color,
        filter: 'blur(10px)',
        opacity: 0.18,
        transform: `translateY(${drift}px)`,
      }}
    />
  );
};

const CaptionBar: React.FC<{text: string; accent: string}> = ({text, accent}) => (
  <div
    style={{
      position: 'absolute',
      left: 110,
      right: 110,
      bottom: 54,
      borderRadius: 28,
      padding: '18px 26px',
      background: 'rgba(249, 247, 239, 0.92)',
      border: '1px solid rgba(38, 73, 42, 0.09)',
      boxShadow: '0 14px 40px rgba(0,0,0,0.08)',
      display: 'flex',
      gap: 16,
      alignItems: 'center',
    }}
  >
    <div
      style={{
        width: 14,
        height: 14,
        borderRadius: 999,
        background: accent,
        boxShadow: `0 0 0 8px ${accent}20`,
      }}
    />
    <div
      style={{
        fontSize: 30,
        lineHeight: 1.35,
        color: '#24442A',
        fontWeight: 600,
      }}
    >
      {text}
    </div>
  </div>
);

const ScreenshotFrame: React.FC<{src: string; accent: string; width?: number}> = ({
  src,
  accent,
  width = 720,
}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const pop = springIn(frame, fps, 6);

  return (
    <div
      style={{
        position: 'relative',
        width,
        borderRadius: 34,
        padding: 18,
        background:
          'linear-gradient(145deg, rgba(255,255,255,0.96), rgba(252,248,232,0.9))',
        border: '1px solid rgba(47, 95, 52, 0.14)',
        boxShadow: '0 32px 90px rgba(29, 52, 31, 0.2)',
        transform: `scale(${1.06 - pop * 0.06}) translateY(${(1 - pop) * 24}px)`,
      }}
    >
      <div
        style={{
          position: 'absolute',
          inset: 10,
          borderRadius: 28,
          border: `2px solid ${accent}22`,
          pointerEvents: 'none',
        }}
      />
      <Img
        src={src}
        style={{
          width: '100%',
          display: 'block',
          borderRadius: 24,
        }}
      />
    </div>
  );
};

const FloatingChip: React.FC<{
  label: string;
  accent: string;
  start: number;
  top: number;
  left?: number;
  right?: number;
}> = ({label, accent, start, top, left, right}) => {
  const frame = useCurrentFrame();
  const alpha = appear(frame, start, 14);

  return (
    <div
      style={{
        position: 'absolute',
        top,
        left,
        right,
        padding: '12px 18px',
        borderRadius: 999,
        background: 'rgba(255,255,255,0.9)',
        border: `1px solid ${accent}33`,
        boxShadow: '0 16px 28px rgba(32, 52, 35, 0.12)',
        color: '#315137',
        fontSize: 20,
        fontWeight: 700,
        whiteSpace: 'nowrap',
        opacity: alpha,
        transform: `translateY(${(1 - alpha) * 16}px)`,
      }}
    >
      {label}
    </div>
  );
};

const ClickPulse: React.FC<{
  top: number;
  left: number;
  accent: string;
  start: number;
}> = ({top, left, accent, start}) => {
  const frame = useCurrentFrame();
  const size = interpolate(frame, [start, start + 18], [24, 110], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const fade = interpolate(frame, [start, start + 18], [0.9, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  if (frame < start || fade <= 0) return null;

  return (
    <div
      style={{
        position: 'absolute',
        top: top - size / 2,
        left: left - size / 2,
        width: size,
        height: size,
        borderRadius: 999,
        border: `3px solid ${accent}`,
        opacity: fade,
      }}
    />
  );
};

const SceneText: React.FC<{scene: PromoScene; copy: PromoUiCopy}> = ({scene, copy}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const titleIn = springIn(frame, fps, 0);
  const bodyIn = appear(frame, 10, 18);

  return (
    <div
      style={{
        width: 700,
        display: 'flex',
        flexDirection: 'column',
        gap: 22,
        transform: `translateY(${(1 - titleIn) * 24}px)`,
      }}
    >
      <div
        style={{
          alignSelf: 'flex-start',
          padding: '12px 20px',
          borderRadius: 999,
          background: `${scene.accent}16`,
          color: scene.accent,
          fontSize: 22,
          fontWeight: 800,
          letterSpacing: 0.4,
        }}
      >
        {scene.kicker}
      </div>
      <div
        style={{
          fontSize: 78,
          lineHeight: 1.02,
          fontWeight: 900,
          color: '#1A331F',
          maxWidth: 700,
        }}
      >
        {scene.title}
      </div>
      <div
        style={{
          opacity: bodyIn,
          fontSize: 31,
          lineHeight: 1.48,
          color: '#38533C',
          maxWidth: 660,
        }}
      >
        {scene.body}
      </div>
      <div style={{display: 'flex', gap: 12, flexWrap: 'wrap', opacity: bodyIn}}>
        {copy.textBadges.map((item) => (
          <div
            key={item}
            style={{
              padding: '11px 16px',
              borderRadius: 999,
              background: 'rgba(255,255,255,0.82)',
              border: '1px solid rgba(30, 64, 36, 0.08)',
              fontSize: 20,
              fontWeight: 700,
            }}
          >
            {item}
          </div>
        ))}
      </div>
    </div>
  );
};

const OpenerVisual: React.FC<{scene: PromoScene; copy: PromoUiCopy}> = ({scene, copy}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const orb = springIn(frame, fps, 10);
  const rightCard = appear(frame, 18, 16);

  return (
    <div style={{position: 'relative', width: 860, height: 700}}>
      <div
        style={{
          position: 'absolute',
          inset: 90,
          borderRadius: 999,
          background:
            'radial-gradient(circle, rgba(122,170,74,0.38), rgba(122,170,74,0.05) 62%, rgba(255,255,255,0) 80%)',
          transform: `scale(${0.92 + orb * 0.08})`,
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: 180,
          top: 136,
          width: 380,
          height: 380,
          borderRadius: 190,
          background:
            'linear-gradient(160deg, rgba(255,255,255,0.95), rgba(233,245,221,0.94))',
          border: `2px solid ${scene.accent}33`,
          boxShadow: '0 30px 90px rgba(28, 52, 30, 0.18)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexDirection: 'column',
          gap: 12,
        }}
      >
        <div style={{fontSize: 28, fontWeight: 700, color: '#4F714F'}}>{copy.openerTop}</div>
        <div style={{fontSize: 76, fontWeight: 900, color: scene.accent}}>{copy.openerTitle}</div>
        <div
          style={{
            fontSize: 22,
            lineHeight: 1.45,
            color: '#355538',
            maxWidth: 250,
            textAlign: 'center',
          }}
        >
          {copy.openerBody}
        </div>
      </div>
      <div
        style={{
          position: 'absolute',
          right: 0,
          top: 70,
          opacity: rightCard,
          transform: `translateX(${(1 - rightCard) * 20}px)`,
        }}
      >
        <ScreenshotFrame src={staticFile(scene.image!)} accent={scene.accent} width={360} />
      </div>
      <FloatingChip label={copy.openerChips[0]} accent={scene.accent} start={16} top={88} left={40} />
      <FloatingChip
        label={copy.openerChips[1]}
        accent={scene.accent}
        start={26}
        top={560}
        left={90}
      />
      <FloatingChip
        label={copy.openerChips[2]}
        accent={scene.accent}
        start={34}
        top={520}
        right={20}
      />
    </div>
  );
};

const CaptureVisual: React.FC<{scene: PromoScene; copy: PromoUiCopy}> = ({scene, copy}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const boardIn = springIn(frame, fps, 8);
  const completed = appear(frame, 68, 18);
  const typed = typewriter(copy.typedTask, frame, 12, 1.05);
  const xpRise = interpolate(frame, [72, 92], [42, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <div style={{position: 'relative', width: 860, height: 680}}>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          borderRadius: 34,
          background:
            'linear-gradient(145deg, rgba(255,255,255,0.95), rgba(245,249,236,0.92))',
          border: '1px solid rgba(45, 89, 48, 0.12)',
          boxShadow: '0 26px 70px rgba(32, 51, 35, 0.14)',
          overflow: 'hidden',
          transform: `translateY(${(1 - boardIn) * 24}px)`,
          opacity: boardIn,
        }}
      >
        <div
          style={{
            height: 90,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '0 28px',
            background: 'rgba(255,255,255,0.72)',
            borderBottom: '1px solid rgba(38, 73, 42, 0.08)',
          }}
        >
          <div style={{fontSize: 30, fontWeight: 800, color: '#234529'}}>{copy.captureBoardTitle}</div>
          <div style={{fontSize: 20, fontWeight: 700, color: '#61805E'}}>XP 1260</div>
        </div>
        <div style={{padding: '24px 28px 0'}}>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 12,
              padding: '18px',
              borderRadius: 24,
              background: 'rgba(248,251,244,0.95)',
              border: `1px solid ${scene.accent}26`,
            }}
          >
            <div
              style={{
                width: 18,
                height: 18,
                borderRadius: 999,
                border: `2px solid ${scene.accent}`,
              }}
            />
            <div style={{flex: 1, minHeight: 30, fontSize: 24, fontWeight: 600, color: '#305136'}}>
              {typed}
              <span style={{color: scene.accent, opacity: Math.floor(frame / 10) % 2 === 0 ? 1 : 0}}>
                |
              </span>
            </div>
            <div
              style={{
                padding: '10px 18px',
                borderRadius: 999,
                background: scene.accent,
                color: '#fff',
                fontSize: 18,
                fontWeight: 800,
              }}
            >
              {copy.captureAddLabel}
            </div>
          </div>
        </div>
        <div style={{padding: '26px 28px', display: 'grid', gap: 16}}>
          {copy.captureRows.map((label, index) => {
            const rowIn = appear(frame, 24 + index * 10, 14);
            const isDone = index === 2 ? completed > 0.3 : false;
            return (
              <div
                key={label}
                style={{
                  opacity: rowIn,
                  transform: `translateX(${(1 - rowIn) * 20}px)`,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 14,
                  padding: '16px 18px',
                  borderRadius: 22,
                  background: 'rgba(255,255,255,0.86)',
                  border: '1px solid rgba(38, 73, 42, 0.07)',
                }}
              >
                <div
                  style={{
                    width: 24,
                    height: 24,
                    borderRadius: 999,
                    background: isDone ? scene.accent : 'transparent',
                    border: `2px solid ${scene.accent}`,
                    color: '#fff',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: 15,
                    fontWeight: 900,
                  }}
                >
                  {isDone ? '✓' : ''}
                </div>
                <div
                  style={{
                    flex: 1,
                    fontSize: 24,
                    color: isDone ? '#6C7D6C' : '#29482E',
                    textDecoration: isDone ? 'line-through' : 'none',
                  }}
                >
                  {label}
                </div>
                <div style={{fontSize: 18, fontWeight: 700, color: '#6B8A67'}}>+20 XP</div>
              </div>
            );
          })}
        </div>
      </div>

      <ClickPulse top={143} left={738} accent={scene.accent} start={52} />
      <ClickPulse top={340} left={112} accent={scene.accent} start={70} />
      <div
        style={{
          position: 'absolute',
          right: 44,
          top: 250 + xpRise,
          opacity: interpolate(frame, [72, 78, 108], [0, 1, 0], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          }),
          color: scene.accent,
          fontSize: 34,
          fontWeight: 900,
        }}
      >
        +20 XP
      </div>
    </div>
  );
};

const MemoryVisual: React.FC<{scene: PromoScene; copy: PromoUiCopy}> = ({scene, copy}) => {
  const frame = useCurrentFrame();

  return (
    <div style={{position: 'relative', width: 860, height: 690}}>
      <div
        style={{
          position: 'absolute',
          left: 314,
          top: 124,
          width: 240,
          height: 240,
          borderRadius: 120,
          background:
            'linear-gradient(160deg, rgba(255,255,255,0.96), rgba(231,244,217,0.95))',
          border: `2px solid ${scene.accent}35`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexDirection: 'column',
          gap: 10,
          boxShadow: '0 28px 80px rgba(31, 58, 35, 0.16)',
        }}
      >
        <div style={{fontSize: 20, fontWeight: 700, color: '#537255'}}>{copy.memoryTitle}</div>
        <div style={{fontSize: 52, fontWeight: 900, color: scene.accent}}>{copy.memoryCount}</div>
        <div style={{fontSize: 18, color: '#456646'}}>{copy.memorySources}</div>
      </div>
      {copy.memoryIncoming.map((text, index) => {
        const show = appear(frame, 6 + index * 12, 16);
        const travel = appear(frame, 6 + index * 12, 52);
        return (
          <div
            key={text}
            style={{
              position: 'absolute',
              left: 20 + travel * 160,
              top: 50 + index * 110 + travel * (90 - index * 8),
              width: 280,
              padding: '18px 20px',
              borderRadius: 22,
              background: 'rgba(255,255,255,0.92)',
              border: '1px solid rgba(38, 73, 42, 0.08)',
              boxShadow: '0 18px 38px rgba(32, 51, 35, 0.1)',
              opacity: show,
              transform: `scale(${1 - travel * 0.08})`,
            }}
          >
            <div style={{fontSize: 20, lineHeight: 1.4, fontWeight: 700, color: '#2A4B2F'}}>
              {text}
            </div>
          </div>
        );
      })}
      {copy.memoryEvidence.map((text, index) => {
        const show = appear(frame, 68 + index * 10, 16);
        return (
          <div
            key={text}
            style={{
              position: 'absolute',
              right: 0,
              top: 80 + index * 126,
              width: 288,
              padding: '18px 20px',
              borderRadius: 22,
              background: 'rgba(247,250,240,0.96)',
              border: `1px solid ${scene.accent}24`,
              opacity: show,
              transform: `translateX(${(1 - show) * 24}px)`,
            }}
          >
            <div style={{fontSize: 14, fontWeight: 800, color: scene.accent, marginBottom: 8}}>
              {copy.memoryEvidenceTag}
            </div>
            <div style={{fontSize: 23, lineHeight: 1.35, fontWeight: 700, color: '#2D4D31'}}>
              {text}
            </div>
          </div>
        );
      })}
    </div>
  );
};

const GuideVisual: React.FC<{scene: PromoScene; copy: PromoUiCopy}> = ({scene, copy}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const panel = springIn(frame, fps, 8);
  const digest = appear(frame, 18, 16);
  const reply = appear(frame, 52, 18);
  const typedQuestion = typewriter(copy.userMessage, frame, 22, 1.1);

  return (
    <div style={{position: 'relative', width: 860, height: 700}}>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          borderRadius: 34,
          overflow: 'hidden',
          boxShadow: '0 28px 80px rgba(25, 45, 28, 0.16)',
          transform: `translateY(${(1 - panel) * 24}px)`,
          opacity: panel,
        }}
      >
        <Img
          src={staticFile(scene.image!)}
          style={{
            position: 'absolute',
            inset: 0,
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            filter: 'blur(1px) saturate(0.92)',
            opacity: 0.26,
          }}
        />
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background:
              'linear-gradient(180deg, rgba(249,247,239,0.92), rgba(243,247,236,0.96))',
          }}
        />
        <div style={{position: 'absolute', inset: 0, padding: 28}}>
          <div style={{display: 'flex', alignItems: 'center', gap: 14, marginBottom: 18}}>
            <div
              style={{
                width: 54,
                height: 54,
                borderRadius: 18,
                background: scene.accent,
                color: '#fff',
                fontSize: 30,
                fontWeight: 900,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              X
            </div>
            <div>
              <div style={{fontSize: 28, fontWeight: 900, color: '#254329'}}>{copy.guideName}</div>
              <div style={{fontSize: 18, color: '#567157'}}>{copy.guideSubtitle}</div>
            </div>
          </div>

          <div
            style={{
              borderRadius: 24,
              padding: '18px 20px',
              background: 'rgba(255,255,255,0.88)',
              border: `1px solid ${scene.accent}24`,
              marginBottom: 18,
              opacity: digest,
              transform: `translateY(${(1 - digest) * 18}px)`,
            }}
          >
            <div style={{fontSize: 14, fontWeight: 800, color: scene.accent, marginBottom: 8}}>
              {copy.guideDigestLabel}
            </div>
            <div style={{fontSize: 22, lineHeight: 1.45, color: '#2E4E33', fontWeight: 700}}>
              {copy.guideDigestText}
            </div>
          </div>

          <div
            style={{
              display: 'flex',
              justifyContent: 'flex-end',
              marginBottom: 14,
              opacity: appear(frame, 28, 14),
            }}
          >
            <div
              style={{
                maxWidth: 470,
                padding: '16px 18px',
                borderRadius: 24,
                background: scene.accent,
                color: '#fff',
                fontSize: 22,
                lineHeight: 1.45,
                fontWeight: 600,
              }}
            >
              {typedQuestion}
              <span style={{opacity: Math.floor(frame / 10) % 2 === 0 ? 1 : 0}}>|</span>
            </div>
          </div>

          <div
            style={{
              maxWidth: 560,
              padding: '18px 20px',
              borderRadius: 24,
              background: 'rgba(255,255,255,0.94)',
              border: '1px solid rgba(38, 73, 42, 0.08)',
              opacity: reply,
              transform: `translateY(${(1 - reply) * 20}px)`,
            }}
          >
            <div style={{fontSize: 23, lineHeight: 1.5, color: '#29482E', fontWeight: 600}}>
              {copy.guideReply}
            </div>
            <div
              style={{
                marginTop: 12,
                display: 'inline-flex',
                padding: '10px 14px',
                borderRadius: 999,
                background: '#EEF7E1',
                color: '#4F6E4F',
                fontSize: 17,
                fontWeight: 800,
              }}
            >
              {copy.guideRefLabel}
            </div>
          </div>

          <div style={{marginTop: 18, display: 'flex', gap: 10, opacity: appear(frame, 78, 14)}}>
            {copy.guideActions.map((item) => (
              <div
                key={item}
                style={{
                  padding: '12px 16px',
                  borderRadius: 999,
                  background: 'rgba(255,255,255,0.9)',
                  border: '1px solid rgba(38, 73, 42, 0.08)',
                  fontSize: 18,
                  fontWeight: 700,
                  color: '#355537',
                }}
              >
                {item}
              </div>
            ))}
          </div>
        </div>
      </div>
      <ClickPulse top={616} left={692} accent={scene.accent} start={24} />
    </div>
  );
};

const EventVisual: React.FC<{scene: PromoScene; copy: PromoUiCopy}> = ({scene, copy}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const modal = springIn(frame, fps, 34);
  const accepted = appear(frame, 88, 16);

  return (
    <div style={{position: 'relative', width: 860, height: 700}}>
      <div style={{position: 'absolute', inset: 0}}>
        <ScreenshotFrame src={staticFile(scene.image!)} accent={scene.accent} width={820} />
      </div>
      <div
        style={{
          position: 'absolute',
          left: 86,
          right: 86,
          top: 92,
          borderRadius: 30,
          padding: 28,
          background:
            'linear-gradient(160deg, rgba(255,252,243,0.98), rgba(249,247,239,0.97))',
          border: `1px solid ${scene.accent}2e`,
          boxShadow: '0 28px 80px rgba(30, 48, 32, 0.2)',
          opacity: modal,
          transform: `translateY(${(1 - modal) * 26}px)`,
        }}
      >
        <div style={{fontSize: 18, fontWeight: 800, color: '#A06C00', marginBottom: 10}}>
          {copy.eventTag}
        </div>
        <div style={{fontSize: 42, lineHeight: 1.12, fontWeight: 900, color: '#203622'}}>
          {copy.eventTitle}
        </div>
        <div style={{marginTop: 14, fontSize: 24, lineHeight: 1.5, color: '#415843'}}>
          {copy.eventReason}
        </div>
        <div
          style={{
            marginTop: 18,
            padding: '16px 18px',
            borderRadius: 22,
            background: '#FFF4D7',
            border: '1px solid rgba(218, 171, 63, 0.34)',
          }}
        >
          <div style={{fontSize: 16, fontWeight: 800, color: '#A06C00', marginBottom: 8}}>
            {copy.eventMemoryLabel}
          </div>
          <div style={{fontSize: 21, lineHeight: 1.45, fontWeight: 700, color: '#6D5310'}}>
            {copy.eventMemoryText}
          </div>
        </div>
        <div style={{display: 'flex', gap: 14, marginTop: 20}}>
          {copy.eventRewards.map((item, index) => (
            <div
              key={item}
              style={{
                padding: '12px 16px',
                borderRadius: 999,
                background: 'rgba(255,255,255,0.9)',
                fontSize: 18,
                fontWeight: 800,
                color: index === 0 ? '#5D6C58' : '#8B5B00',
              }}
            >
              {item}
            </div>
          ))}
          <div
            style={{
              marginLeft: 'auto',
              padding: '12px 22px',
              borderRadius: 999,
              background: scene.accent,
              color: '#fff',
              fontSize: 20,
              fontWeight: 900,
            }}
          >
            {copy.eventAcceptLabel}
          </div>
        </div>
      </div>
      <ClickPulse top={496} left={666} accent={scene.accent} start={84} />
      <div
        style={{
          position: 'absolute',
          right: 114,
          bottom: 78,
          padding: '16px 20px',
          borderRadius: 22,
          background: 'rgba(246, 250, 239, 0.96)',
          border: `1px solid ${scene.accent}22`,
          boxShadow: '0 18px 40px rgba(31, 48, 33, 0.12)',
          opacity: accepted,
          transform: `translateY(${(1 - accepted) * 20}px)`,
        }}
      >
        <div style={{fontSize: 18, fontWeight: 800, color: scene.accent}}>{copy.eventAcceptedTag}</div>
        <div style={{fontSize: 22, color: '#2C4B31', marginTop: 4}}>{copy.eventAcceptedText}</div>
      </div>
    </div>
  );
};

const ProgressionVisual: React.FC<{scene: PromoScene; copy: PromoUiCopy}> = ({scene, copy}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const dashIn = springIn(frame, fps, 8);
  const shopIn = appear(frame, 42, 18);
  const redeemed = appear(frame, 92, 14);
  const ringProgress = interpolate(frame, [14, 72], [0, 0.68], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.bezier(0.2, 0.8, 0.2, 1),
  });
  const ringRadius = 64;
  const ringCircumference = 2 * Math.PI * ringRadius;

  return (
    <div style={{position: 'relative', width: 860, height: 700}}>
      {/* Left: Growth Dashboard */}
      <div
        style={{
          position: 'absolute',
          left: 0,
          top: 0,
          width: 400,
          height: 680,
          borderRadius: 32,
          overflow: 'hidden',
          background:
            'linear-gradient(180deg, rgba(255,253,243,0.97), rgba(252,247,230,0.95))',
          border: '1px solid rgba(212, 149, 22, 0.14)',
          boxShadow: '0 24px 70px rgba(40, 36, 20, 0.14)',
          opacity: dashIn,
          transform: `translateY(${(1 - dashIn) * 22}px)`,
        }}
      >
        <div style={{padding: '24px 24px 16px', display: 'flex', gap: 12, alignItems: 'center'}}>
          <div
            style={{
              padding: '10px 16px',
              borderRadius: 999,
              background: 'rgba(255, 87, 34, 0.12)',
              color: '#E64A19',
              fontSize: 20,
              fontWeight: 800,
              display: 'flex',
              gap: 6,
              alignItems: 'center',
            }}
          >
            <span style={{fontSize: 22}}>🔥</span>
            {copy.progressionCheckinLabel}
          </div>
          <div
            style={{
              padding: '10px 16px',
              borderRadius: 999,
              background: `${scene.accent}18`,
              color: scene.accent,
              fontSize: 18,
              fontWeight: 800,
            }}
          >
            {copy.progressionLevelLabel}
          </div>
        </div>

        {/* XP Ring */}
        <div style={{display: 'flex', justifyContent: 'center', padding: '18px 0'}}>
          <div style={{position: 'relative', width: 160, height: 160}}>
            <svg width="160" height="160" viewBox="0 0 160 160" style={{transform: 'rotate(-90deg)'}}>
              <circle
                cx="80" cy="80" r={ringRadius}
                fill="none"
                stroke="rgba(212,149,22,0.14)"
                strokeWidth="12"
              />
              <circle
                cx="80" cy="80" r={ringRadius}
                fill="none"
                stroke={scene.accent}
                strokeWidth="12"
                strokeLinecap="round"
                strokeDasharray={ringCircumference}
                strokeDashoffset={ringCircumference * (1 - ringProgress)}
              />
            </svg>
            <div
              style={{
                position: 'absolute',
                inset: 0,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <div style={{fontSize: 28, fontWeight: 900, color: scene.accent}}>
                {Math.round(ringProgress * 100)}%
              </div>
              <div style={{fontSize: 14, color: '#8A7340', fontWeight: 700}}>
                {copy.progressionXpLabel}
              </div>
            </div>
          </div>
        </div>

        {/* 3-stat row */}
        <div style={{padding: '0 18px', display: 'flex', gap: 8}}>
          {copy.progressionStats.map((stat, i) => {
            const statIn = appear(frame, 30 + i * 8, 14);
            return (
              <div
                key={stat}
                style={{
                  flex: 1,
                  padding: '14px 10px',
                  borderRadius: 18,
                  background: 'rgba(255,255,255,0.88)',
                  border: '1px solid rgba(212, 149, 22, 0.1)',
                  textAlign: 'center',
                  opacity: statIn,
                  transform: `translateY(${(1 - statIn) * 12}px)`,
                }}
              >
                <div style={{fontSize: 17, fontWeight: 800, color: '#44381C', lineHeight: 1.4}}>
                  {stat}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Right: Reward Shop */}
      <div
        style={{
          position: 'absolute',
          right: 0,
          top: 60,
          width: 410,
          borderRadius: 30,
          padding: 24,
          background:
            'linear-gradient(155deg, rgba(255,255,249,0.98), rgba(249,245,234,0.96))',
          border: `1px solid ${scene.accent}28`,
          boxShadow: '0 26px 68px rgba(40, 36, 20, 0.15)',
          opacity: shopIn,
          transform: `translateX(${(1 - shopIn) * 24}px)`,
        }}
      >
        <div style={{fontSize: 26, fontWeight: 900, color: '#3A2F14', marginBottom: 18}}>
          {copy.progressionShopTitle}
        </div>
        {copy.progressionShopItems.map((item, i) => {
          const rowIn = appear(frame, 48 + i * 10, 14);
          const isRedeemed = i === 0 && redeemed > 0.3;
          return (
            <div
              key={item}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 14,
                padding: '16px 14px',
                marginBottom: 10,
                borderRadius: 20,
                background: isRedeemed ? `${scene.accent}14` : 'rgba(255,255,255,0.86)',
                border: `1px solid ${isRedeemed ? `${scene.accent}40` : 'rgba(212,149,22,0.08)'}`,
                opacity: rowIn,
                transform: `translateX(${(1 - rowIn) * 16}px)`,
              }}
            >
              <div
                style={{
                  width: 42,
                  height: 42,
                  borderRadius: 14,
                  background: `${scene.accent}18`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: 22,
                }}
              >
                {i === 0 ? '☕' : i === 1 ? '🍰' : '🎬'}
              </div>
              <div style={{flex: 1}}>
                <div style={{fontSize: 20, fontWeight: 800, color: '#3A2F14'}}>
                  {isRedeemed ? <s>{item}</s> : item}
                </div>
                <div style={{fontSize: 16, fontWeight: 700, color: '#8A7340'}}>
                  {copy.progressionShopPrices[i]}
                </div>
              </div>
              {isRedeemed && (
                <div
                  style={{
                    padding: '8px 14px',
                    borderRadius: 999,
                    background: scene.accent,
                    color: '#fff',
                    fontSize: 16,
                    fontWeight: 900,
                  }}
                >
                  {copy.progressionRedeemedLabel}
                </div>
              )}
            </div>
          );
        })}
      </div>

      <ClickPulse top={376} left={794} accent={scene.accent} start={88} />
    </div>
  );
};

const DiaryVisual: React.FC<{scene: PromoScene; copy: PromoUiCopy}> = ({scene, copy}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const shell = springIn(frame, fps, 8);
  const summary = appear(frame, 56, 18);
  const scroll = interpolate(frame, [10, 110], [0, -130], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <div style={{position: 'relative', width: 860, height: 700}}>
      <div
        style={{
          position: 'absolute',
          left: 0,
          top: 0,
          width: 360,
          height: 700,
          borderRadius: 32,
          overflow: 'hidden',
          background:
            'linear-gradient(180deg, rgba(255,255,255,0.96), rgba(244,248,238,0.94))',
          border: '1px solid rgba(38, 73, 42, 0.09)',
          boxShadow: '0 24px 72px rgba(30, 47, 32, 0.14)',
          opacity: shell,
          transform: `translateY(${(1 - shell) * 22}px)`,
        }}
      >
        <div
          style={{
            padding: '24px 24px 16px',
            borderBottom: '1px solid rgba(38, 73, 42, 0.08)',
            fontSize: 28,
            fontWeight: 900,
            color: '#214128',
          }}
        >
          {copy.diaryTitle}
        </div>
        <div
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            top: 86 + scroll,
            padding: '0 18px 18px',
            display: 'grid',
            gap: 12,
          }}
        >
          {copy.diaryEntries.map(([date, text]) => (
            <div
              key={date}
              style={{
                padding: '16px',
                borderRadius: 20,
                background: 'rgba(255,255,255,0.88)',
                border: '1px solid rgba(38, 73, 42, 0.07)',
              }}
            >
              <div style={{fontSize: 16, fontWeight: 800, color: scene.accent, marginBottom: 8}}>
                {date}
              </div>
              <div style={{fontSize: 20, lineHeight: 1.4, color: '#2C4B31', fontWeight: 700}}>
                {text}
              </div>
              <div style={{fontSize: 16, color: '#657A66', marginTop: 8}}>{copy.diaryStoredLabel}</div>
            </div>
          ))}
        </div>
      </div>
      <div
        style={{
          position: 'absolute',
          right: 0,
          top: 116,
          width: 450,
          borderRadius: 30,
          padding: 28,
          background:
            'linear-gradient(155deg, rgba(255,253,246,0.98), rgba(240,247,236,0.95))',
          border: `1px solid ${scene.accent}28`,
          boxShadow: '0 28px 70px rgba(31, 48, 33, 0.16)',
          opacity: summary,
          transform: `translateX(${(1 - summary) * 24}px)`,
        }}
      >
        <div style={{fontSize: 18, fontWeight: 800, color: scene.accent, marginBottom: 12}}>
          {copy.diarySummaryTag}
        </div>
        <div style={{fontSize: 38, lineHeight: 1.15, fontWeight: 900, color: '#203622'}}>
          {copy.diarySummaryTitle}
        </div>
        <div style={{fontSize: 22, lineHeight: 1.55, color: '#415843', marginTop: 16}}>
          {copy.diarySummaryText}
        </div>
        <div style={{marginTop: 18, display: 'grid', gap: 10}}>
          {copy.diaryBullets.map((line) => (
            <div
              key={line}
              style={{
                display: 'flex',
                gap: 12,
                alignItems: 'center',
                fontSize: 20,
                fontWeight: 700,
                color: '#2D4D31',
              }}
            >
              <div
                style={{
                  width: 14,
                  height: 14,
                  borderRadius: 999,
                  background: scene.accent,
                }}
              />
              {line}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

const SceneVisual: React.FC<{scene: PromoScene; copy: PromoUiCopy}> = ({scene, copy}) => {
  switch (scene.kind) {
    case 'opener':
      return <OpenerVisual scene={scene} copy={copy} />;
    case 'capture':
      return <CaptureVisual scene={scene} copy={copy} />;
    case 'memory':
      return <MemoryVisual scene={scene} copy={copy} />;
    case 'guide':
      return <GuideVisual scene={scene} copy={copy} />;
    case 'event':
      return <EventVisual scene={scene} copy={copy} />;
    case 'progression':
      return <ProgressionVisual scene={scene} copy={copy} />;
    case 'diary':
      return <DiaryVisual scene={scene} copy={copy} />;
    default:
      return null;
  }
};

const SceneView: React.FC<{scene: PromoScene; copy: PromoUiCopy}> = ({scene, copy}) => {
  const frame = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();
  const fade = interpolate(frame, [0, 14, durationInFrames - 16, durationInFrames], [0, 1, 1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill style={{...shellStyle, opacity: fade}}>
      <AccentOrb size={220} top={120} left={56} color={scene.accent} />
      <AccentOrb size={180} top={780} right={120} color="#F6D768" delay={14} />
      <AccentOrb size={150} top={420} right={280} color="#73C37E" delay={26} />

      <div
        style={{
          position: 'absolute',
          inset: 0,
          padding: '106px 96px 154px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 46,
        }}
      >
        <SceneText scene={scene} copy={copy} />
        <div
          style={{
            width: 860,
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
          }}
        >
          <SceneVisual scene={scene} copy={copy} />
        </div>
      </div>

      <CaptionBar text={scene.caption} accent={scene.accent} />
    </AbsoluteFill>
  );
};

const PromoComposition: React.FC<PromoCompositionProps> = ({
  scenes = promoScenesEn,
  audioDir = 'audio',
  variant = 'en',
}) => {
  const copy = copyByVariant[variant];
  let offset = 0;

  return (
    <AbsoluteFill style={shellStyle}>
      {scenes.map((scene) => {
        const currentOffset = offset;
        offset += scene.durationInFrames;

        return (
          <Sequence
            key={scene.id}
            from={currentOffset}
            durationInFrames={scene.durationInFrames}
            premountFor={15}
          >
            <SceneView scene={scene} copy={copy} />
          </Sequence>
        );
      })}

      {scenes.map((scene) => (
        <Sequence
          key={`${scene.id}-audio`}
          from={frameToOffset(scenes, scene.id)}
          durationInFrames={scene.durationInFrames}
          premountFor={15}
        >
          <Audio src={staticFile(`${audioDir}/${scene.id}.wav`)} volume={0.95} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};

export const EarthOnlinePromo: React.FC = () => {
  return <PromoComposition scenes={promoScenesEn} audioDir="audio" variant="en" />;
};

export const EarthOnlinePromoZh: React.FC = () => {
  return <PromoComposition scenes={promoScenesZh} audioDir="audio-zh" variant="zh" />;
};

/* ─── Standalone Poster Compositions ─── */

type PosterCopy = {
  title: string;
  subtitle: string;
  tagline: string;
  features: [string, string, string, string, string];
  cta: string;
  url: string;
  statsLine: string;
  memoryFlow: [string, string, string];
  achievements: [string, string, string];
  guideBubble: string;
};

const posterCopyEn: PosterCopy = {
  title: 'Earth Online',
  subtitle: 'Memory-Aware Productivity Game',
  tagline: 'The task app that remembers your rhythm, tracks your growth, and turns effort into real rewards.',
  features: ['Quest Board', 'Memory Guide', 'Daily Check-in', 'Growth Stats', 'Reward Shop'],
  cta: 'Try it live',
  url: 'earth-online-wine.vercel.app',
  statsLine: '247 quests · 38-day streak · Lv.12',
  memoryFlow: ['Tasks completed', 'Context packed', 'Guide informed'],
  achievements: ['First Quest', '7-Day Streak', 'Memory Master'],
  guideBubble: 'Recovery looks smart right now. Try one light task to get back in rhythm.',
};

const posterCopyZh: PosterCopy = {
  title: 'Earth Online',
  subtitle: '会记忆的效率游戏',
  tagline: '记住你的节奏，追踪你的成长，把每一份付出变成看得见的奖励。',
  features: ['任务面板', '记忆助手', '每日签到', '成长仪表盘', '奖励商店'],
  cta: '立即体验',
  url: 'earth-online-wine.vercel.app',
  statsLine: '247 个任务 · 连续 38 天 · Lv.12',
  memoryFlow: ['完成任务', '打包上下文', '助手就绪'],
  achievements: ['首个任务', '连续7天', '记忆大师'],
  guideBubble: '现在适合恢复节奏，试试从一个轻量任务开始。',
};

const PosterComposition: React.FC<{copy: PosterCopy}> = ({copy}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const titleIn = springIn(frame, fps, 0);
  const subIn = appear(frame, 6, 14);
  const tagIn = appear(frame, 12, 14);
  const chipsIn = appear(frame, 18, 16);
  const ctaIn = springIn(frame, fps, 24);
  const flowIn = appear(frame, 14, 18);
  const badgesIn = appear(frame, 20, 16);
  const ringProgress = interpolate(frame, [6, 30], [0, 0.72], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.bezier(0.2, 0.8, 0.2, 1),
  });
  const ringR = 72;
  const ringC = 2 * Math.PI * ringR;

  const chipColors = ['#2F8A43', '#2F7C39', '#E64A19', '#D49516', '#8A6B1A'];
  const chipIcons = ['📋', '🧠', '🔥', '📊', '🎁'];
  const badgeIcons = ['⚔️', '🔥', '🧠'];

  return (
    <AbsoluteFill
      style={{
        ...shellStyle,
        background:
          'radial-gradient(ellipse at 20% 25%, rgba(233,245,221,0.96) 0%, rgba(255,253,243,0.97) 35%, rgba(246,236,191,0.92) 70%, rgba(221,240,206,0.95) 100%)',
      }}
    >
      {/* Decorative orbs */}
      <div style={{position: 'absolute', top: 40, left: 30, width: 320, height: 320, borderRadius: 320, background: 'rgba(47,138,67,0.08)', filter: 'blur(50px)'}} />
      <div style={{position: 'absolute', bottom: 60, right: 60, width: 280, height: 280, borderRadius: 280, background: 'rgba(212,149,22,0.1)', filter: 'blur(40px)'}} />
      <div style={{position: 'absolute', top: 500, left: 400, width: 200, height: 200, borderRadius: 200, background: 'rgba(115,195,126,0.08)', filter: 'blur(30px)'}} />
      <div style={{position: 'absolute', top: 150, right: 500, width: 140, height: 140, borderRadius: 140, background: 'rgba(230,74,25,0.06)', filter: 'blur(25px)'}} />

      <div style={{position: 'absolute', inset: 0, display: 'flex', padding: '60px 90px', gap: 60}}>
        {/* ─── Left column ─── */}
        <div style={{flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 18, transform: `translateY(${(1 - titleIn) * 16}px)`}}>
          {/* Product icon (globe + checkmark) + title */}
          <div style={{display: 'flex', alignItems: 'center', gap: 18}}>
            <div style={{
              width: 78, height: 78, borderRadius: 24, position: 'relative',
              background: 'linear-gradient(145deg, #2F8A43, #4BA556)',
              boxShadow: '0 14px 40px rgba(47,138,67,0.35)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <div style={{fontSize: 40, lineHeight: 1}}>🌍</div>
              <div style={{
                position: 'absolute', right: -4, bottom: -4,
                width: 28, height: 28, borderRadius: 999,
                background: '#fff', border: '2px solid #2F8A43',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 14, fontWeight: 900, color: '#2F8A43',
              }}>✓</div>
            </div>
            <div style={{fontSize: 62, fontWeight: 900, color: '#1A331F', letterSpacing: -1}}>{copy.title}</div>
          </div>

          {/* Subtitle */}
          <div style={{opacity: subIn, fontSize: 32, fontWeight: 800, color: '#2F8A43', transform: `translateY(${(1 - subIn) * 10}px)`}}>
            {copy.subtitle}
          </div>

          {/* Tagline */}
          <div style={{opacity: tagIn, fontSize: 23, lineHeight: 1.55, color: '#38533C', maxWidth: 580, transform: `translateY(${(1 - tagIn) * 8}px)`}}>
            {copy.tagline}
          </div>

          {/* Feature chips with icons */}
          <div style={{display: 'flex', flexWrap: 'wrap', gap: 10, marginTop: 4, opacity: chipsIn, transform: `translateY(${(1 - chipsIn) * 12}px)`}}>
            {copy.features.map((f, i) => (
              <div key={f} style={{
                padding: '10px 18px', borderRadius: 999, display: 'flex', gap: 8, alignItems: 'center',
                background: 'rgba(255,255,255,0.9)',
                border: `1px solid ${chipColors[i]}20`,
                boxShadow: '0 4px 14px rgba(30,50,32,0.06)',
                fontSize: 18, fontWeight: 700, color: chipColors[i],
              }}>
                <span style={{fontSize: 16}}>{chipIcons[i]}</span>{f}
              </div>
            ))}
          </div>

          {/* Memory flow pipeline */}
          <div style={{
            marginTop: 8, padding: '14px 20px', borderRadius: 20,
            background: 'rgba(255,255,255,0.8)',
            border: '1px solid rgba(47,138,67,0.1)',
            boxShadow: '0 8px 28px rgba(30,50,32,0.06)',
            opacity: flowIn, transform: `translateY(${(1 - flowIn) * 10}px)`,
            display: 'flex', alignItems: 'center', gap: 14,
          }}>
            {copy.memoryFlow.map((step, i) => (
              <React.Fragment key={step}>
                <div style={{
                  padding: '8px 14px', borderRadius: 14,
                  background: i === 2 ? '#2F8A4316' : 'rgba(248,251,244,0.95)',
                  border: `1px solid ${i === 2 ? '#2F8A4330' : 'rgba(38,73,42,0.06)'}`,
                  fontSize: 16, fontWeight: 700, color: '#2A5E30', whiteSpace: 'nowrap',
                }}>{step}</div>
                {i < 2 && <div style={{fontSize: 18, color: '#2F8A4360', fontWeight: 800}}>→</div>}
              </React.Fragment>
            ))}
          </div>

          {/* Achievement badges row */}
          <div style={{display: 'flex', gap: 12, opacity: badgesIn, transform: `translateY(${(1 - badgesIn) * 10}px)`}}>
            {copy.achievements.map((badge, i) => (
              <div key={badge} style={{
                padding: '10px 16px', borderRadius: 18, display: 'flex', gap: 8, alignItems: 'center',
                background: 'linear-gradient(145deg, rgba(255,253,240,0.95), rgba(255,248,220,0.92))',
                border: '1px solid rgba(212,149,22,0.18)',
                boxShadow: '0 6px 20px rgba(40,36,20,0.08)',
                fontSize: 16, fontWeight: 800, color: '#6D5310',
              }}>
                <span style={{fontSize: 18}}>{badgeIcons[i]}</span>{badge}
              </div>
            ))}
          </div>

          {/* Stats line */}
          <div style={{opacity: badgesIn, fontSize: 17, fontWeight: 700, color: '#5B8A5E', marginTop: 2}}>
            {copy.statsLine}
          </div>

          {/* CTA */}
          <div style={{display: 'flex', alignItems: 'center', gap: 16, transform: `scale(${0.95 + ctaIn * 0.05})`}}>
            <div style={{
              padding: '14px 30px', borderRadius: 999,
              background: 'linear-gradient(135deg, #2F8A43, #5B9E48)',
              color: '#fff', fontSize: 21, fontWeight: 900,
              boxShadow: '0 10px 28px rgba(47,138,67,0.3)',
            }}>
              {copy.cta}
            </div>
            <div style={{fontSize: 18, color: '#5B8A5E', fontWeight: 600}}>{copy.url}</div>
          </div>
        </div>

        {/* ─── Right column ─── */}
        <div style={{width: 560, position: 'relative'}}>
          {/* Quest board card */}
          <div style={{
            position: 'absolute', left: 0, top: 20, width: 400, borderRadius: 28, padding: 20,
            background: 'linear-gradient(155deg, rgba(255,255,255,0.96), rgba(245,249,236,0.93))',
            border: '1px solid rgba(45,89,48,0.1)',
            boxShadow: '0 24px 64px rgba(32,51,35,0.14)',
            opacity: appear(frame, 8, 16),
            transform: `translateY(${(1 - appear(frame, 8, 16)) * 16}px)`,
          }}>
            <div style={{display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12}}>
              <div style={{width: 11, height: 11, borderRadius: 999, background: '#2F8A43'}} />
              <div style={{fontSize: 20, fontWeight: 800, color: '#234529'}}>Quest Board</div>
              <div style={{marginLeft: 'auto', fontSize: 15, fontWeight: 700, color: '#61805E'}}>Lv.12</div>
            </div>
            {['Review weekly summary', 'Prepare recovery quest', 'Upload memory snapshot', 'Check guide flow'].map((t, i) => (
              <div key={t} style={{
                display: 'flex', gap: 10, alignItems: 'center',
                padding: '10px 12px', marginBottom: 6, borderRadius: 14,
                background: i < 2 ? '#2F8A4310' : 'rgba(255,255,255,0.7)',
                border: '1px solid rgba(38,73,42,0.05)',
              }}>
                <div style={{
                  width: 18, height: 18, borderRadius: 999,
                  background: i < 2 ? '#2F8A43' : 'transparent',
                  border: '2px solid #2F8A43',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  color: '#fff', fontSize: 11, fontWeight: 900,
                }}>{i < 2 ? '✓' : ''}</div>
                <div style={{
                  fontSize: 16, fontWeight: 600,
                  color: i < 2 ? '#6C7D6C' : '#29482E',
                  textDecoration: i < 2 ? 'line-through' : 'none',
                }}>{t}</div>
                <div style={{marginLeft: 'auto', fontSize: 13, fontWeight: 700, color: '#6B8A67'}}>+20 XP</div>
              </div>
            ))}
          </div>

          {/* XP Ring */}
          <div style={{
            position: 'absolute', right: 10, top: 160, width: 180, height: 180,
            borderRadius: 28, padding: 16,
            background: 'linear-gradient(155deg, rgba(255,253,243,0.98), rgba(252,247,230,0.96))',
            border: '1px solid rgba(212,149,22,0.16)',
            boxShadow: '0 20px 54px rgba(40,36,20,0.15)',
            opacity: appear(frame, 16, 16),
            transform: `translateX(${(1 - appear(frame, 16, 16)) * 18}px)`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="148" height="148" viewBox="0 0 180 180" style={{transform: 'rotate(-90deg)'}}>
              <circle cx="90" cy="90" r={ringR} fill="none" stroke="rgba(212,149,22,0.14)" strokeWidth="12" />
              <circle cx="90" cy="90" r={ringR} fill="none" stroke="#D49516" strokeWidth="12"
                strokeLinecap="round" strokeDasharray={ringC} strokeDashoffset={ringC * (1 - ringProgress)} />
            </svg>
            <div style={{position: 'absolute', display: 'flex', flexDirection: 'column', alignItems: 'center'}}>
              <div style={{fontSize: 26, fontWeight: 900, color: '#D49516'}}>{Math.round(ringProgress * 100)}%</div>
              <div style={{fontSize: 12, fontWeight: 700, color: '#8A7340'}}>1,260 XP</div>
            </div>
          </div>

          {/* Streak + reward chips */}
          <FloatingChip label="🔥 7-day streak" accent="#E64A19" start={20} top={370} left={10} />
          <FloatingChip label="☕ Redeemed!" accent="#D49516" start={24} top={370} right={30} />

          {/* Reward shop mini card */}
          <div style={{
            position: 'absolute', right: 0, top: 420, width: 260, borderRadius: 22, padding: 16,
            background: 'linear-gradient(155deg, rgba(255,255,249,0.97), rgba(249,245,234,0.95))',
            border: '1px solid rgba(212,149,22,0.14)',
            boxShadow: '0 18px 48px rgba(40,36,20,0.12)',
            opacity: appear(frame, 26, 14),
            transform: `translateX(${(1 - appear(frame, 26, 14)) * 16}px)`,
          }}>
            <div style={{fontSize: 16, fontWeight: 800, color: '#3A2F14', marginBottom: 10}}>🎁 Reward Shop</div>
            {['30-min Break', 'Dessert Voucher'].map((item, i) => (
              <div key={item} style={{
                display: 'flex', gap: 8, alignItems: 'center',
                padding: '8px 10px', marginBottom: 6, borderRadius: 14,
                background: i === 0 ? '#D4951610' : 'rgba(255,255,255,0.7)',
                border: '1px solid rgba(212,149,22,0.06)',
              }}>
                <span style={{fontSize: 16}}>{i === 0 ? '☕' : '🍰'}</span>
                <div style={{flex: 1, fontSize: 14, fontWeight: 700, color: '#3A2F14'}}>{item}</div>
                <div style={{fontSize: 12, fontWeight: 700, color: '#8A7340'}}>{i === 0 ? '80g' : '150g'}</div>
              </div>
            ))}
          </div>

          {/* Guide bubble */}
          <div style={{
            position: 'absolute', left: 0, bottom: 30, width: 340, borderRadius: 22,
            padding: '14px 16px',
            background: 'rgba(255,255,255,0.94)',
            border: '1px solid rgba(47,138,67,0.12)',
            boxShadow: '0 16px 40px rgba(32,51,35,0.12)',
            opacity: appear(frame, 28, 14),
            transform: `translateY(${(1 - appear(frame, 28, 14)) * 14}px)`,
          }}>
            <div style={{display: 'flex', gap: 8, alignItems: 'center', marginBottom: 6}}>
              <div style={{
                width: 28, height: 28, borderRadius: 9,
                background: '#2F7C39', color: '#fff',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 15, fontWeight: 900,
              }}>🧠</div>
              <div style={{fontSize: 15, fontWeight: 800, color: '#254329'}}>Guide</div>
              <div style={{
                marginLeft: 'auto', padding: '3px 8px', borderRadius: 999,
                background: '#EEF7E1', fontSize: 11, fontWeight: 800, color: '#4F6E4F',
              }}>6 memory refs</div>
            </div>
            <div style={{fontSize: 14, lineHeight: 1.5, color: '#2E4E33', fontWeight: 600}}>
              {copy.guideBubble}
            </div>
          </div>
        </div>
      </div>
    </AbsoluteFill>
  );
};

export const EarthOnlinePoster: React.FC = () => <PosterComposition copy={posterCopyEn} />;
export const EarthOnlinePosterZh: React.FC = () => <PosterComposition copy={posterCopyZh} />;
