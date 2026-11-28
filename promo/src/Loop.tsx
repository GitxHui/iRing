import React from "react";
import { AbsoluteFill, Sequence, useCurrentFrame, useVideoConfig } from "remotion";
import { Desktop } from "./scenes/Desktop";
import { Lang } from "./lib/copy";
import { ramp } from "./lib/anim";

export type LoopProps = { lang: Lang; from: number; to: number; captions: boolean };
export const LOOP_XF = 0.5;

/** A slice of the desktop demo that cross-fades back into its own first frame. */
export const Loop: React.FC<LoopProps> = ({ lang, from, to, captions }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const len = to - from;
  const t = frame / fps;
  const k = ramp(t, len - LOOP_XF, len);
  return (
    <AbsoluteFill>
      <Desktop lang={lang} start={from} captions={captions} />
      {k > 0 ? (
        <AbsoluteFill style={{ opacity: k }}>
          <Sequence from={Math.round((len - LOOP_XF) * fps)}>
            <Desktop lang={lang} start={from - (len - LOOP_XF)} captions={captions} />
          </Sequence>
        </AbsoluteFill>
      ) : null}
    </AbsoluteFill>
  );
};

export const CLIPS = {
  Hero: { from: 0.25, to: 9.75, captions: true },
  Switch: { from: 0.35, to: 4.25, captions: false },
  Tile: { from: 4.2, to: 9.85, captions: false },
  Resize: { from: 9.85, to: 14.0, captions: false },
  Island: { from: 14.0, to: 18.35, captions: false },
} as const;
