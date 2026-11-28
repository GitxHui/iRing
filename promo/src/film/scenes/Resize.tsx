import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { COPY, FilmSceneProps, SCENES } from "../contract";
import { C, TitleBlock, exitAmt } from "../style";
import { FeatureStage, RZ, W_OFF, cuesFor, resizePct } from "../worlds/featureWorld";
import { clamp01, easeOut, ramp } from "../../lib/anim";
import { FONT } from "../../theme";

const LEN = SCENES.resize.len;

export const Resize: React.FC<FilmSceneProps> = ({ lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const w = W_OFF.resize + t;
  const c = COPY.resize[lang];
  const pctIn = clamp01(ramp(w, RZ.s1 - 0.3, RZ.s1, easeOut));
  const out = exitAmt(t, 3.55);
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      <FeatureStage w={w} />
      <TitleBlock t={t} at={0.15} lang={lang} eyebrow={c.eyebrow} title={c.title} sub={c.sub} x={130} y={170} exitAt={3.55} scale={0.9} />
      <div
        style={{
          position: "absolute",
          left: 130,
          top: 420,
          fontFamily: FONT,
          fontSize: 150,
          fontWeight: 600,
          letterSpacing: -4,
          color: C.ink,
          fontVariantNumeric: "tabular-nums",
          opacity: pctIn * (1 - out),
          filter: `blur(${(1 - pctIn) * 12 + out * 12}px)`,
        }}
      >
        {resizePct(w)}
        <span style={{ fontSize: 80, color: C.grey, marginLeft: 6 }}>%</span>
      </div>
    </AbsoluteFill>
  );
};

export const CUES = cuesFor(W_OFF.resize, LEN);
