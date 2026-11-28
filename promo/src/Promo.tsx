import React from "react";
import { AbsoluteFill } from "remotion";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { Hook, HOOK_LEN } from "./scenes/Hook";
import { Reveal, REVEAL_LEN } from "./scenes/Reveal";
import { Desktop, DESKTOP_LEN } from "./scenes/Desktop";
import { Bento, BENTO_LEN } from "./scenes/Bento";
import { Outro, OUTRO_LEN } from "./scenes/Outro";
import { Lang } from "./lib/copy";
import { FPS } from "./theme";
import { Soundtrack } from "./Soundtrack";
import { XFADE } from "./timeline";

const f = (s: number) => Math.round(s * FPS);

export type PromoProps = { lang: Lang; audio: boolean };

export const Promo: React.FC<PromoProps> = ({ lang, audio }) => {
  const x = linearTiming({ durationInFrames: f(XFADE) });
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      <TransitionSeries>
        <TransitionSeries.Sequence durationInFrames={f(HOOK_LEN)}>
          <Hook lang={lang} />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={fade()} timing={x} />
        <TransitionSeries.Sequence durationInFrames={f(REVEAL_LEN)}>
          <Reveal lang={lang} />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={fade()} timing={x} />
        <TransitionSeries.Sequence durationInFrames={f(DESKTOP_LEN)}>
          <Desktop lang={lang} />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={fade()} timing={x} />
        <TransitionSeries.Sequence durationInFrames={f(BENTO_LEN)}>
          <Bento lang={lang} />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition presentation={fade()} timing={x} />
        <TransitionSeries.Sequence durationInFrames={f(OUTRO_LEN)}>
          <Outro lang={lang} />
        </TransitionSeries.Sequence>
      </TransitionSeries>
      {audio ? <Soundtrack /> : null}
    </AbsoluteFill>
  );
};
