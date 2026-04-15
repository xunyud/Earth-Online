import React from "react";
import {
  AbsoluteFill,
  Easing,
  Img,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

type CompetitionScene = {
  id: string;
  kind: "hero" | "split";
  align?: "left" | "right";
  kicker: string;
  title: string;
  body: string;
  caption: string;
  chips: [string, string, string];
  notes: [string, string, string];
  screenLabel: string;
  image: string;
  accent: string;
  durationInFrames: number;
};

type CompetitionVariant = "en" | "zh";

const fontStack =
  '"Segoe UI", "Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", sans-serif';

export const competitionFps = 30;
export const competitionWidth = 1920;
export const competitionHeight = 1080;

const competitionScenesEn: CompetitionScene[] = [
  {
    id: "intro",
    kind: "hero",
    kicker: "Earth Online",
    title: "A productivity game that remembers what just happened.",
    body:
      "Instead of treating every day like a blank slate, it keeps recent context alive before the next step.",
    caption: "Tasks become memory. Memory shapes the next step.",
    chips: ["Quest board", "Memory layer", "Guide"],
    notes: ["Real task in", "Recent context kept", "Steadier restart out"],
    screenLabel: "Live home",
    image: "competition/home.png",
    accent: "#3CD05B",
    durationInFrames: 180,
  },
  {
    id: "capture",
    kind: "split",
    align: "right",
    kicker: "1. Capture",
    title: "A rough task goes straight onto the board.",
    body:
      "The user starts from one real thing they want to finish today. No polished prompt required.",
    caption: "The loop starts from behavior, not abstraction.",
    chips: ["Task in", "Quest board", "XP feedback"],
    notes: ["Create the quest", "See it on the board", "Finish and earn progress"],
    screenLabel: "Quest board",
    image: "screens/board.png",
    accent: "#57C978",
    durationInFrames: 300,
  },
  {
    id: "memory",
    kind: "split",
    align: "left",
    kicker: "2. Remember",
    title: "Before the guide replies, it reads recent memory.",
    body:
      "Completed quests, logs, and behavior signals are pulled together as evidence before the assistant says anything new.",
    caption: "The response starts from context, not a generic script.",
    chips: ["Memory digest", "Recent rhythm", "Behavior signals"],
    notes: ["Recent completions", "Current rhythm", "Recovery cues"],
    screenLabel: "Guide remembers",
    image: "competition/guide-dialog.png",
    accent: "#76C66C",
    durationInFrames: 300,
  },
  {
    id: "event",
    kind: "split",
    align: "right",
    kicker: "3. Recommend",
    title: "The next task arrives with a reason.",
    body:
      "Daily events explain why the suggestion fits this moment, then send it back into the board with one tap.",
    caption: "A recommendation should explain itself.",
    chips: ["Why now", "Memory basis", "One-tap accept"],
    notes: ["Reason first", "Accept directly", "Reward feedback"],
    screenLabel: "Daily event",
    image: "screens/event.png",
    accent: "#F2C55C",
    durationInFrames: 300,
  },
  {
    id: "continuity",
    kind: "split",
    align: "left",
    kicker: "4. Continue",
    title: "Finished work does not disappear. It keeps the story moving.",
    body:
      "Guide replies, daily events, diary, and weekly summary all reuse the same recent context.",
    caption: "Memory keeps progress connected across days.",
    chips: ["Guide", "Diary", "Summary"],
    notes: ["Task completed", "Context stored", "Next step grounded"],
    screenLabel: "Completed quest",
    image: "competition/complete.png",
    accent: "#59CDA5",
    durationInFrames: 270,
  },
  {
    id: "outro",
    kind: "hero",
    kicker: "Start with context",
    title: "The next step should not start from zero.",
    body:
      "Earth Online turns planning into a steadier loop of task, memory, and forward motion.",
    caption: "Windows · Web · Android · Live demo available",
    chips: [
      "earth-online-wine.vercel.app",
      "Guide + Events",
      "Competition-ready",
    ],
    notes: ["Real product", "Grounded guidance", "Bilingual assets ready"],
    screenLabel: "Competition poster",
    image: "competition/poster-en.png",
    accent: "#3CD05B",
    durationInFrames: 240,
  },
];

const competitionScenesZh: CompetitionScene[] = [
  {
    id: "intro",
    kind: "hero",
    kicker: "Earth Online",
    title: "记得最近发生过什么的效率游戏",
    body: "它不会把每一天都当成重新开始，而是让最近的上下文继续参与下一步。",
    caption: "任务会变成记忆，记忆会影响下一步。",
    chips: ["任务板", "记忆层", "引导助手"],
    notes: ["先接住任务", "留下近期上下文", "再给下一步"],
    screenLabel: "实时首页",
    image: "competition/home.png",
    accent: "#3CD05B",
    durationInFrames: 180,
  },
  {
    id: "capture",
    kind: "split",
    align: "right",
    kicker: "1. 先接住",
    title: "一条随手记下的事，直接进入任务板。",
    body: "先接住真实任务，再决定怎么安排，不要求用户先把它说得很“标准”。",
    caption: "闭环从真实动作开始，不从抽象口号开始。",
    chips: ["输入任务", "任务板", "奖励反馈"],
    notes: ["创建任务", "落到任务板里", "完成后看到进展"],
    screenLabel: "任务板",
    image: "screens/board.png",
    accent: "#57C978",
    durationInFrames: 300,
  },
  {
    id: "memory",
    kind: "split",
    align: "left",
    kicker: "2. 先记住",
    title: "助手回答前，会先读最近的记忆。",
    body: "已完成任务、日志和行为信号会先整理成依据，再进入后续回复。",
    caption: "先有上下文，再有回应。",
    chips: ["记忆摘要", "近期节奏", "行为信号"],
    notes: ["最近完成了什么", "现在的节奏怎样", "是否需要恢复一下"],
    screenLabel: "助手记得",
    image: "competition/guide-dialog.png",
    accent: "#76C66C",
    durationInFrames: 300,
  },
  {
    id: "event",
    kind: "split",
    align: "right",
    kicker: "3. 再带回行动",
    title: "下一件事不是硬推，而是带着理由出现。",
    body: "每日事件会解释为什么此刻推荐这件事，并支持一键接回任务板。",
    caption: "推荐需要说清“为什么是现在”。",
    chips: ["为什么是现在", "记忆依据", "一键接回"],
    notes: ["先解释", "再接受", "同时给奖励反馈"],
    screenLabel: "每日事件",
    image: "screens/event.png",
    accent: "#F2C55C",
    durationInFrames: 300,
  },
  {
    id: "continuity",
    kind: "split",
    align: "left",
    kicker: "4. 保持连续",
    title: "做完不会消失，它会继续影响后面的体验。",
    body: "助手、每日事件、生活日记和周报都在复用同一层近期上下文。",
    caption: "记忆让跨天的推进保持连续。",
    chips: ["助手", "日记", "周报"],
    notes: ["完成动作", "沉淀上下文", "把下一步落稳"],
    screenLabel: "已完成任务",
    image: "competition/complete.png",
    accent: "#59CDA5",
    durationInFrames: 270,
  },
  {
    id: "outro",
    kind: "hero",
    kicker: "别从空白开始",
    title: "下一步，不该从空白开始。",
    body: "Earth Online 把任务、记忆和引导连成一个更稳的推进循环。",
    caption: "Windows · Web · Android · 在线 demo 可用",
    chips: ["earth-online-wine.vercel.app", "Guide + Events", "比赛可用"],
    notes: ["真实产品", "有依据的引导", "双语资产已就绪"],
    screenLabel: "比赛海报",
    image: "competition/poster-zh.png",
    accent: "#3CD05B",
    durationInFrames: 240,
  },
];

export const competitionDurationInFrames = competitionScenesEn.reduce(
  (sum, scene) => sum + scene.durationInFrames,
  0,
);

export const competitionDurationInFramesZh = competitionScenesZh.reduce(
  (sum, scene) => sum + scene.durationInFrames,
  0,
);

const appear = (frame: number, start: number, duration: number) =>
  interpolate(frame, [start, start + duration], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.bezier(0.2, 0.8, 0.2, 1),
  });

