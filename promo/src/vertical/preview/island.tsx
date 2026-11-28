import React from "react";
import { Composition, registerRoot } from "remotion";
import { VIsland } from "../scenes/VIsland";
import { VFPS, VH, VSCENES, VW } from "../contract";
// island scene length follows VSCENES.island.len (6.5 s)

const Root: React.FC = () => (
  <>
    <Composition
      id="VIsland"
      component={VIsland}
      durationInFrames={Math.round(VSCENES.island.len * VFPS)}
      fps={VFPS}
      width={VW}
      height={VH}
      defaultProps={{ lang: "zh" as const }}
    />
    <Composition
      id="VIsland-EN"
      component={VIsland}
      durationInFrames={Math.round(VSCENES.island.len * VFPS)}
      fps={VFPS}
      width={VW}
      height={VH}
      defaultProps={{ lang: "en" as const }}
    />
  </>
);

registerRoot(Root);
