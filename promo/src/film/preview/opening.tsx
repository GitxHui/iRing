import React from "react";
import { Composition, registerRoot } from "remotion";
import { Problem } from "../scenes/Problem";
import { Reveal } from "../scenes/Reveal";
import { FFPS, FH, FW, SCENES } from "../contract";

const Root: React.FC = () => (
  <>
    <Composition id="Problem" component={Problem} durationInFrames={SCENES.problem.len * FFPS} fps={FFPS} width={FW} height={FH} defaultProps={{ lang: "zh" as const }} />
    <Composition id="Problem-EN" component={Problem} durationInFrames={SCENES.problem.len * FFPS} fps={FFPS} width={FW} height={FH} defaultProps={{ lang: "en" as const }} />
    <Composition id="Reveal" component={Reveal} durationInFrames={SCENES.reveal.len * FFPS} fps={FFPS} width={FW} height={FH} defaultProps={{ lang: "zh" as const }} />
    <Composition id="Reveal-EN" component={Reveal} durationInFrames={SCENES.reveal.len * FFPS} fps={FFPS} width={FW} height={FH} defaultProps={{ lang: "en" as const }} />
  </>
);
registerRoot(Root);
