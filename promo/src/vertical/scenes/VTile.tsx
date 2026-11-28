import React from "react";
import { VSceneProps } from "../contract";
import { VShowcase, TILE_CUES } from "./showcase";

export const VTile: React.FC<VSceneProps> = ({ lang }) => <VShowcase part="tile" lang={lang} />;
export const CUES = TILE_CUES;
