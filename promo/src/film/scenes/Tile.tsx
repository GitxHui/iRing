import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { COPY, FilmSceneProps, SCENES } from "../contract";
import { C, RevealLine, TitleBlock, exitAmt } from "../style";
import { FeatureStage, W_OFF, cuesFor } from "../worlds/featureWorld";
import { clamp01, easeOut, ramp, track } from "../../lib/anim";
import { FONT } from "../../theme";

const LEN = SCENES.tile.len;
// local times where the mode changes (halves -> quarters -> full)
const MODE_AT = [0.25, 2.6, 4.65];

const Modes: React.FC<{ t: number; lang: "zh" | "en"; x: number; y: number }> = ({ t, lang, x, y }) => {
  const labels = COPY.tile[lang].modes;
  const active = t < MODE_AT[1] ? 0 : t < MODE_AT[2] ? 1 : 2;
  const w = lang === "zh" ? 150 : 205;
  const gap = 40;
  const pos = track(t, [[0, 0], [MODE_AT[1], 1], [MODE_AT[2], 2]], { response: 0.45, damping: 0.86 });
  const vis = clamp01(ramp(t, 0.55, 0.95, easeOut));
  return (
    <div style={{ position: "absolute", left: x, top: y, display: "flex", gap, paddingBottom: 16, opacity: vis, fontFamily: FONT }}>
      {labels.map((l, i) => (
        <div key={l} style={{ width: w, fontSize: 36, fontWeight: i === active ? 600 : 400, color: i === active ? C.ink : C.greyDim }}>
          {l}
        </div>
      ))}
      <div
        style={{
          position: "absolute",
          left: pos * (w + gap),
          bottom: 0,
          width: lang === "zh" ? 108 : 150,
          height: 3,
          borderRadius: 2,
          background: C.blue,
          boxShadow: `0 0 14px ${C.blue}`,
        }}
      />
    </div>
  );
};

export const Tile: React.FC<FilmSceneProps> = ({ lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const c = COPY.tile[lang];
  const X = 1170;
  const out = exitAmt(t, LEN - 0.45);
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      <FeatureStage w={W_OFF.tile + t} />
      <TitleBlock t={t} at={0.2} lang={lang} eyebrow={c.eyebrow} title={c.title} sub={c.sub} x={X} y={190} exitAt={LEN - 0.45} scale={lang === "zh" ? 0.8 : 0.72} />
      <div style={{ opacity: 1 - out, filter: `blur(${out * 10}px)` }}>
        <Modes t={t} lang={lang} x={X} y={440} />
        <RevealLine text={c.note} t={t} at={1.1} lang={lang} color={C.grey} style={{ position: "absolute", left: X, top: 520, fontSize: 30, fontWeight: 400 }} />
      </div>
    </AbsoluteFill>
  );
};

export const CUES = cuesFor(W_OFF.tile, LEN);
