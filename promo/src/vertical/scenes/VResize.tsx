import React from "react";
import { VSceneProps } from "../contract";
import { VShowcase, RESIZE_CUES } from "./showcase";

export const VResize: React.FC<VSceneProps> = ({ lang }) => <VShowcase part="resize" lang={lang} />;
export const CUES = RESIZE_CUES;
