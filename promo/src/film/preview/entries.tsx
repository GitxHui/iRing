import React from "react";
import { Composition, registerRoot } from "remotion";
import { Entries } from "../scenes/Entries";
import { FFPS, FH, FW, SCENES } from "../contract";

const Root: React.FC = () => (
  <>
    <Composition id="Entries" component={Entries} durationInFrames={SCENES.entries.len * FFPS} fps={FFPS} width={FW} height={FH} defaultProps={{ lang: "zh" as const }} />
    <Composition id="Entries-EN" component={Entries} durationInFrames={SCENES.entries.len * FFPS} fps={FFPS} width={FW} height={FH} defaultProps={{ lang: "en" as const }} />
  </>
);
registerRoot(Root);
