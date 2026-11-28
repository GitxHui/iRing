import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { COPY, FilmSceneProps, SCENES } from "../contract";
import { TitleBlock } from "../style";
import { FeatureStage, W_OFF, cuesFor } from "../worlds/featureWorld";

const LEN = SCENES.switch.len;

export const Switch: React.FC<FilmSceneProps> = ({ lang }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const c = COPY.switch[lang];
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      <FeatureStage w={W_OFF.switch + t} />
      <TitleBlock t={t} at={1.05} lang={lang} eyebrow={c.eyebrow} title={c.title} sub={c.sub} x={130} y={330} exitAt={LEN - 0.45} />
    </AbsoluteFill>
  );
};

export const CUES = cuesFor(W_OFF.switch, LEN);
