import React from "react";
import { Composition, registerRoot } from "remotion";
import { VSwitch } from "../scenes/VSwitch";
import { VTile } from "../scenes/VTile";
import { VResize } from "../scenes/VResize";
import { VFPS, VH, VW, VSCENES } from "../contract";

const Root: React.FC = () => (
  <>
    <Composition id="VSwitch" component={VSwitch} durationInFrames={VSCENES.switch.len * VFPS} fps={VFPS} width={VW} height={VH} defaultProps={{ lang: "zh" as const }} />
    <Composition id="VTile" component={VTile} durationInFrames={VSCENES.tile.len * VFPS} fps={VFPS} width={VW} height={VH} defaultProps={{ lang: "zh" as const }} />
    <Composition id="VResize" component={VResize} durationInFrames={VSCENES.resize.len * VFPS} fps={VFPS} width={VW} height={VH} defaultProps={{ lang: "zh" as const }} />
  </>
);
registerRoot(Root);