const rise = (frame: number, fps: number, start: number) => {
  if (frame < start) return 0;
  return spring({
    frame: frame - start,
    fps,
    config: { damping: 15, stiffness: 110 },
  });
};

const sceneOffset = (scenes: CompetitionScene[], id: string) => {
  let offset = 0;
  for (const scene of scenes) {
    if (scene.id === id) return offset;
    offset += scene.durationInFrames;
  }
  return 0;
};

const BrandBar: React.FC<{
  accent: string;
  variant: CompetitionVariant;
  index: number;
  total: number;
}> = ({ accent, variant, index, total }) => {
  return (
    <div
      style={{
        position: "absolute",
        left: 72,
        right: 72,
        top: 46,
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        zIndex: 10,
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 14,
          padding: "12px 18px",
          borderRadius: 999,
          background: "rgba(255,255,255,0.06)",
          border: `1px solid ${accent}28`,
          boxShadow: `0 18px 30px rgba(0,0,0,0.25), 0 0 20px ${accent}14`,
        }}
      >
        <div
          style={{
            width: 34,
            height: 34,
            borderRadius: 12,
            background: `linear-gradient(135deg, ${accent}, #1B7C39)`,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            color: "#F5FFF2",
            fontSize: 18,
            fontWeight: 900,
          }}
        >
          EO
        </div>
        <div
          style={{
            fontSize: 18,
            fontWeight: 800,
            color: "#F7FFF5",
            letterSpacing: 0.2,
          }}
        >
          Earth Online
        </div>
      </div>
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 14,
        }}
      >
        <div
          style={{
            fontSize: 15,
            color: "rgba(233,247,231,0.62)",
            fontWeight: 700,
            textTransform: "uppercase",
          }}
        >
          {variant === "en" ? "Competition Cut" : "比赛版本"}
        </div>
        <div
          style={{
            minWidth: 98,
            textAlign: "center",
            padding: "10px 14px",
            borderRadius: 999,
            background: "rgba(255,255,255,0.06)",
            border: "1px solid rgba(255,255,255,0.1)",
            color: "#F7FFF5",
            fontSize: 16,
            fontWeight: 800,
          }}
        >
          {String(index).padStart(2, "0")} / {String(total).padStart(2, "0")}
        </div>
      </div>
    </div>
  );
};

