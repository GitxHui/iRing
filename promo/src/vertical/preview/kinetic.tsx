import React from "react";
import { Composition, registerRoot } from "remotion";
import { VHook } from "../scenes/VHook";
import { VKey } from "../scenes/VKey";
import { VEquation } from "../scenes/VEquation";
import { VFinale } from "../scenes/VFinale";
import { VFPS, VH, VW, VSCENES } from "../contract";

const Root: React.FC = () => (
  <>
    {(
      [
        ["VHook", VHook, VSCENES.hook.len],
        ["VKey", VKey, VSCENES.key.len],
        ["VEquation", VEquation, VSCENES.equation.len],
        ["VFinale", VFinale, VSCENES.finale.len],
      ] as const
    ).map(([id, C, len]) =>
      (["zh", "en"] as const).map((lang) => (
        <Composition
          key={id + lang}
          id={lang === "zh" ? id : `${id}-en`}
          component={C}
          durationInFrames={Math.round(len * VFPS)}
          fps={VFPS}
          width={VW}
          height={VH}
          defaultProps={{ lang }}
        />
      )),
    )}
  </>
);

registerRoot(Root);
