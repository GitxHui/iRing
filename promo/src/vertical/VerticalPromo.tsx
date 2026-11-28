import React from "react";
import { AbsoluteFill, Sequence, staticFile, useVideoConfig } from "remotion";
import { Audio } from "@remotion/media";
import { KEY, SceneCue, VSCENES, VSceneProps } from "./contract";
import { MUSIC_VERTICAL, sfxSrc } from "./audio";
import { VHook, CUES as HOOK } from "./scenes/VHook";
import { VKey, CUES as KEYC } from "./scenes/VKey";
import { VEquation, CUES as EQ } from "./scenes/VEquation";
import { VSwitch, CUES as SW } from "./scenes/VSwitch";
import { VTile, CUES as TI } from "./scenes/VTile";
import { VResize, CUES as RS } from "./scenes/VResize";
import { VIsland, CUES as IS } from "./scenes/VIsland";
import { VFinale, CUES as FI } from "./scenes/VFinale";

type SceneKey = keyof typeof VSCENES;
const SCENES: Array<{ key: SceneKey; C: React.FC<VSceneProps>; cues: SceneCue[] }> = [
  { key: "hook", C: VHook, cues: HOOK },
  { key: "key", C: VKey, cues: KEYC },
  { key: "equation", C: VEquation, cues: EQ },
  { key: "switch", C: VSwitch, cues: SW },
  { key: "tile", C: VTile, cues: TI },
  { key: "resize", C: VResize, cues: RS },
  { key: "island", C: VIsland, cues: IS },
  { key: "finale", C: VFinale, cues: FI },
];

export const V_CUES = SCENES.flatMap(({ key, cues }) =>
  cues.map((c) => ({ ...c, abs: VSCENES[key].start + c.at })),
);

export const VerticalPromo: React.FC<VSceneProps & { audio?: boolean }> = ({ lang, audio = true }) => {
  const { fps } = useVideoConfig();
  const f = (s: number) => Math.round(s * fps);
  return (
    <AbsoluteFill style={{ background: KEY.bg }}>
      {SCENES.map(({ key, C }) => (
        <Sequence key={key} from={f(VSCENES[key].start)} durationInFrames={f(VSCENES[key].len)} premountFor={fps}>
          <C lang={lang} />
        </Sequence>
      ))}
      {audio ? (
        <>
          <Audio src={staticFile(MUSIC_VERTICAL)} volume={0.48} />
          {V_CUES.map((c, i) => (
            <Sequence key={i} from={f(c.abs)} layout="none">
              <Audio src={staticFile(sfxSrc(c.sfx))} volume={(c.vol ?? 0.8) * 0.8} />
            </Sequence>
          ))}
        </>
      ) : null}
    </AbsoluteFill>
  );
};
