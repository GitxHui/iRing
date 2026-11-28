import React from "react";
import { VSceneProps } from "../contract";
import { T, VFeature, deskCues } from "./featureCommon";

export const VSwitch: React.FC<VSceneProps> = ({ lang }) => <VFeature id="switch" lang={lang} />;

export const CUES = [
  { sfx: "whoosh" as const, at: 0.0, vol: 0.5 },
  ...deskCues("switch", [
    ["key_down", T.altA, 0.8],
    ["ring_open", T.ringA, 0.65],
    ["tick", T.toGPT + 0.16, 0.55],
    ["tick_hi", T.toClaude + 0.14, 0.55],
    ["key_up", T.releaseA, 0.6],
    ["ring_close", T.releaseA, 0.5],
    ["select", T.releaseA + 0.03, 0.7],
    ["whoosh_fast", T.releaseA + 0.02, 0.4],
  ]),
];
