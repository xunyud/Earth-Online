import React from 'react';
import {
  AbsoluteFill,
  Audio,
  Easing,
  OffthreadVideo,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {evermemosScenes, type EverMemOSScene} from './evermemos-scenes';

const fontStack =
  '"Aptos", "Segoe UI", "Microsoft YaHei UI", "Microsoft YaHei", sans-serif';

const appear = (frame: number, start: number, duration: number) =>
  interpolate(frame, [start, start + duration], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.bezier(0.2, 0.8, 0.2, 1),
  });

const rise = (frame: number, fps: number, start: number) => {
  if (frame < start) {
    return 0;
  }

  return spring({
    frame: frame - start,
    fps,
    config: {damping: 18, stiffness: 120},
  });
};

const sceneOffset = (id: string) => {
  let offset = 0;

  for (const scene of evermemosScenes) {
    if (scene.id === id) {
      return offset;
    }

    offset += scene.durationInFrames;
  }

  return 0;
};

const TopBar: React.FC<{accent: string; index: number; total: number}> = ({
  accent,
  index,
  total,
}) => {
  return (
    <div
      style={{
        position: 'absolute',
        left: 72,
        right: 72,
        top: 42,
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        zIndex: 20,
      }}
    >
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 14,
          padding: '12px 18px',
          borderRadius: 999,
          background: 'rgba(7, 18, 14, 0.62)',
          border: `1px solid ${accent}3d`,
          boxShadow: `0 20px 40px rgba(0,0,0,0.22), 0 0 24px ${accent}12`,
        }}
      >
        <div
          style={{
            width: 34,
            height: 34,
            borderRadius: 12,
            background: `linear-gradient(135deg, ${accent}, #103B25)`,
            color: '#F6FFF7',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: 16,
            fontWeight: 900,
          }}
        >
          EM
        </div>
        <div
          style={{
            color: '#F6FFF7',
            fontSize: 18,
            fontWeight: 800,
            letterSpacing: 0.3,
          }}
        >
          EverMemOS Demo
        </div>
      </div>

      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 14,
        }}
      >
        <div
          style={{
            color: 'rgba(232,245,235,0.66)',
            fontSize: 15,
            fontWeight: 700,
            textTransform: 'uppercase',
            letterSpacing: 0.8,
          }}
        >
          Memory-native companion
        </div>
        <div
          style={{
            minWidth: 112,
            textAlign: 'center',
            padding: '10px 14px',
            borderRadius: 999,
            background: 'rgba(255,255,255,0.06)',
            border: '1px solid rgba(255,255,255,0.12)',
            color: '#F6FFF7',
            fontSize: 16,
            fontWeight: 800,
          }}
        >
          {String(index).padStart(2, '0')} / {String(total).padStart(2, '0')}
        </div>
      </div>
    </div>
  );
};

const SubtitleBar: React.FC<{accent: string; text: string}> = ({accent, text}) => {
  return (
    <div
      style={{
        position: 'absolute',
        left: 72,
        right: 72,
        bottom: 42,
        padding: '18px 22px',
        borderRadius: 28,
        background: 'rgba(8, 16, 13, 0.74)',
        border: '1px solid rgba(255,255,255,0.08)',
        boxShadow: '0 20px 50px rgba(0,0,0,0.26)',
        display: 'flex',
        gap: 14,
        alignItems: 'center',
        zIndex: 20,
      }}
    >
      <div
        style={{
          width: 12,
          height: 12,
          borderRadius: 999,
          background: accent,
          boxShadow: `0 0 16px ${accent}66`,
          flexShrink: 0,
        }}
      />
      <div
        style={{
          color: '#F6FFF7',
          fontSize: 25,
          lineHeight: 1.38,
          fontWeight: 650,
        }}
      >
        {text}
      </div>
    </div>
  );
};

const AudioTrack: React.FC<{id: string}> = ({id}) => {
  return (
    <Audio
      src={staticFile(`audio-evermemos/${id}.wav`)}
      volume={0.92}
    />
  );
};

