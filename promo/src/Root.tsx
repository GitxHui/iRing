import React from "react";
import { Composition, Still } from "remotion";
import { Promo, PromoProps } from "./Promo";
import { PROMO_FRAMES } from "./timeline";
import { Loop, CLIPS, LoopProps } from "./Loop";
import { VideoPoster } from "./VideoPoster";
import { VerticalPromo } from "./vertical/VerticalPromo";
import { VFPS, VH, VTOTAL, VW } from "./vertical/contract";
import { Desktop } from "./scenes/Desktop";
import { FPS, H, W } from "./theme";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="Vertical-ZH"
        component={VerticalPromo}
        durationInFrames={Math.round(VTOTAL * VFPS)}
        fps={VFPS}
        width={VW}
        height={VH}
        defaultProps={{ lang: "zh" as const, audio: true }}
      />
      <Composition
        id="Vertical-EN"
        component={VerticalPromo}
        durationInFrames={Math.round(VTOTAL * VFPS)}
        fps={VFPS}
        width={VW}
        height={VH}
        defaultProps={{ lang: "en" as const, audio: true }}
      />
      <Composition
        id="Promo-EN"
        component={Promo}
        durationInFrames={PROMO_FRAMES}
        fps={FPS}
        width={W}
        height={H}
        defaultProps={{ lang: "en", audio: true } satisfies PromoProps}
      />
      <Composition
        id="Promo-ZH"
        component={Promo}
        durationInFrames={PROMO_FRAMES}
        fps={FPS}
        width={W}
        height={H}
        defaultProps={{ lang: "zh", audio: true } satisfies PromoProps}
      />
      {(["EN", "ZH"] as const).map((L) =>
        Object.entries(CLIPS).map(([name, c]) => (
          <Composition
            key={`${name}-${L}`}
            id={`${name}-${L}`}
            component={Loop}
            durationInFrames={Math.round((c.to - c.from) * 30)}
            fps={30}
            width={W}
            height={H}
            defaultProps={{ lang: L === "EN" ? "en" : "zh", from: c.from, to: c.to, captions: c.captions } satisfies LoopProps}
          />
        )),
      )}
      <Composition id="VideoPoster-EN" component={VideoPoster} durationInFrames={1} fps={60} width={W} height={H} defaultProps={{ lang: "en" as const }} />
      <Composition id="VideoPoster-ZH" component={VideoPoster} durationInFrames={1} fps={60} width={W} height={H} defaultProps={{ lang: "zh" as const }} />
      <Still id="Poster-EN" component={Desktop} width={W} height={H} defaultProps={{ lang: "en" as const, start: 2.6 }} />
      <Still id="Poster-ZH" component={Desktop} width={W} height={H} defaultProps={{ lang: "zh" as const, start: 2.6 }} />
    </>
  );
};
