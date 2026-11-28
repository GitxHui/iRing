import React from "react";
import { Composition, registerRoot } from "remotion";
import { Switch } from "../scenes/Switch";
import { Tile } from "../scenes/Tile";
import { Resize } from "../scenes/Resize";
import { FFPS, FH, FW, SCENES } from "../contract";

const f = (s: number) => Math.round(s * FFPS);
const Root: React.FC = () => (
  <>
    {(["zh", "en"] as const).map((lang) => (
      <React.Fragment key={lang}>
        <Composition id={`Switch${lang === "en" ? "-EN" : ""}`} component={Switch} durationInFrames={f(SCENES.switch.len)} fps={FFPS} width={FW} height={FH} defaultProps={{ lang }} />
        <Composition id={`Tile${lang === "en" ? "-EN" : ""}`} component={Tile} durationInFrames={f(SCENES.tile.len)} fps={FFPS} width={FW} height={FH} defaultProps={{ lang }} />
        <Composition id={`Resize${lang === "en" ? "-EN" : ""}`} component={Resize} durationInFrames={f(SCENES.resize.len)} fps={FFPS} width={FW} height={FH} defaultProps={{ lang }} />
      </React.Fragment>
    ))}
  </>
);
registerRoot(Root);
