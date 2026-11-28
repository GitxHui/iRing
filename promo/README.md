# iRing promo video

Remotion project for the iRing launch film (~35 s, 1920×1080 @ 60 fps) and the README hero loop.
Everything on screen is drawn in code; all music and sound effects are synthesised by
`scripts/make_audio.py` (no third-party samples).

## Compositions

| ID | What |
| --- | --- |
| `Promo-EN` / `Promo-ZH` | Full film with music + SFX |
| `Loop-EN` / `Loop-ZH` | 9.5 s silent loop (switch + tile) for the README |
| `Poster-EN` / `Poster-ZH` | Still frame for video posters |

## Commands

```bash
npm install
npm run dev                                   # Remotion Studio
python3 scripts/make_audio.py public/audio 34.9   # regenerate music + SFX (pass the film length)
npx remotion render Promo-EN out/iring-promo-en-master.mp4 --crf=14 --x264-preset=slow --audio-bitrate=256k
scripts/encode_web.sh out/iring-promo-en-master.mp4 out/iring-promo-en   # ≤10 MB GitHub upload
npx remotion render Loop-EN out/loop-en.mp4 --crf=16
scripts/encode_loop.sh out/loop-en.mp4 out/iring-loop-en 960            # GIF + animated WebP
```

## Where things live

- `src/scenes/` – Hook, Reveal, Desktop (switch → tile → resize → island), Bento, Outro
- `src/components/` – ring, island, windows, keycaps, captions…
- `src/Soundtrack.tsx` – SFX cue sheet, derived from the scene timelines
- `src/lib/copy.ts` – EN / ZH copy
- `public/icons/` – app icons exported from the local Mac (third-party trademarks; see note below)

App icons of third-party apps (ChatGPT, Claude, Chrome, VS Code, WeChat…) are shown to illustrate
iRing working with real apps. Swap `public/icons/*.png` if you prefer neutral placeholders.

Note: `remotion.config.ts` disables Rspack — it hung the headless renderer on this machine.
