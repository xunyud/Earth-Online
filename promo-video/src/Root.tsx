import {Composition} from 'remotion';
import {EarthOnlinePromo, EarthOnlinePromoZh} from './EarthOnlinePromo';
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
    </>
  );
};
