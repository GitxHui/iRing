import React from "react";
import { AbsoluteFill, Sequence, staticFile, useVideoConfig } from "remotion";
import { Audio } from "@remotion/media";
import { FilmCue, FilmSceneProps, SCENES, SceneId, SFX_STEMS } from "./contract";
import { MUSIC_FILM, filmSfx } from "./audio";
import { Problem, CUES as C_PROBLEM } from "./scenes/Problem";
import { Reveal, CUES as C_REVEAL } from "./scenes/Reveal";
import { Entries, CUES as C_ENTRIES } from "./scenes/Entries";
import { Switch, CUES as C_SWITCH } from "./scenes/Switch";
import { Tile, CUES as C_TILE } from "./scenes/Tile";
import { Resize, CUES as C_RESIZE } from "./scenes/Resize";
import { Island, CUES as C_ISLAND } from "./scenes/Island";
import { Details, CUES as C_DETAILS } from "./scenes/Details";
import { Finale, CUES as C_FINALE } from "./scenes/Finale";

const ORDER: Array<{ id: SceneId; C: React.FC<FilmSceneProps>; cues: FilmCue[] }> = [
  { id: "problem", C: Problem, cues: C_PROBLEM },
  { id: "reveal", C: Reveal, cues: C_REVEAL },
  { id: "entries", C: Entries, cues: C_ENTRIES },
  { id: "switch", C: Switch, cues: C_SWITCH },
  { id: "tile", C: Tile, cues: C_TILE },
  { id: "resize", C: Resize, cues: C_RESIZE },
  { id: "island", C: Island, cues: C_ISLAND },
  { id: "details", C: Details, cues: C_DETAILS },
  { id: "finale", C: Finale, cues: C_FINALE },
];

const KNOWN = new Set<string>(SFX_STEMS);
export const FILM_CUES = ORDER.flatMap(({ id, cues }) =>
  cues
    .filter((c) => KNOWN.has(c.sfx) && c.at >= 0 && c.at < SCENES[id].len)
    .map((c) => ({ ...c, abs: SCENES[id].start + c.at })),
);

export const Film: React.FC<FilmSceneProps & { audio?: boolean }> = ({ lang, audio = true }) => {
  const { fps } = useVideoConfig();
  const f = (s: number) => Math.round(s * fps);
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      {ORDER.map(({ id, C }) => (
        <Sequence key={id} from={f(SCENES[id].start)} durationInFrames={f(SCENES[id].len)} premountFor={fps}>
          <C lang={lang} />
        </Sequence>
      ))}
      {audio ? (
        <>
          <Audio src={staticFile(MUSIC_FILM)} volume={0.5} />
          {FILM_CUES.map((c, i) => (
            <Sequence key={i} from={f(c.abs)} layout="none">
              <Audio src={staticFile(filmSfx(c.sfx))} volume={(c.vol ?? 0.7) * 0.75} />
            </Sequence>
          ))}
        </>
      ) : null}
    </AbsoluteFill>
  );
};