const VideoBackdrop: React.FC<{
  scene: EverMemOSScene;
  fullBleed?: boolean;
}> = ({scene, fullBleed}) => {
  const frame = useCurrentFrame();
  const zoom = interpolate(frame, [0, scene.durationInFrames], [1.015, 1.08], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const drift = interpolate(frame, [0, scene.durationInFrames], [0, -24], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        overflow: 'hidden',
        borderRadius: fullBleed ? 0 : 34,
        background: '#0B1A12',
      }}
    >
      <OffthreadVideo
        muted
        src={staticFile(scene.clipSrc ?? '')}
        trimBefore={scene.trimBefore}
        trimAfter={scene.trimAfter}
        playbackRate={scene.playbackRate ?? 1}
        style={{
          width: '100%',
          height: '100%',
          objectFit: 'cover',
          transform: `scale(${zoom}) translateY(${drift}px)`,
          transformOrigin: 'center center',
        }}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: fullBleed
            ? 'linear-gradient(180deg, rgba(4,10,8,0.32) 0%, rgba(4,10,8,0.72) 100%)'
            : 'linear-gradient(180deg, rgba(4,10,8,0.06) 0%, rgba(4,10,8,0.26) 100%)',
        }}
      />
    </div>
  );
};

const BrowserFrame: React.FC<{scene: EverMemOSScene}> = ({scene}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const pop = rise(frame, fps, 2);

  return (
    <div
      style={{
        position: 'relative',
        width: 1180,
        height: 664,
        padding: 16,
        borderRadius: 38,
        background: 'rgba(255,255,255,0.06)',
        border: `1px solid ${scene.accent}34`,
        boxShadow: `0 40px 120px rgba(0,0,0,0.35), 0 0 36px ${scene.accent}14`,
        transform: `scale(${0.96 + pop * 0.04}) translateY(${(1 - pop) * 20}px)`,
      }}
    >
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          padding: '2px 4px 14px 4px',
        }}
      >
        <div
          style={{
            padding: '8px 14px',
            borderRadius: 999,
            background: `${scene.accent}16`,
            border: `1px solid ${scene.accent}2a`,
            color: scene.accent,
            fontSize: 15,
            fontWeight: 800,
          }}
        >
          Real product footage
        </div>
        <div
          style={{
            display: 'flex',
            gap: 8,
          }}
        >
          {['#FF7B72', '#FFD36C', '#52D98C'].map((color) => (
            <div
              key={color}
              style={{
                width: 10,
                height: 10,
                borderRadius: 999,
                background: color,
              }}
            />
          ))}
        </div>
      </div>

      <div
        style={{
          position: 'relative',
          overflow: 'hidden',
          borderRadius: 28,
          width: '100%',
          height: '100%',
        }}
      >
        <VideoBackdrop scene={scene} />
      </div>
    </div>
  );
};

