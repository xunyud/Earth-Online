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
  color: '#E8F5E9',
  background: '#0B1E13',
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
        filter: `blur(${Math.round(size * 0.45)}px)`,
        opacity: 0.12,
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
      background: 'rgba(255, 255, 255, 0.05)',
      border: '1px solid rgba(255,255,255,0.08)',
      boxShadow: '0 14px 40px rgba(0,0,0,0.3)',
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
        boxShadow: `0 0 12px ${accent}50`,
      }}
    />
    <div
      style={{
        fontSize: 30,
        lineHeight: 1.35,
        color: 'rgba(200,230,202,0.8)',
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
        background: 'rgba(255,255,255,0.04)',
        border: `1px solid ${accent}20`,
        boxShadow: `0 32px 90px rgba(0,0,0,0.4), 0 0 40px ${accent}10`,
        transform: `scale(${1.06 - pop * 0.06}) translateY(${(1 - pop) * 24}px)`,
      }}
    >
      <div
        style={{
          position: 'absolute',
          inset: 10,
          borderRadius: 28,
          border: `1px solid ${accent}15`,
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
        background: 'rgba(255,255,255,0.06)',
        border: `1px solid ${accent}30`,
        boxShadow: `0 16px 28px rgba(0,0,0,0.3), 0 0 16px ${accent}12`,
        color: accent,
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
          background: `${scene.accent}18`,
          border: `1px solid ${scene.accent}30`,
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
          color: '#FFFFFF',
          maxWidth: 700,
          textShadow: `0 0 40px ${scene.accent}25`,
        }}
      >
        {scene.title}
      </div>
      <div
        style={{
          opacity: bodyIn,
          fontSize: 31,
          lineHeight: 1.48,
          color: 'rgba(200,230,202,0.7)',
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
              background: 'rgba(255,255,255,0.06)',
              border: '1px solid rgba(255,255,255,0.1)',
              fontSize: 20,
              fontWeight: 700,
              color: '#7BAF80',
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
            `radial-gradient(circle, ${scene.accent}20, ${scene.accent}05 62%, transparent 80%)`,
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
          background: 'rgba(255,255,255,0.04)',
          border: `2px solid ${scene.accent}25`,
          boxShadow: `0 30px 90px rgba(0,0,0,0.4), 0 0 60px ${scene.accent}15`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexDirection: 'column',
          gap: 12,
        }}
      >
        <div style={{fontSize: 28, fontWeight: 700, color: '#7BAF80'}}>{copy.openerTop}</div>
        <div style={{fontSize: 76, fontWeight: 900, color: scene.accent, textShadow: `0 0 30px ${scene.accent}40`}}>{copy.openerTitle}</div>
        <div
          style={{
            fontSize: 22,
            lineHeight: 1.45,
            color: 'rgba(200,230,202,0.7)',
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
      <FloatingChip label={copy.openerChips[1]} accent={scene.accent} start={26} top={560} left={90} />
      <FloatingChip label={copy.openerChips[2]} accent={scene.accent} start={34} top={520} right={20} />
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
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp',
  });

  return (
    <div style={{position: 'relative', width: 860, height: 680}}>
      <div
        style={{
          position: 'absolute', inset: 0, borderRadius: 34,
          background: 'rgba(255,255,255,0.04)',
          border: `1px solid ${scene.accent}18`,
          boxShadow: `0 26px 70px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.05)`,
          overflow: 'hidden',
          transform: `translateY(${(1 - boardIn) * 24}px)`, opacity: boardIn,
        }}
      >
        <div style={{
          height: 90, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '0 28px', background: 'rgba(255,255,255,0.03)',
          borderBottom: '1px solid rgba(255,255,255,0.06)',
        }}>
          <div style={{fontSize: 30, fontWeight: 800, color: '#E8F5E9'}}>{copy.captureBoardTitle}</div>
          <div style={{fontSize: 20, fontWeight: 700, color: '#7BAF80'}}>XP 1260</div>
        </div>
        <div style={{padding: '24px 28px 0'}}>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 12, padding: '18px',
            borderRadius: 24, background: 'rgba(255,255,255,0.04)',
            border: `1px solid ${scene.accent}20`,
          }}>
            <div style={{width: 18, height: 18, borderRadius: 999, border: `2px solid ${scene.accent}60`}} />
            <div style={{flex: 1, minHeight: 30, fontSize: 24, fontWeight: 600, color: '#C8E6CA'}}>
              {typed}
              <span style={{color: scene.accent, opacity: Math.floor(frame / 10) % 2 === 0 ? 1 : 0}}>|</span>
            </div>
            <div style={{
              padding: '10px 18px', borderRadius: 999,
              background: `linear-gradient(135deg, ${scene.accent}, ${scene.accent}cc)`,
              color: '#0B1E13', fontSize: 18, fontWeight: 800,
            }}>
              {copy.captureAddLabel}
            </div>
          </div>
        </div>
        <div style={{padding: '26px 28px', display: 'grid', gap: 16}}>
          {copy.captureRows.map((label, index) => {
            const rowIn = appear(frame, 24 + index * 10, 14);
            const isDone = index === 2 ? completed > 0.3 : false;
            return (
              <div key={label} style={{
                opacity: rowIn, transform: `translateX(${(1 - rowIn) * 20}px)`,
                display: 'flex', alignItems: 'center', gap: 14,
                padding: '16px 18px', borderRadius: 22,
                background: isDone ? `${scene.accent}10` : 'rgba(255,255,255,0.03)',
                border: '1px solid rgba(255,255,255,0.05)',
              }}>
                <div style={{
                  width: 24, height: 24, borderRadius: 999,
                  background: isDone ? scene.accent : 'transparent',
                  border: `2px solid ${isDone ? scene.accent : `${scene.accent}50`}`,
                  color: '#0B1E13', display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 15, fontWeight: 900,
                }}>
                  {isDone ? '✓' : ''}
                </div>
                <div style={{
                  flex: 1, fontSize: 24,
                  color: isDone ? 'rgba(200,230,202,0.4)' : '#C8E6CA',
                  textDecoration: isDone ? 'line-through' : 'none',
                }}>
                  {label}
                </div>
                <div style={{fontSize: 18, fontWeight: 700, color: `${scene.accent}80`}}>+20 XP</div>
              </div>
            );
          })}
        </div>
      </div>

      <ClickPulse top={143} left={738} accent={scene.accent} start={52} />
      <ClickPulse top={340} left={112} accent={scene.accent} start={70} />
      <div style={{
        position: 'absolute', right: 44, top: 250 + xpRise,
        opacity: interpolate(frame, [72, 78, 108], [0, 1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}),
        color: scene.accent, fontSize: 34, fontWeight: 900,
        textShadow: `0 0 20px ${scene.accent}50`,
      }}>
        +20 XP
      </div>
    </div>
  );
};

