import React from "react";
import { AbsoluteFill, Composition, registerRoot, useCurrentFrame } from "remotion";
import { MacBook3D } from "../device/MacBook3D";
import { Desktop } from "../../scenes/Desktop";

const Test: React.FC = () => {
  const f = useCurrentFrame();
  const cams = [
    { cam: { rx: -4, ry: 0, s: 0.62 }, lid: 92, cy: 860 },
    { cam: { rx: -16, ry: -32, s: 0.55 }, lid: 108, cy: 700 },
    { cam: { rx: -48, ry: 12, s: 0.5 }, lid: 112, cy: 520 },
    { cam: { rx: -10, ry: 150, s: 0.55 }, lid: 105, cy: 760 },
  ];
  const c = cams[f % cams.length];
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      <MacBook3D cx={960} cy={c.cy} cam={c.cam} lid={c.lid} keyGlow={{ option: 1 }} pad={{ show: 1, x: 0, y: 0, fingers: 2 }} screen={<Desktop lang="zh" start={2.6} captions={false} camera={false} keys={false} />} />
    </AbsoluteFill>
  );
};
registerRoot(() => <Composition id="Device" component={Test} durationInFrames={4} fps={60} width={1920} height={1080} />);
