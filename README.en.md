<p align="center">
  <img src="docs/icon.png" width="120" height="120" alt="iRing app icon" />
</p>

<h1 align="center">iRing</h1>

<p align="center"><a href="README.md">简体中文</a> · <strong>English</strong></p>

<p align="center">
  <strong>Switch apps and arrange windows right where your pointer is.</strong><br/>
  Hold left Option (⌥) to open the ring. Keep favorite apps within reach in a Liquid Glass dock that fits around the MacBook notch or along a screen edge.
</p>

<p align="center">
  <a href="https://github.com/GitxHui/iRing/releases/download/v0.1.0-beta.2/iRing-v0.1.0-beta.2-macOS-arm64.dmg"><strong>Download Beta 2 (.dmg)</strong></a> ·
  <a href="https://github.com/GitxHui/iRing/releases/tag/v0.1.0-beta.2">Release notes and checksums</a><br/>
  macOS 15.0 or later · Apple silicon (arm64)
</p>

<p align="center"><a href="#default-controls">Controls</a> · <a href="#features">Features</a> · <a href="#install-iring">Installation</a></p>

## Default controls

| Action | Gesture |
| --- | --- |
| Switch apps | Hold left Option (⌥) and move the pointer toward an app in the ring. Release Option to switch. |
| Tile a window | While holding left Option, press Tab or tap the trackpad to open the tiling ring. Choose a half-screen, a corner quarter, or the center to maximize. |
| Resize a window | With the ring open, scroll with two fingers or use the mouse wheel. iRing locks the current selection and adjusts its size continuously from 45% to 100%. Release the trigger to apply. |
| Open the app ring with a mouse | Hold the middle mouse button and move the pointer. |
| Open the tiling ring with a mouse | Press Option (⌥) + middle mouse button. |
| Show or hide the dock | Press Option (⌥) + Space. |
| Move the dock to the next display | Press Control (⌃) + Option (⌥) + Right Arrow, or drag the dock to another display. |

You can customize mouse controls or set a separate tiling shortcut in Settings.

## Features

- **Live tiling previews.** Preview four half-screen layouts, four corner layouts, and a maximized layout before placement.
- **Liquid Glass dock.** Dock it around the MacBook notch or along any screen edge. Choose a glass or black appearance, adjust transparency, and see unread badges for supported apps.
- **Multi-display behavior.** By default, switching apps keeps the current window size and display assignment and leaves reference windows on other displays visible. Optional settings let you maximize a window on switch or move it to the display with the iRing dock.
- **Customizable ring.** Sort apps by the order you added them or by how often you use them, hide apps that are not running, and customize colors and animations. Set different animation speeds for the ring and the dock.

The app interface is available in English and Simplified Chinese.

## Install iRing

1. Open the downloaded DMG and drag **iRing.app** into **Applications**.
2. Open iRing and enable it under **System Settings → Privacy & Security → Accessibility** when prompted. The switching, tiling, and resizing controls work with Accessibility permission alone.

The beta is ad hoc signed and has yet to be notarized by Apple. If macOS blocks the first launch, compare the download with the SHA-256 checksum on the release page. Then run the command below for the installed app.

```bash
xattr -cr /Applications/iRing.app
```

The [release page](https://github.com/GitxHui/iRing/releases/tag/v0.1.0-beta.2) also provides a ZIP archive. Prebuilt downloads target Apple silicon. Intel Mac users can try building from source.

## Build from source

Requires macOS 15.0 or later and Swift 6.2 or later. Run these commands from the repository root.

```bash
# Run the core self-tests
swift run AIStageSelfTest

# Build the release app bundle
./Scripts/build_app.sh

# Package the DMG, ZIP, and SHA256SUMS.txt
./Scripts/release.sh
```

The build script writes the app to the build directory and installs it into Applications when that folder is writable. To build without installing, run `SKIP_INSTALL=1 ./Scripts/build_app.sh`.

See the [changelog](CHANGELOG.md) for version history and [LICENSE](LICENSE) for the MIT license.