const CaptionBar: React.FC<{ text: string; accent: string }> = ({ text, accent }) => {
  return (
    <div
      style={{
        position: "absolute",
        left: 72,
        right: 72,
        bottom: 44,
        padding: "18px 22px",
        borderRadius: 28,
        background: "rgba(255,255,255,0.06)",
        border: "1px solid rgba(255,255,255,0.08)",
        boxShadow: "0 20px 46px rgba(0,0,0,0.28)",
        display: "flex",
        gap: 14,
        alignItems: "center",
        zIndex: 10,
      }}
    >
      <div
        style={{
          width: 14,
          height: 14,
          borderRadius: 999,
          background: accent,
          boxShadow: `0 0 14px ${accent}60`,
        }}
      />
      <div
        style={{
          fontSize: 26,
          lineHeight: 1.35,
          fontWeight: 600,
          color: "rgba(227,243,224,0.88)",
        }}
      >
        {text}
      </div>
    </div>
  );
};

const ScreenCard: React.FC<{
  accent: string;
  label: string;
  src: string;
  variant: "hero" | "split";
}> = ({ accent, label, src, variant }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = rise(frame, fps, 6);
  const zoom = interpolate(frame, [0, 180], [1.02, 1.08], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <div
      style={{
        position: "relative",
        width: variant === "hero" ? 1180 : 760,
        borderRadius: variant === "hero" ? 36 : 32,
        padding: 16,
        background: "rgba(255,255,255,0.05)",
        border: `1px solid ${accent}26`,
        boxShadow: `0 36px 120px rgba(0,0,0,0.34), 0 0 42px ${accent}12`,
        transform: `scale(${0.96 + pop * 0.04}) translateY(${(1 - pop) * 20}px)`,
      }}
    >
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          padding: "2px 4px 12px 4px",
        }}
      >
        <div
          style={{
            padding: "8px 14px",
            borderRadius: 999,
            background: `${accent}16`,
            border: `1px solid ${accent}28`,
            fontSize: 16,
            fontWeight: 800,
            color: accent,
          }}
        >
          {label}
        </div>
        <div
          style={{
            display: "flex",
            gap: 8,
          }}
        >
          {["#FF7B72", "#F2C55C", "#3CD05B"].map((color) => (
            <div
              key={color}
              style={{
                width: 10,
                height: 10,
                borderRadius: 999,
                background: color,
                opacity: 0.9,
              }}
            />
          ))}
        </div>
      </div>
      <div
        style={{
          overflow: "hidden",
          borderRadius: variant === "hero" ? 28 : 24,
          position: "relative",
          background: "#EBF1E5",
        }}
      >
        <Img
          src={staticFile(src)}
          style={{
            width: "100%",
            display: "block",
            transform: `scale(${zoom})`,
            transformOrigin: "center center",
          }}
        />
        <div
          style={{
            position: "absolute",
            inset: 0,
            background:
              variant === "hero"
                ? "linear-gradient(180deg, rgba(8,20,12,0.02) 0%, rgba(8,20,12,0.24) 100%)"
                : "linear-gradient(180deg, rgba(8,20,12,0.03) 0%, rgba(8,20,12,0.14) 100%)",
          }}
        />
      </div>
    </div>
  );
};

