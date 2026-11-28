import React from "react";
import { Composition, registerRoot } from "remotion";
import { Island } from "../scenes/Island";
import { Details } from "../scenes/Details";
import { Finale } from "../scenes/Finale";
import { FFPS, FH, FW, SCENES } from "../contract";

const f = (s: number) => Math.round(s * FFPS);

const Root: React.FC = () => (
  <>
    {(["zh", "en"] as const).map((lang) => {
      const sfx = lang === "zh" ? "" : "-EN";
      return (
        <React.Fragment key={lang}>
          <Composition id={`Island${sfx}`} component={Island} durationInFrames={f(SCENES.island.len)} fps={FFPS} width={FW} height={FH} defaultProps={{ lang }} />
          <Composition id={`Details${sfx}`} component={Details} durationInFrames={f(SCENES.details.len)} fps={FFPS} width={FW} height={FH} defaultProps={{ lang }} />
          <Composition id={`Finale${sfx}`} component={Finale} durationInFrames={f(SCENES.finale.len)} fps={FFPS} width={FW} height={FH} defaultProps={{ lang }} />
        </React.Fragment>
      );
    })}
  </>
);
registerRoot(Root);
