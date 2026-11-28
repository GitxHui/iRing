<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/media/hero-en-dark.svg" />
    <img src="docs/media/hero-en-light.svg" width="820" alt="iRing for macOS. Switch apps, tile, and resize windows at your cursor." />
  </picture>
</p>

<p align="center"><a href="README.md">简体中文</a> · <strong>English</strong></p>

<p align="center">
  <a href="https://github.com/GitxHui/iRing/releases/download/v0.1.0-beta.2/iRing-v0.1.0-beta.2-macOS-arm64.dmg"><img src="docs/media/btn-download-en.svg" alt="Download the Mac beta (DMG)" /></a><br />
  <a href="https://gitxhui.github.io/iRing/?lang=en">Website</a> · <a href="#download-and-install">Homebrew</a> · <a href="https://github.com/GitxHui/iRing/releases/download/v0.1.0-beta.2/iRing-v0.1.0-beta.2-macOS-arm64.zip">ZIP</a><br />
  <sub>Beta 2 · macOS 15 or later · Apple silicon (arm64)</sub>
</p>

## Download and install

- **Manual install.** Download from the [website](https://gitxhui.github.io/iRing/?lang=en) or get the [DMG](https://github.com/GitxHui/iRing/releases/download/v0.1.0-beta.2/iRing-v0.1.0-beta.2-macOS-arm64.dmg) / [ZIP](https://github.com/GitxHui/iRing/releases/download/v0.1.0-beta.2/iRing-v0.1.0-beta.2-macOS-arm64.zip) directly. Drag **iRing.app** to **Applications**.
- **Homebrew.** Install the same beta from the project's [tap](https://github.com/GitxHui/homebrew-tap).

```sh
brew install --cask gitxhui/tap/iring
```

Open iRing and enable it in **System Settings → Privacy & Security → Accessibility**. This beta has not been notarized by Apple. If macOS blocks the first launch, see the [release notes for installation instructions and SHA-256 checksums](https://github.com/GitxHui/iRing/releases/tag/v0.1.0-beta.2).

## Quick start

<p align="center">
  <img src="docs/media/hero-en.webp" width="820" alt="iRing radial app switching and tiling preview" />
</p>

| Feature | Gesture |
| --- | --- |
| Switch apps | Hold left **⌥** or the middle mouse button, point to an app, and release. |
| Tile windows | Press **Tab** or tap the trackpad while holding **⌥**, or use **⌥ + middle mouse button**. Point to preview a layout and release to apply. |
| Resize windows | With the ring open, swipe with two fingers or scroll the mouse wheel to resize from **45% to 100%**. |
| Liquid Glass dock | Keep favorite apps near the MacBook notch or along a screen edge. Press **⌥ + Space** to show or hide the dock. |

[Watch the 35-second film](https://gitxhui.github.io/iRing/?lang=en#film) · [See individual feature demos](https://gitxhui.github.io/iRing/?lang=en#features)

## Build from source

Requires macOS 15+ and Swift 6.2+. Run these commands from the repository root.

```sh
swift run AIStageSelfTest
./Scripts/build_app.sh
```

Use `SKIP_INSTALL=1 ./Scripts/build_app.sh` to build without installing into Applications.

[Changelog](CHANGELOG.md) · [MIT License](LICENSE) · [Report an issue](https://github.com/GitxHui/iRing/issues)