const TextBlock: React.FC<{ scene: CompetitionScene; align: "left" | "right" }> = ({
  scene,
  align,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const titleIn = rise(frame, fps, 2);
  const bodyIn = appear(frame, 10, 16);

  return (
    <div
      style={{
        width: 620,
        display: "flex",
        flexDirection: "column",
        gap: 22,
        transform: `translateY(${(1 - titleIn) * 18}px)`,
        alignItems: align === "left" ? "flex-start" : "flex-end",
        textAlign: align,
      }}
    >
      <div
        style={{
          padding: "12px 18px",
          borderRadius: 999,
          background: `${scene.accent}16`,
          border: `1px solid ${scene.accent}28`,
          color: scene.accent,
          fontSize: 20,
          fontWeight: 800,
        }}
      >
        {scene.kicker}
      </div>
      <div
        style={{
          fontSize: 68,
          lineHeight: 1.04,
          letterSpacing: -1.6,
          fontWeight: 900,
          color: "#F7FFF5",
          textShadow: `0 0 40px ${scene.accent}20`,
        }}
      >
        {scene.title}
      </div>
      <div
        style={{
          opacity: bodyIn,
          fontSize: 28,
          lineHeight: 1.55,
          color: "rgba(215,235,214,0.78)",
          maxWidth: 560,
        }}
      >
        {scene.body}
      </div>
      <div
        style={{
          display: "flex",
          gap: 10,
          flexWrap: "wrap",
          justifyContent: align === "left" ? "flex-start" : "flex-end",
          opacity: bodyIn,
        }}
      >
        {scene.chips.map((chip) => (
          <div
            key={chip}
            style={{
              padding: "10px 14px",
              borderRadius: 999,
              background: "rgba(255,255,255,0.06)",
              border: "1px solid rgba(255,255,255,0.09)",
              color: "#A4D4A1",
              fontSize: 17,
              fontWeight: 700,
            }}
          >
            {chip}
          </div>
        ))}
      </div>
    </div>
  );
};

const NotesStack: React.FC<{ scene: CompetitionScene }> = ({ scene }) => {
  const frame = useCurrentFrame();
  return (
    <div
      style={{
        display: "grid",
        gridTemplateColumns: "repeat(3, minmax(0, 1fr))",
        gap: 16,
        width: "100%",
      }}
    >
      {scene.notes.map((note, index) => {
        const alpha = appear(frame, 16 + index * 6, 12);
        return (
          <div
            key={note}
            style={{
              padding: "18px 18px 20px 18px",
              borderRadius: 22,
              background: "rgba(255,255,255,0.06)",
              border: `1px solid ${scene.accent}18`,
              boxShadow: "0 16px 34px rgba(0,0,0,0.18)",
              opacity: alpha,
              transform: `translateY(${(1 - alpha) * 14}px)`,
            }}
          >
            <div
              style={{
                fontSize: 14,
                fontWeight: 800,
                color: scene.accent,
                marginBottom: 10,
              }}
            >
              {String(index + 1).padStart(2, "0")}
            </div>
            <div
              style={{
                fontSize: 22,
                lineHeight: 1.35,
                fontWeight: 700,
                color: "#F4FFF2",
              }}
            >
              {note}
            </div>
          </div>
        );
      })}
    </div>
  );
};

const HeroSceneView: React.FC<{ scene: CompetitionScene; variant: CompetitionVariant }> = ({
  scene,
  variant,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const titleIn = rise(frame, fps, 0);
  const bodyIn = appear(frame, 10, 16);

  return (
    <AbsoluteFill
      style={{
        fontFamily: fontStack,
        color: "#F7FFF5",
        background: "#09160E",
      }}
    >
      <div
        style={{
          position: "absolute",
          inset: 0,
          background:
            "radial-gradient(circle at 22% 18%, rgba(60,208,91,0.18), transparent 40%), radial-gradient(circle at 78% 82%, rgba(242,197,92,0.12), transparent 34%), linear-gradient(180deg, #102116 0%, #09160E 100%)",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: 180,
          right: 180,
          top: 180,
          display: "flex",
          justifyContent: "center",
          opacity: bodyIn,
        }}
      >
        <ScreenCard
          accent={scene.accent}
          label={scene.screenLabel}
          src={scene.image}
          variant="hero"
        />
      </div>
      <div
        style={{
          position: "absolute",
          left: 92,
          top: 168,
          width: 720,
          display: "flex",
          flexDirection: "column",
          gap: 22,
          zIndex: 11,
          transform: `translateY(${(1 - titleIn) * 16}px)`,
        }}
      >
        <div
          style={{
            alignSelf: "flex-start",
            padding: "12px 18px",
            borderRadius: 999,
            background: `${scene.accent}16`,
            border: `1px solid ${scene.accent}28`,
            color: scene.accent,
            fontSize: 20,
            fontWeight: 800,
          }}
        >
          {scene.kicker}
        </div>
        <div
          style={{
            fontSize: variant === "zh" ? 66 : 74,
            lineHeight: 1.02,
            letterSpacing: variant === "zh" ? -0.8 : -1.8,
            fontWeight: 900,
            maxWidth: 760,
            textShadow: `0 0 40px ${scene.accent}24`,
          }}
        >
          {scene.title}
        </div>
        <div
          style={{
            fontSize: 28,
            lineHeight: 1.55,
            color: "rgba(220,239,218,0.82)",
            maxWidth: 620,
          }}
        >
          {scene.body}
        </div>
        <div
          style={{
            display: "flex",
            gap: 10,
            flexWrap: "wrap",
          }}
        >
          {scene.chips.map((chip) => (
            <div
              key={chip}
              style={{
                padding: "10px 14px",
                borderRadius: 999,
                background: "rgba(255,255,255,0.06)",
                border: "1px solid rgba(255,255,255,0.1)",
                color: "#A4D4A1",
                fontSize: 17,
                fontWeight: 700,
              }}
            >
              {chip}
            </div>
          ))}
        </div>
      </div>
      <div
        style={{
          position: "absolute",
          left: 92,
          right: 92,
          top: 740,
          zIndex: 11,
        }}
      >
        <NotesStack scene={scene} />
      </div>
      <BrandBar
        accent={scene.accent}
        variant={variant}
        index={competitionScenesEn.findIndex((item) => item.id === scene.id) + 1}
        total={competitionScenesEn.length}
      />
      <CaptionBar text={scene.caption} accent={scene.accent} />
    </AbsoluteFill>
  );
};

const SplitSceneView: React.FC<{ scene: CompetitionScene; variant: CompetitionVariant }> = ({
  scene,
  variant,
}) => {
  const frame = useCurrentFrame();
  const float = Math.sin(frame / 24) * 10;
  const align = scene.align ?? "left";
  const reverse = align === "right";

  return (
    <AbsoluteFill
      style={{
        fontFamily: fontStack,
        color: "#F7FFF5",
        background: "#09160E",
      }}
    >
      <div
        style={{
          position: "absolute",
          inset: 0,
          background:
            "radial-gradient(circle at 18% 22%, rgba(60,208,91,0.12), transparent 38%), radial-gradient(circle at 82% 76%, rgba(242,197,92,0.1), transparent 30%), linear-gradient(180deg, #102116 0%, #09160E 100%)",
        }}
      />
      <div
        style={{
          position: "absolute",
          top: 170,
          left: 92,
          right: 92,
          bottom: 150,
          display: "flex",
          gap: 56,
          alignItems: "center",
          flexDirection: reverse ? "row-reverse" : "row",
        }}
      >
        <TextBlock scene={scene} align={reverse ? "right" : "left"} />
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            gap: 18,
            width: 760,
            transform: `translateY(${float}px)`,
          }}
        >
          <ScreenCard
            accent={scene.accent}
            label={scene.screenLabel}
            src={scene.image}
            variant="split"
          />
          <NotesStack scene={scene} />
        </div>
      </div>
      <BrandBar
        accent={scene.accent}
        variant={variant}
        index={competitionScenesEn.findIndex((item) => item.id === scene.id) + 1}
        total={competitionScenesEn.length}
      />
      <CaptionBar text={scene.caption} accent={scene.accent} />
    </AbsoluteFill>
  );
};

const CompetitionSceneView: React.FC<{
  scene: CompetitionScene;
  variant: CompetitionVariant;
}> = ({ scene, variant }) => {
  if (scene.kind === "hero") {
    return <HeroSceneView scene={scene} variant={variant} />;
  }
  return <SplitSceneView scene={scene} variant={variant} />;
};

const CompetitionComposition: React.FC<{
  scenes: CompetitionScene[];
  variant: CompetitionVariant;
}> = ({ scenes, variant }) => {
  return (
    <AbsoluteFill style={{ background: "#09160E" }}>
      {scenes.map((scene) => (
        <Sequence
          key={scene.id}
          from={sceneOffset(scenes, scene.id)}
          durationInFrames={scene.durationInFrames}
          premountFor={20}
        >
          <CompetitionSceneView scene={scene} variant={variant} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};

export const EarthOnlineCompetition: React.FC = () => {
  return <CompetitionComposition scenes={competitionScenesEn} variant="en" />;
};

export const EarthOnlineCompetitionZh: React.FC = () => {
  return <CompetitionComposition scenes={competitionScenesZh} variant="zh" />;
};
