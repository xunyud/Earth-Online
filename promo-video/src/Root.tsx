import {Composition} from 'remotion';
import {
  EarthOnlineCompetition,
  EarthOnlineCompetitionZh,
  competitionDurationInFrames,
  competitionDurationInFramesZh,
  competitionFps,
  competitionHeight,
  competitionWidth,
} from './EarthOnlineCompetition';
import {
  EarthOnlinePromo,
  EarthOnlinePromoZh,
  EarthOnlinePoster,
  EarthOnlinePosterZh,
} from './EarthOnlinePromo';
import {
  EverMemOSDemo,
} from './EverMemOSDemo';
import {
  evermemosFps,
  evermemosHeight,
  evermemosTotalDurationInFrames,
  evermemosWidth,
} from './evermemos-scenes';
import {fps, height, totalDurationInFrames, width} from './scenes';
import {totalDurationInFramesZh} from './scenes.zh';

export const RemotionRoot = () => {
  return (
    <>
      <Composition
        id="EarthOnlinePromo"
        component={EarthOnlinePromo}
        durationInFrames={totalDurationInFrames}
        fps={fps}
        width={width}
        height={height}
      />
      <Composition
        id="EarthOnlinePromoZh"
        component={EarthOnlinePromoZh}
        durationInFrames={totalDurationInFramesZh}
        fps={fps}
        width={width}
        height={height}
      />
      <Composition
        id="EarthOnlinePoster"
        component={EarthOnlinePoster}
        durationInFrames={60}
        fps={fps}
        width={width}
        height={height}
      />
      <Composition
        id="EarthOnlinePosterZh"
        component={EarthOnlinePosterZh}
        durationInFrames={60}
        fps={fps}
        width={width}
        height={height}
      />
      <Composition
        id="EarthOnlineCompetition"
        component={EarthOnlineCompetition}
        durationInFrames={competitionDurationInFrames}
        fps={competitionFps}
        width={competitionWidth}
        height={competitionHeight}
      />
      <Composition
        id="EarthOnlineCompetitionZh"
        component={EarthOnlineCompetitionZh}
        durationInFrames={competitionDurationInFramesZh}
        fps={competitionFps}
        width={competitionWidth}
        height={competitionHeight}
      />
      <Composition
        id="EverMemOSDemo"
        component={EverMemOSDemo}
        durationInFrames={evermemosTotalDurationInFrames}
        fps={evermemosFps}
        width={evermemosWidth}
        height={evermemosHeight}
      />
    </>
  );
};