const SidePanel: React.FC<{scene: EverMemOSScene}> = ({scene}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const titleIn = rise(frame, fps, 0);
  const bodyIn = appear(frame, 10, 18);

  return (
    <div
      style={{
        width: 470,
        display: 'flex',
        flexDirection: 'column',
        gap: 18,
        transform: `translateY(${(1 - titleIn) * 20}px)`,
      }}
    >
      <div
        style={{
          alignSelf: 'flex-start',
          padding: '12px 18px',
          borderRadius: 999,
          background: `${scene.accent}16`,
          border: `1px solid ${scene.accent}28`,
          color: scene.accent,
          fontSize: 18,
          fontWeight: 800,
        }}
      >
        {scene.kicker}
      </div>

      <div
        style={{
          color: '#F7FFF6',
          fontSize: 56,
          lineHeight: 1.04,
          letterSpacing: -1.4,
          fontWeight: 900,
          textShadow: `0 0 24px ${scene.accent}1A`,
        }}
      >
        {scene.title}
      </div>

      <div
        style={{
          opacity: bodyIn,
          color: 'rgba(221,235,225,0.82)',
          fontSize: 24,
          lineHeight: 1.6,
        }}
      >
        {scene.body}
      </div>

      <div
        style={{
          padding: '18px 20px',
          borderRadius: 26,
          background: 'rgba(255,255,255,0.06)',
          border: '1px solid rgba(255,255,255,0.08)',
          boxShadow: '0 20px 50px rgba(0,0,0,0.16)',
          opacity: bodyIn,
        }}
      >
        <div
          style={{
            color: scene.accent,
            fontSize: 14,
            fontWeight: 900,
            letterSpacing: 0.9,
            textTransform: 'uppercase',
            marginBottom: 10,
          }}
        >
          What this proves
        </div>
        <div
          style={{
            color: '#F7FFF6',
            fontSize: 22,
            lineHeight: 1.5,
            fontWeight: 650,
          }}
        >
          {scene.proof}
        </div>
      </div>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '1fr',
          gap: 12,
        }}
      >
        {scene.notes.map((note, index) => {
          const alpha = appear(frame, 18 + index * 7, 12);

          return (
            <div
              key={note}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 14,
                padding: '14px 16px',
                borderRadius: 22,
                background: 'rgba(255,255,255,0.05)',
                border: `1px solid ${scene.accent}16`,
                opacity: alpha,
                transform: `translateY(${(1 - alpha) * 12}px)`,
              }}
            >
              <div
                style={{
                  width: 10,
                  height: 10,
                  borderRadius: 999,
                  background: scene.accent,
                  flexShrink: 0,
                  boxShadow: `0 0 12px ${scene.accent}66`,
                }}
              />
              <div
                style={{
                  color: '#E7F3E9',
                  fontSize: 18,
                  lineHeight: 1.45,
                  fontWeight: 600,
                }}
              >
                {note}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

const OpenerCards: React.FC<{scene: EverMemOSScene}> = ({scene}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const titleIn = rise(frame, fps, 0);

  const phrases = [
    'Too many tasks',
    'Too many reminders',
    'Too much to hold alone',
  ];

  return (
    <div
      style={{
        position: 'absolute',
        right: 110,
        top: 210,
        width: 490,
        display: 'flex',
        flexDirection: 'column',
        gap: 18,
        zIndex: 12,
      }}
    >
      {phrases.map((phrase, index) => {
        const alpha = appear(frame, 14 + index * 8, 14);
        const bob = Math.sin(frame / 18 + index) * 8;

        return (
          <div
            key={phrase}
            style={{
              padding: '20px 22px',
              borderRadius: 28,
              background: 'rgba(12, 20, 17, 0.72)',
              border: `1px solid ${scene.accent}24`,
              boxShadow: '0 20px 60px rgba(0,0,0,0.26)',
              opacity: alpha,
              transform: `translateY(${(1 - alpha) * 22 + bob}px)`,
            }}
          >
            <div
              style={{
                color: scene.accent,
                fontSize: 14,
                fontWeight: 900,
                letterSpacing: 0.9,
                textTransform: 'uppercase',
                marginBottom: 8,
              }}
            >
              Pressure signal
            </div>
            <div
              style={{
                color: '#F6FFF7',
                fontSize: 28,
                lineHeight: 1.25,
                fontWeight: 800,
              }}
            >
              {phrase}
            </div>
          </div>
        );
      })}

      <div
        style={{
          marginTop: 10,
          transform: `translateY(${(1 - titleIn) * 20}px)`,
        }}
      >
        <div
          style={{
            color: 'rgba(221,235,225,0.78)',
            fontSize: 18,
            lineHeight: 1.6,
            paddingLeft: 4,
          }}
        >
          The product is introduced as relief from mental overhead, not as another dashboard.
        </div>
      </div>
    </div>
  );
};

const OpenerScene: React.FC<{scene: EverMemOSScene; index: number}> = ({
  scene,
  index,
}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const titleIn = rise(frame, fps, 2);
  const bodyIn = appear(frame, 12, 18);

  return (
    <AbsoluteFill
      style={{
        background: '#07110D',
        color: '#F6FFF7',
        fontFamily: fontStack,
      }}
    >
      <VideoBackdrop scene={scene} fullBleed />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background:
            'radial-gradient(circle at 18% 26%, rgba(255,138,91,0.22), transparent 36%), linear-gradient(90deg, rgba(5,12,9,0.9) 0%, rgba(5,12,9,0.58) 44%, rgba(5,12,9,0.78) 100%)',
        }}
      />

      <TopBar accent={scene.accent} index={index + 1} total={evermemosScenes.length} />
      <AudioTrack id={scene.id} />

      <div
        style={{
          position: 'absolute',
          left: 92,
          top: 178,
          width: 760,
          display: 'flex',
          flexDirection: 'column',
          gap: 22,
          zIndex: 12,
          transform: `translateY(${(1 - titleIn) * 18}px)`,
        }}
      >
        <div
          style={{
            alignSelf: 'flex-start',
            padding: '12px 18px',
            borderRadius: 999,
            background: `${scene.accent}16`,
            border: `1px solid ${scene.accent}28`,
            color: scene.accent,
            fontSize: 18,
            fontWeight: 800,
          }}
        >
          {scene.kicker}
        </div>
        <div
          style={{
            fontSize: 76,
            lineHeight: 1.03,
            letterSpacing: -2,
            fontWeight: 900,
            maxWidth: 760,
          }}
        >
          {scene.title}
        </div>
        <div
          style={{
            opacity: bodyIn,
            color: 'rgba(224,236,227,0.82)',
            fontSize: 28,
            lineHeight: 1.58,
            maxWidth: 640,
          }}
        >
          {scene.body}
        </div>
      </div>

      <OpenerCards scene={scene} />
      <SubtitleBar accent={scene.accent} text={scene.subtitle} />
    </AbsoluteFill>
  );
};