const MemoryVisual: React.FC<{scene: PromoScene; copy: PromoUiCopy}> = ({scene, copy}) => {
  const frame = useCurrentFrame();

  return (
    <div style={{position: 'relative', width: 860, height: 690}}>
      <div style={{
        position: 'absolute', left: 314, top: 124, width: 240, height: 240, borderRadius: 120,
        background: 'rgba(255,255,255,0.04)',
        border: `2px solid ${scene.accent}25`,
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 10,
        boxShadow: `0 28px 80px rgba(0,0,0,0.4), 0 0 50px ${scene.accent}12`,
      }}>
        <div style={{fontSize: 20, fontWeight: 700, color: '#7BAF80'}}>{copy.memoryTitle}</div>
        <div style={{fontSize: 52, fontWeight: 900, color: scene.accent, textShadow: `0 0 20px ${scene.accent}40`}}>{copy.memoryCount}</div>
        <div style={{fontSize: 18, color: 'rgba(200,230,202,0.5)'}}>{copy.memorySources}</div>
      </div>
      {copy.memoryIncoming.map((text, index) => {
        const show = appear(frame, 6 + index * 12, 16);
        const travel = appear(frame, 6 + index * 12, 52);
        return (
          <div key={text} style={{
            position: 'absolute', left: 20 + travel * 160, top: 50 + index * 110 + travel * (90 - index * 8),
            width: 280, padding: '18px 20px', borderRadius: 22,
            background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.08)',
            boxShadow: '0 18px 38px rgba(0,0,0,0.3)',
            opacity: show, transform: `scale(${1 - travel * 0.08})`,
          }}>
            <div style={{fontSize: 20, lineHeight: 1.4, fontWeight: 700, color: '#C8E6CA'}}>{text}</div>
          </div>
        );
      })}
      {copy.memoryEvidence.map((text, index) => {
        const show = appear(frame, 68 + index * 10, 16);
        return (
          <div key={text} style={{
            position: 'absolute', right: 0, top: 80 + index * 126, width: 288,
            padding: '18px 20px', borderRadius: 22,
            background: `${scene.accent}08`, border: `1px solid ${scene.accent}20`,
            opacity: show, transform: `translateX(${(1 - show) * 24}px)`,
          }}>
            <div style={{fontSize: 14, fontWeight: 800, color: scene.accent, marginBottom: 8}}>{copy.memoryEvidenceTag}</div>
            <div style={{fontSize: 23, lineHeight: 1.35, fontWeight: 700, color: '#C8E6CA'}}>{text}</div>
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
      <div style={{
        position: 'absolute', inset: 0, borderRadius: 34, overflow: 'hidden',
        boxShadow: `0 28px 80px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.05)`,
        transform: `translateY(${(1 - panel) * 24}px)`, opacity: panel,
      }}>
        <Img src={staticFile(scene.image!)} style={{
          position: 'absolute', inset: 0, width: '100%', height: '100%',
          objectFit: 'cover', filter: 'blur(2px) saturate(0.6) brightness(0.2)', opacity: 0.4,
        }} />
        <div style={{position: 'absolute', inset: 0, background: 'rgba(11,30,19,0.85)'}} />
        <div style={{position: 'absolute', inset: 0, padding: 28}}>
          <div style={{display: 'flex', alignItems: 'center', gap: 14, marginBottom: 18}}>
            <div style={{
              width: 54, height: 54, borderRadius: 18,
              background: `linear-gradient(145deg, ${scene.accent}, ${scene.accent}aa)`,
              color: '#0B1E13', fontSize: 30, fontWeight: 900,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              boxShadow: `0 0 20px ${scene.accent}30`,
            }}>X</div>
            <div>
              <div style={{fontSize: 28, fontWeight: 900, color: '#E8F5E9'}}>{copy.guideName}</div>
              <div style={{fontSize: 18, color: '#7BAF80'}}>{copy.guideSubtitle}</div>
            </div>
          </div>

          <div style={{
            borderRadius: 24, padding: '18px 20px',
            background: `${scene.accent}0a`, border: `1px solid ${scene.accent}20`,
            marginBottom: 18, opacity: digest, transform: `translateY(${(1 - digest) * 18}px)`,
          }}>
            <div style={{fontSize: 14, fontWeight: 800, color: scene.accent, marginBottom: 8}}>{copy.guideDigestLabel}</div>
            <div style={{fontSize: 22, lineHeight: 1.45, color: '#C8E6CA', fontWeight: 700}}>{copy.guideDigestText}</div>
          </div>

          <div style={{display: 'flex', justifyContent: 'flex-end', marginBottom: 14, opacity: appear(frame, 28, 14)}}>
            <div style={{
              maxWidth: 470, padding: '16px 18px', borderRadius: 24,
              background: `linear-gradient(135deg, ${scene.accent}, ${scene.accent}cc)`,
              color: '#0B1E13', fontSize: 22, lineHeight: 1.45, fontWeight: 600,
            }}>
              {typedQuestion}
              <span style={{opacity: Math.floor(frame / 10) % 2 === 0 ? 1 : 0}}>|</span>
            </div>
          </div>

          <div style={{
            maxWidth: 560, padding: '18px 20px', borderRadius: 24,
            background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.08)',
            opacity: reply, transform: `translateY(${(1 - reply) * 20}px)`,
          }}>
            <div style={{fontSize: 23, lineHeight: 1.5, color: '#C8E6CA', fontWeight: 600}}>{copy.guideReply}</div>
            <div style={{
              marginTop: 12, display: 'inline-flex', padding: '10px 14px', borderRadius: 999,
              background: `${scene.accent}15`, border: `1px solid ${scene.accent}25`,
              color: scene.accent, fontSize: 17, fontWeight: 800,
            }}>{copy.guideRefLabel}</div>
          </div>

          <div style={{marginTop: 18, display: 'flex', gap: 10, opacity: appear(frame, 78, 14)}}>
            {copy.guideActions.map((item) => (
              <div key={item} style={{
                padding: '12px 16px', borderRadius: 999,
                background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.1)',
                fontSize: 18, fontWeight: 700, color: '#7BAF80',
              }}>{item}</div>
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
      <div style={{
        position: 'absolute', left: 86, right: 86, top: 92, borderRadius: 30, padding: 28,
        background: 'rgba(15,30,20,0.92)', border: `1px solid ${scene.accent}25`,
        boxShadow: `0 28px 80px rgba(0,0,0,0.5), 0 0 40px ${scene.accent}08`,
        opacity: modal, transform: `translateY(${(1 - modal) * 26}px)`,
      }}>
        <div style={{fontSize: 18, fontWeight: 800, color: scene.accent, marginBottom: 10}}>{copy.eventTag}</div>
        <div style={{fontSize: 42, lineHeight: 1.12, fontWeight: 900, color: '#FFFFFF'}}>{copy.eventTitle}</div>
        <div style={{marginTop: 14, fontSize: 24, lineHeight: 1.5, color: 'rgba(200,230,202,0.7)'}}>{copy.eventReason}</div>
        <div style={{
          marginTop: 18, padding: '16px 18px', borderRadius: 22,
          background: `${scene.accent}0c`, border: `1px solid ${scene.accent}20`,
        }}>
          <div style={{fontSize: 16, fontWeight: 800, color: scene.accent, marginBottom: 8}}>{copy.eventMemoryLabel}</div>
          <div style={{fontSize: 21, lineHeight: 1.45, fontWeight: 700, color: '#C8E6CA'}}>{copy.eventMemoryText}</div>
        </div>
        <div style={{display: 'flex', gap: 14, marginTop: 20}}>
          {copy.eventRewards.map((item, index) => (
            <div key={item} style={{
              padding: '12px 16px', borderRadius: 999,
              background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.1)',
              fontSize: 18, fontWeight: 800,
              color: index === 0 ? '#7BAF80' : scene.accent,
            }}>{item}</div>
          ))}
          <div style={{
            marginLeft: 'auto', padding: '12px 22px', borderRadius: 999,
            background: `linear-gradient(135deg, ${scene.accent}, ${scene.accent}cc)`,
            color: '#0B1E13', fontSize: 20, fontWeight: 900,
            boxShadow: `0 0 20px ${scene.accent}30`,
          }}>{copy.eventAcceptLabel}</div>
        </div>
      </div>
      <ClickPulse top={496} left={666} accent={scene.accent} start={84} />
      <div style={{
        position: 'absolute', right: 114, bottom: 78, padding: '16px 20px', borderRadius: 22,
        background: `${scene.accent}10`, border: `1px solid ${scene.accent}25`,
        boxShadow: '0 18px 40px rgba(0,0,0,0.3)',
        opacity: accepted, transform: `translateY(${(1 - accepted) * 20}px)`,
      }}>
        <div style={{fontSize: 18, fontWeight: 800, color: scene.accent}}>{copy.eventAcceptedTag}</div>
        <div style={{fontSize: 22, color: '#C8E6CA', marginTop: 4}}>{copy.eventAcceptedText}</div>
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
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp',
    easing: Easing.bezier(0.2, 0.8, 0.2, 1),
  });
  const ringRadius = 64;
  const ringCircumference = 2 * Math.PI * ringRadius;

  return (
    <div style={{position: 'relative', width: 860, height: 700}}>
      {/* Left: Growth Dashboard */}
      <div style={{
        position: 'absolute', left: 0, top: 0, width: 400, height: 680, borderRadius: 32, overflow: 'hidden',
        background: 'rgba(255,255,255,0.04)',
        border: `1px solid ${scene.accent}18`,
        boxShadow: `0 24px 70px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.05)`,
        opacity: dashIn, transform: `translateY(${(1 - dashIn) * 22}px)`,
      }}>
        <div style={{padding: '24px 24px 16px', display: 'flex', gap: 12, alignItems: 'center'}}>
          <div style={{
            padding: '10px 16px', borderRadius: 999,
            background: 'rgba(255,138,80,0.12)', border: '1px solid rgba(255,138,80,0.25)',
            color: '#FF8A50', fontSize: 20, fontWeight: 800, display: 'flex', gap: 6, alignItems: 'center',
          }}>
            <span style={{fontSize: 22}}>🔥</span>{copy.progressionCheckinLabel}
          </div>
          <div style={{
            padding: '10px 16px', borderRadius: 999,
            background: `${scene.accent}12`, border: `1px solid ${scene.accent}25`,
            color: scene.accent, fontSize: 18, fontWeight: 800,
          }}>{copy.progressionLevelLabel}</div>
        </div>

        <div style={{display: 'flex', justifyContent: 'center', padding: '18px 0'}}>
          <div style={{position: 'relative', width: 160, height: 160}}>
            <svg width="160" height="160" viewBox="0 0 160 160" style={{transform: 'rotate(-90deg)'}}>
              <circle cx="80" cy="80" r={ringRadius} fill="none" stroke={`${scene.accent}18`} strokeWidth="12" />
              <circle cx="80" cy="80" r={ringRadius} fill="none" stroke={scene.accent} strokeWidth="12"
                strokeLinecap="round" strokeDasharray={ringCircumference} strokeDashoffset={ringCircumference * (1 - ringProgress)} />
            </svg>
            <div style={{position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center'}}>
              <div style={{fontSize: 28, fontWeight: 900, color: scene.accent}}>{Math.round(ringProgress * 100)}%</div>
              <div style={{fontSize: 14, color: `${scene.accent}80`, fontWeight: 700}}>{copy.progressionXpLabel}</div>
            </div>
          </div>
        </div>

        <div style={{padding: '0 18px', display: 'flex', gap: 8}}>
          {copy.progressionStats.map((stat, i) => {
            const statIn = appear(frame, 30 + i * 8, 14);
            return (
              <div key={stat} style={{
                flex: 1, padding: '14px 10px', borderRadius: 18,
                background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.06)',
                textAlign: 'center' as const, opacity: statIn, transform: `translateY(${(1 - statIn) * 12}px)`,
              }}>
                <div style={{fontSize: 17, fontWeight: 800, color: '#C8E6CA', lineHeight: 1.4}}>{stat}</div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Right: Reward Shop */}
      <div style={{
        position: 'absolute', right: 0, top: 60, width: 410, borderRadius: 30, padding: 24,
        background: 'rgba(255,209,102,0.04)',
        border: `1px solid ${scene.accent}18`,
        boxShadow: '0 26px 68px rgba(0,0,0,0.4)',
        opacity: shopIn, transform: `translateX(${(1 - shopIn) * 24}px)`,
      }}>
        <div style={{fontSize: 26, fontWeight: 900, color: scene.accent, marginBottom: 18}}>{copy.progressionShopTitle}</div>
        {copy.progressionShopItems.map((item, i) => {
          const rowIn = appear(frame, 48 + i * 10, 14);
          const isRedeemed = i === 0 && redeemed > 0.3;
          return (
            <div key={item} style={{
              display: 'flex', alignItems: 'center', gap: 14,
              padding: '16px 14px', marginBottom: 10, borderRadius: 20,
              background: isRedeemed ? `${scene.accent}10` : 'rgba(255,255,255,0.03)',
              border: `1px solid ${isRedeemed ? `${scene.accent}30` : 'rgba(255,255,255,0.06)'}`,
              opacity: rowIn, transform: `translateX(${(1 - rowIn) * 16}px)`,
            }}>
              <div style={{
                width: 42, height: 42, borderRadius: 14,
                background: `${scene.accent}12`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22,
              }}>{i === 0 ? '☕' : i === 1 ? '🍰' : '🎬'}</div>
              <div style={{flex: 1}}>
                <div style={{fontSize: 20, fontWeight: 800, color: '#E8F5E9'}}>
                  {isRedeemed ? <s>{item}</s> : item}
                </div>
                <div style={{fontSize: 16, fontWeight: 700, color: `${scene.accent}80`}}>{copy.progressionShopPrices[i]}</div>
              </div>
              {isRedeemed && (
                <div style={{
                  padding: '8px 14px', borderRadius: 999,
                  background: `linear-gradient(135deg, ${scene.accent}, ${scene.accent}cc)`,
                  color: '#0B1E13', fontSize: 16, fontWeight: 900,
                  boxShadow: `0 0 16px ${scene.accent}30`,
                }}>{copy.progressionRedeemedLabel}</div>
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
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp',
  });

  return (
    <div style={{position: 'relative', width: 860, height: 700}}>
      <div style={{
        position: 'absolute', left: 0, top: 0, width: 360, height: 700, borderRadius: 32, overflow: 'hidden',
        background: 'rgba(255,255,255,0.04)',
        border: `1px solid ${scene.accent}15`,
        boxShadow: `0 24px 72px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.05)`,
        opacity: shell, transform: `translateY(${(1 - shell) * 22}px)`,
      }}>
        <div style={{
          padding: '24px 24px 16px',
          borderBottom: '1px solid rgba(255,255,255,0.06)',
          fontSize: 28, fontWeight: 900, color: '#E8F5E9',
        }}>{copy.diaryTitle}</div>
        <div style={{
          position: 'absolute', left: 0, right: 0, top: 86 + scroll,
          padding: '0 18px 18px', display: 'grid', gap: 12,
        }}>
          {copy.diaryEntries.map(([date, text]) => (
            <div key={date} style={{
              padding: '16px', borderRadius: 20,
              background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.06)',
            }}>
              <div style={{fontSize: 16, fontWeight: 800, color: scene.accent, marginBottom: 8}}>{date}</div>
              <div style={{fontSize: 20, lineHeight: 1.4, color: '#C8E6CA', fontWeight: 700}}>{text}</div>
              <div style={{fontSize: 16, color: 'rgba(123,175,128,0.5)', marginTop: 8}}>{copy.diaryStoredLabel}</div>
            </div>
          ))}
        </div>
      </div>
      <div style={{
        position: 'absolute', right: 0, top: 116, width: 450, borderRadius: 30, padding: 28,
        background: 'rgba(255,255,255,0.04)',
        border: `1px solid ${scene.accent}20`,
        boxShadow: '0 28px 70px rgba(0,0,0,0.4)',
        opacity: summary, transform: `translateX(${(1 - summary) * 24}px)`,
      }}>
        <div style={{fontSize: 18, fontWeight: 800, color: scene.accent, marginBottom: 12}}>{copy.diarySummaryTag}</div>
        <div style={{fontSize: 38, lineHeight: 1.15, fontWeight: 900, color: '#FFFFFF'}}>{copy.diarySummaryTitle}</div>
        <div style={{fontSize: 22, lineHeight: 1.55, color: 'rgba(200,230,202,0.7)', marginTop: 16}}>{copy.diarySummaryText}</div>
        <div style={{marginTop: 18, display: 'grid', gap: 10}}>
          {copy.diaryBullets.map((line) => (
            <div key={line} style={{
              display: 'flex', gap: 12, alignItems: 'center',
              fontSize: 20, fontWeight: 700, color: '#C8E6CA',
            }}>
              <div style={{width: 14, height: 14, borderRadius: 999, background: scene.accent, boxShadow: `0 0 8px ${scene.accent}40`}} />
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
      {/* deep background layers */}
      <div style={{position: 'absolute', inset: 0, background: 'radial-gradient(ellipse at 30% 20%, #143024 0%, #0B1E13 50%, #0D1A10 100%)'}} />
      <div style={{position: 'absolute', inset: 0, background: 'radial-gradient(ellipse at 75% 80%, rgba(26,46,32,0.9) 0%, transparent 60%)'}} />
      {/* subtle grid */}
      <div style={{position: 'absolute', inset: 0, opacity: 0.025, backgroundImage: 'linear-gradient(rgba(255,255,255,0.5) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.5) 1px, transparent 1px)', backgroundSize: '80px 80px'}} />

      <AccentOrb size={320} top={-40} left={-30} color={scene.accent} />
      <AccentOrb size={260} top={700} right={80} color="#FFD166" delay={14} />
      <AccentOrb size={200} top={350} right={300} color={scene.accent} delay={26} />

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
  guideLabel: string;
  guideMemoryTag: string;
  questBoardTitle: string;
  questRows: [string, string, string, string];
  rewardShopTitle: string;
  rewardItems: [string, string];
  rewardPrices: [string, string];
  streakChip: string;
  redeemChip: string;
  levelLabel: string;
  xpLabel: string;
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
  guideLabel: 'Guide',
  guideMemoryTag: '6 memory refs',
  questBoardTitle: 'Quest Board',
  questRows: ['Review weekly summary', 'Prepare recovery quest', 'Upload memory snapshot', 'Check guide flow'],
  rewardShopTitle: 'Reward Shop',
  rewardItems: ['30-min Break', 'Dessert Voucher'],
  rewardPrices: ['80g', '150g'],
  streakChip: '7-day streak',
  redeemChip: 'Redeemed!',
  levelLabel: 'Lv.12',
  xpLabel: '1,260 XP',
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
  guideLabel: '助手',
  guideMemoryTag: '6 段记忆参考',
  questBoardTitle: '任务面板',
  questRows: ['整理本周回顾', '准备恢复任务', '上传记忆快照', '检查引导流程'],
  rewardShopTitle: '奖励商店',
  rewardItems: ['30分钟休息', '甜品兑换券'],
  rewardPrices: ['80金', '150金'],
  streakChip: '连续 7 天',
  redeemChip: '已兑换!',
  levelLabel: 'Lv.12',
  xpLabel: '1,260 XP',
};

const PosterComposition: React.FC<{copy: PosterCopy}> = ({copy}) => {
  const frame = useCurrentFrame();
  const {fps: fpsVal} = useVideoConfig();

  /* ── animation helpers (all fully visible at frame 30) ── */
  const a = (start: number, dur = 14) => appear(frame, start, dur);
  const sIn = (start: number) => springIn(frame, fpsVal, start);

  const ringProgress = interpolate(frame, [4, 28], [0, 0.72], {
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp',
    easing: Easing.bezier(0.2, 0.8, 0.2, 1),
  });
  const ringR = 62;
  const ringC = 2 * Math.PI * ringR;

  const chipColors = ['#3CD05B', '#34C759', '#FF8A50', '#FFD166', '#C9A84C'];
  const chipIcons = ['📋', '🧠', '🔥', '📊', '🎁'];
  const badgeIcons = ['⚔️', '🔥', '🧠'];

  const font = '"Segoe UI", "Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", sans-serif';

  return (
    <AbsoluteFill style={{fontFamily: font, color: '#E8F5E9', background: '#0B1E13'}}>
      {/* ── deep background gradient ── */}
      <div style={{position: 'absolute', inset: 0, background: 'radial-gradient(ellipse at 30% 20%, #143024 0%, #0B1E13 50%, #0D1A10 100%)'}} />
      <div style={{position: 'absolute', inset: 0, background: 'radial-gradient(ellipse at 75% 80%, rgba(26,46,32,0.9) 0%, transparent 60%)'}} />

      {/* ── ambient glow orbs ── */}
      <div style={{position: 'absolute', top: -80, left: -60, width: 600, height: 600, borderRadius: 600, background: 'rgba(60,208,91,0.12)', filter: 'blur(120px)'}} />
      <div style={{position: 'absolute', bottom: -100, right: -40, width: 500, height: 500, borderRadius: 500, background: 'rgba(255,209,102,0.10)', filter: 'blur(100px)'}} />
      <div style={{position: 'absolute', top: 300, left: 700, width: 350, height: 350, borderRadius: 350, background: 'rgba(255,138,80,0.07)', filter: 'blur(80px)'}} />
      <div style={{position: 'absolute', top: 100, right: 300, width: 250, height: 250, borderRadius: 250, background: 'rgba(60,208,91,0.06)', filter: 'blur(60px)'}} />

      {/* ── subtle grid overlay ── */}
      <div style={{
        position: 'absolute', inset: 0, opacity: 0.03,
        backgroundImage: 'linear-gradient(rgba(255,255,255,0.5) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.5) 1px, transparent 1px)',
        backgroundSize: '80px 80px',
      }} />

      {/* ═══════ CENTER COLUMN: Brand identity ═══════ */}
      <div style={{
        position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center', zIndex: 10,
      }}>
        {/* Product icon */}
        <div style={{
          width: 110, height: 110, borderRadius: 32, position: 'relative',
          background: 'linear-gradient(145deg, #2F8A43, #3CD05B)',
          boxShadow: '0 0 60px rgba(60,208,91,0.4), 0 20px 50px rgba(0,0,0,0.3)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          opacity: sIn(0), transform: `scale(${0.8 + sIn(0) * 0.2})`,
          marginBottom: 20,
        }}>
          <div style={{fontSize: 56, lineHeight: 1}}>🌍</div>
          <div style={{
            position: 'absolute', right: -6, bottom: -6,
            width: 34, height: 34, borderRadius: 999,
            background: '#fff', border: '3px solid #3CD05B',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 17, fontWeight: 900, color: '#2F8A43',
          }}>✓</div>
        </div>

        {/* Title */}
        <div style={{
          fontSize: 82, fontWeight: 900, color: '#fff', letterSpacing: -2, lineHeight: 1,
          textShadow: '0 0 40px rgba(60,208,91,0.3)',
          opacity: sIn(2), transform: `translateY(${(1 - sIn(2)) * 20}px)`,
        }}>{copy.title}</div>

        {/* Subtitle */}
        <div style={{
          fontSize: 30, fontWeight: 800, color: '#FFD166', marginTop: 10,
          textShadow: '0 0 20px rgba(255,209,102,0.3)',
          opacity: a(4), transform: `translateY(${(1 - a(4)) * 12}px)`,
        }}>{copy.subtitle}</div>

        {/* Tagline */}
        <div style={{
          fontSize: 20, lineHeight: 1.6, color: 'rgba(200,230,202,0.7)', maxWidth: 620,
          textAlign: 'center', marginTop: 10,
          opacity: a(6), transform: `translateY(${(1 - a(6)) * 8}px)`,
        }}>{copy.tagline}</div>

        {/* Feature chips row */}
        <div style={{
          display: 'flex', gap: 12, marginTop: 22,
          opacity: a(8, 16), transform: `translateY(${(1 - a(8, 16)) * 14}px)`,
        }}>
          {copy.features.map((f, i) => (
            <div key={f} style={{
              padding: '10px 18px', borderRadius: 999, display: 'flex', gap: 8, alignItems: 'center',
              background: 'rgba(255,255,255,0.06)',
              border: `1px solid ${chipColors[i]}40`,
              boxShadow: `0 0 20px ${chipColors[i]}15`,
              fontSize: 17, fontWeight: 700, color: chipColors[i],
            }}>
              <span style={{fontSize: 15}}>{chipIcons[i]}</span>{f}
            </div>
          ))}
        </div>

        {/* Memory flow pipeline */}
        <div style={{
          marginTop: 18, padding: '12px 22px', borderRadius: 20,
          background: 'rgba(255,255,255,0.05)',
          border: '1px solid rgba(60,208,91,0.15)',
          opacity: a(10, 16), transform: `translateY(${(1 - a(10, 16)) * 10}px)`,
          display: 'flex', alignItems: 'center', gap: 14,
        }}>
          {copy.memoryFlow.map((step, i) => (
            <React.Fragment key={step}>
              <div style={{
                padding: '8px 14px', borderRadius: 14,
                background: i === 2 ? 'rgba(60,208,91,0.12)' : 'rgba(255,255,255,0.04)',
                border: `1px solid ${i === 2 ? 'rgba(60,208,91,0.3)' : 'rgba(255,255,255,0.06)'}`,
                fontSize: 15, fontWeight: 700, color: i === 2 ? '#3CD05B' : '#7BAF80', whiteSpace: 'nowrap' as const,
              }}>{step}</div>
              {i < 2 && <div style={{fontSize: 18, color: 'rgba(60,208,91,0.4)', fontWeight: 800}}>→</div>}
            </React.Fragment>
          ))}
        </div>

        {/* Achievement badges */}
        <div style={{
          display: 'flex', gap: 12, marginTop: 16,
          opacity: a(14, 16), transform: `translateY(${(1 - a(14, 16)) * 10}px)`,
        }}>
          {copy.achievements.map((badge, i) => (
            <div key={badge} style={{
              padding: '9px 16px', borderRadius: 16, display: 'flex', gap: 8, alignItems: 'center',
              background: 'linear-gradient(145deg, rgba(255,209,102,0.1), rgba(255,209,102,0.05))',
              border: '1px solid rgba(255,209,102,0.2)',
              fontSize: 15, fontWeight: 800, color: '#FFD166',
            }}>
              <span style={{fontSize: 17}}>{badgeIcons[i]}</span>{badge}
            </div>
          ))}
        </div>

        {/* Stats line */}
        <div style={{
          fontSize: 16, fontWeight: 700, color: 'rgba(123,175,128,0.6)', marginTop: 12,
          opacity: a(16),
        }}>{copy.statsLine}</div>

        {/* CTA row */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 18, marginTop: 18,
          opacity: a(18, 12), transform: `scale(${0.95 + a(18, 12) * 0.05})`,
        }}>
          <div style={{
            padding: '14px 34px', borderRadius: 999,
            background: 'linear-gradient(135deg, #2F8A43, #3CD05B)',
            color: '#fff', fontSize: 20, fontWeight: 900,
            boxShadow: '0 0 30px rgba(60,208,91,0.35), 0 12px 30px rgba(0,0,0,0.2)',
          }}>{copy.cta}</div>
          <div style={{fontSize: 17, color: '#7BAF80', fontWeight: 600}}>{copy.url}</div>
        </div>
      </div>

      {/* ═══════ LEFT SIDE: Quest Board card ═══════ */}
      <div style={{
        position: 'absolute', left: 50, top: 80, width: 370, borderRadius: 24, padding: 18,
        background: 'rgba(255,255,255,0.05)',
        border: '1px solid rgba(60,208,91,0.12)',
        boxShadow: '0 30px 80px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.05)',
        opacity: a(6, 18),
        transform: `rotate(-3deg) translateY(${(1 - a(6, 18)) * 20}px)`,
        zIndex: 5,
      }}>
        <div style={{display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12}}>
          <div style={{width: 10, height: 10, borderRadius: 999, background: '#3CD05B', boxShadow: '0 0 8px rgba(60,208,91,0.5)'}} />
          <div style={{fontSize: 18, fontWeight: 800, color: '#E8F5E9'}}>{copy.questBoardTitle}</div>
          <div style={{marginLeft: 'auto', fontSize: 14, fontWeight: 700, color: '#7BAF80'}}>{copy.levelLabel}</div>
        </div>
        {copy.questRows.map((t, i) => (
          <div key={t} style={{
            display: 'flex', gap: 10, alignItems: 'center',
            padding: '9px 11px', marginBottom: 5, borderRadius: 12,
            background: i < 2 ? 'rgba(60,208,91,0.08)' : 'rgba(255,255,255,0.03)',
            border: '1px solid rgba(255,255,255,0.04)',
          }}>
            <div style={{
              width: 16, height: 16, borderRadius: 999,
              background: i < 2 ? '#3CD05B' : 'transparent',
              border: `2px solid ${i < 2 ? '#3CD05B' : 'rgba(60,208,91,0.4)'}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: '#0B1E13', fontSize: 10, fontWeight: 900,
            }}>{i < 2 ? '✓' : ''}</div>
            <div style={{
              fontSize: 14, fontWeight: 600,
              color: i < 2 ? 'rgba(200,230,202,0.4)' : '#C8E6CA',
              textDecoration: i < 2 ? 'line-through' : 'none',
            }}>{t}</div>
            <div style={{marginLeft: 'auto', fontSize: 12, fontWeight: 700, color: 'rgba(60,208,91,0.5)'}}>+20 XP</div>
          </div>
        ))}
      </div>

      {/* ═══════ LEFT BOTTOM: XP Ring ═══════ */}
      <div style={{
        position: 'absolute', left: 80, bottom: 100, width: 170, height: 170,
        borderRadius: 28, padding: 14,
        background: 'rgba(255,209,102,0.05)',
        border: '1px solid rgba(255,209,102,0.15)',
        boxShadow: '0 24px 60px rgba(0,0,0,0.35), 0 0 30px rgba(255,209,102,0.08)',
        opacity: a(10, 18),
        transform: `rotate(2deg) translateY(${(1 - a(10, 18)) * 20}px)`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        zIndex: 5,
      }}>
        <svg width="130" height="130" viewBox="0 0 160 160" style={{transform: 'rotate(-90deg)'}}>
          <circle cx="80" cy="80" r={ringR} fill="none" stroke="rgba(255,209,102,0.12)" strokeWidth="10" />
          <circle cx="80" cy="80" r={ringR} fill="none" stroke="#FFD166" strokeWidth="10"
            strokeLinecap="round" strokeDasharray={ringC} strokeDashoffset={ringC * (1 - ringProgress)} />
        </svg>
        <div style={{position: 'absolute', display: 'flex', flexDirection: 'column', alignItems: 'center'}}>
          <div style={{fontSize: 24, fontWeight: 900, color: '#FFD166'}}>{Math.round(ringProgress * 100)}%</div>
          <div style={{fontSize: 11, fontWeight: 700, color: 'rgba(255,209,102,0.6)'}}>{copy.xpLabel}</div>
        </div>
      </div>

      {/* ═══════ RIGHT SIDE: Guide bubble ═══════ */}
      <div style={{
        position: 'absolute', right: 50, top: 100, width: 350, borderRadius: 22,
        padding: '16px 18px',
        background: 'rgba(255,255,255,0.05)',
        border: '1px solid rgba(60,208,91,0.12)',
        boxShadow: '0 24px 60px rgba(0,0,0,0.35), inset 0 1px 0 rgba(255,255,255,0.05)',
        opacity: a(8, 18),
        transform: `rotate(2deg) translateY(${(1 - a(8, 18)) * 18}px)`,
        zIndex: 5,
      }}>
        <div style={{display: 'flex', gap: 8, alignItems: 'center', marginBottom: 8}}>
          <div style={{
            width: 30, height: 30, borderRadius: 10,
            background: 'linear-gradient(145deg, #2F7C39, #3CD05B)',
            color: '#fff',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 16, fontWeight: 900,
            boxShadow: '0 0 12px rgba(60,208,91,0.3)',
          }}>🧠</div>
          <div style={{fontSize: 16, fontWeight: 800, color: '#E8F5E9'}}>{copy.guideLabel}</div>
          <div style={{
            marginLeft: 'auto', padding: '4px 10px', borderRadius: 999,
            background: 'rgba(60,208,91,0.1)',
            border: '1px solid rgba(60,208,91,0.2)',
            fontSize: 11, fontWeight: 800, color: '#3CD05B',
          }}>{copy.guideMemoryTag}</div>
        </div>
        <div style={{fontSize: 14, lineHeight: 1.55, color: 'rgba(200,230,202,0.8)', fontWeight: 600}}>
          {copy.guideBubble}
        </div>
      </div>

      {/* ═══════ RIGHT BOTTOM: Reward shop mini card ═══════ */}
      <div style={{
        position: 'absolute', right: 60, bottom: 80, width: 260, borderRadius: 22, padding: 16,
        background: 'rgba(255,209,102,0.04)',
        border: '1px solid rgba(255,209,102,0.12)',
        boxShadow: '0 24px 60px rgba(0,0,0,0.35)',
        opacity: a(14, 16),
        transform: `rotate(-2deg) translateY(${(1 - a(14, 16)) * 18}px)`,
        zIndex: 5,
      }}>
        <div style={{fontSize: 15, fontWeight: 800, color: '#FFD166', marginBottom: 10}}>🎁 {copy.rewardShopTitle}</div>
        {copy.rewardItems.map((item, i) => (
          <div key={item} style={{
            display: 'flex', gap: 8, alignItems: 'center',
            padding: '8px 10px', marginBottom: 5, borderRadius: 12,
            background: i === 0 ? 'rgba(255,209,102,0.08)' : 'rgba(255,255,255,0.03)',
            border: '1px solid rgba(255,209,102,0.06)',
          }}>
            <span style={{fontSize: 15}}>{i === 0 ? '☕' : '🍰'}</span>
            <div style={{flex: 1, fontSize: 13, fontWeight: 700, color: '#E8F5E9'}}>{item}</div>
            <div style={{fontSize: 11, fontWeight: 700, color: 'rgba(255,209,102,0.6)'}}>{copy.rewardPrices[i]}</div>
          </div>
        ))}
      </div>

      {/* ═══════ FLOATING CHIPS: streak / redeemed ═══════ */}
      <div style={{
        position: 'absolute', left: 440, bottom: 60, zIndex: 6,
        padding: '11px 18px', borderRadius: 999,
        background: 'rgba(255,138,80,0.08)',
        border: '1px solid rgba(255,138,80,0.25)',
        boxShadow: '0 0 20px rgba(255,138,80,0.1)',
        color: '#FF8A50', fontSize: 17, fontWeight: 700,
        opacity: a(18), transform: `translateY(${(1 - a(18)) * 12}px)`,
      }}>🔥 {copy.streakChip}</div>

      <div style={{
        position: 'absolute', right: 420, bottom: 55, zIndex: 6,
        padding: '11px 18px', borderRadius: 999,
        background: 'rgba(255,209,102,0.08)',
        border: '1px solid rgba(255,209,102,0.25)',
        boxShadow: '0 0 20px rgba(255,209,102,0.1)',
        color: '#FFD166', fontSize: 17, fontWeight: 700,
        opacity: a(20), transform: `translateY(${(1 - a(20)) * 12}px)`,
      }}>☕ {copy.redeemChip}</div>
    </AbsoluteFill>
  );
};

export const EarthOnlinePoster: React.FC = () => <PosterComposition copy={posterCopyEn} />;
export const EarthOnlinePosterZh: React.FC = () => <PosterComposition copy={posterCopyZh} />;