const VideoScene: React.FC<{scene: EverMemOSScene; index: number}> = ({
  scene,
  index,
}) => {
  return (
    <AbsoluteFill
      style={{
        background: '#08130F',
        color: '#F6FFF7',
        fontFamily: fontStack,
      }}
    >
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background:
            'radial-gradient(circle at 20% 20%, rgba(82,217,140,0.12), transparent 32%), radial-gradient(circle at 78% 80%, rgba(255,211,108,0.12), transparent 34%), linear-gradient(180deg, #0E1D15 0%, #08130F 100%)',
        }}
      />

      <TopBar accent={scene.accent} index={index + 1} total={evermemosScenes.length} />
      <AudioTrack id={scene.id} />

      <div
        style={{
          position: 'absolute',
          top: 158,
          left: 72,
          right: 72,
          bottom: 142,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 52,
        }}
      >
        <BrowserFrame scene={scene} />
        <SidePanel scene={scene} />
      </div>

      <SubtitleBar accent={scene.accent} text={scene.subtitle} />
    </AbsoluteFill>
  );
};

const ClosingScene: React.FC<{scene: EverMemOSScene; index: number}> = ({
  scene,
  index,
}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const titleIn = rise(frame, fps, 2);
  const bodyIn = appear(frame, 12, 18);
  const glow = interpolate(frame, [0, scene.durationInFrames], [0.22, 0.5], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill
      style={{
        background: '#06100C',
        color: '#F6FFF7',
        fontFamily: fontStack,
      }}
    >
      <VideoBackdrop scene={scene} fullBleed />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background:
            'linear-gradient(180deg, rgba(5,12,9,0.34) 0%, rgba(5,12,9,0.82) 100%)',
        }}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: `radial-gradient(circle at 50% 34%, rgba(141,242,175,${glow}), transparent 34%)`,
        }}
      />

      <TopBar accent={scene.accent} index={index + 1} total={evermemosScenes.length} />
      <AudioTrack id={scene.id} />

      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 12,
        }}
      >
        <div
          style={{
            width: 1180,
            padding: '42px 48px',
            borderRadius: 36,
            background: 'rgba(9, 18, 14, 0.6)',
            border: `1px solid ${scene.accent}28`,
            boxShadow: '0 30px 120px rgba(0,0,0,0.32)',
            textAlign: 'center',
            transform: `translateY(${(1 - titleIn) * 18}px)`,
          }}
        >
          <div
            style={{
              color: scene.accent,
              fontSize: 18,
              fontWeight: 900,
              letterSpacing: 1.1,
              textTransform: 'uppercase',
              marginBottom: 14,
            }}
          >
            {scene.kicker}
          </div>
          <div
            style={{
              fontSize: 68,
              lineHeight: 1.08,
              letterSpacing: -1.6,
              fontWeight: 900,
              marginBottom: 18,
            }}
          >
            {scene.title}
          </div>
          <div
            style={{
              opacity: bodyIn,
              color: 'rgba(226,237,229,0.82)',
              fontSize: 30,
              lineHeight: 1.5,
              fontWeight: 600,
            }}
          >
            {scene.body}
          </div>
        </div>
      </div>

      <SubtitleBar accent={scene.accent} text={scene.subtitle} />
    </AbsoluteFill>
  );
};

const SceneView: React.FC<{scene: EverMemOSScene; index: number}> = ({
  scene,
  index,
}) => {
  if (scene.kind === 'opener') {
    return <OpenerScene scene={scene} index={index} />;
  }

  if (scene.kind === 'closing') {
    return <ClosingScene scene={scene} index={index} />;
  }

  return <VideoScene scene={scene} index={index} />;
};

export const EverMemOSDemo: React.FC = () => {
  return (
    <AbsoluteFill style={{background: '#08130F'}}>
      {evermemosScenes.map((scene, index) => (
        <Sequence
          key={scene.id}
          from={sceneOffset(scene.id)}
          durationInFrames={scene.durationInFrames}
          premountFor={20}
        >
          <SceneView scene={scene} index={index} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};
