#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_NAME="AIStage"
APP_NAME="iRing"
BUNDLE_ID="com.iring.mac"
VERSION_FILE="$ROOT_DIR/VERSION"
APP_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE" 2>/dev/null || echo "0.1.0-beta.1")"
if [[ -z "$APP_VERSION" ]]; then
    APP_VERSION="0.1.0-beta.1"
fi
BUILD_NUMBER="$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || echo "1")"
if [[ -z "$BUILD_NUMBER" || ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    BUILD_NUMBER="1"
fi
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Building $APP_NAME (Release)..."
cd "$ROOT_DIR"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="$BIN_DIR/$BIN_NAME"
if [[ ! -x "$BIN_PATH" ]]; then
    echo "Error: Binary not found at $BIN_PATH"
    exit 1
fi

echo "==> Packaging $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
for BUNDLE_PATH in "$BIN_DIR"/*.bundle; do
    if [[ -d "$BUNDLE_PATH" ]]; then
        cp -R "$BUNDLE_PATH" "$RESOURCES_DIR/"
    fi
done

# Generate a clean native macOS squircle app icon (.icns) using Swift + iconutil
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

swift - "$ICONSET_DIR" <<'SWIFT'
import AppKit
import Foundation

let outDir = CommandLine.arguments[1]
let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, px) in sizes {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(px),
        pixelsHigh: Int(px),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: px, height: px)
    let inset = px * 0.08
    let card = rect.insetBy(dx: inset, dy: inset)
    let radius = card.width * 0.225

    // Outer glass squircle gradient
    let path = NSBezierPath(roundedRect: card, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.14, green: 0.20, blue: 0.38, alpha: 1.0),
        NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.22, alpha: 1.0)
    ])!
    gradient.draw(in: path, angle: -55)

    // Subtle specular rim
    NSColor.white.withAlphaComponent(0.24).setStroke()
    path.lineWidth = max(1, px * 0.014)
    path.stroke()

    // Combined iRing "lollipop i + Ring" vector emblem:
    // Crisp white open ring + top 12 o'clock azure sector + bottom 6 o'clock azure dot + white stem.
    let ringCenter = NSPoint(x: px * 0.50, y: px * 0.5547)
    let ringRadius = px * 0.2432
    let ringStroke = max(1.6, px * 0.1113)
    let halfStroke = ringStroke * 0.5
    let azure = NSColor(calibratedRed: 0.05, green: 0.48, blue: 0.96, alpha: 1.0)
    let crispWhite = NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.99, alpha: 0.98)

    let glyphShadow = NSShadow()
    glyphShadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    glyphShadow.shadowBlurRadius = px * 0.025
    glyphShadow.shadowOffset = NSSize(width: 0, height: -px * 0.012)

    NSGraphicsContext.saveGraphicsState()
    glyphShadow.set()

    let openRing = NSBezierPath()
    openRing.appendArc(withCenter: ringCenter, radius: ringRadius, startAngle: 306.5, endAngle: 233.5, clockwise: false)
    openRing.lineWidth = ringStroke
    openRing.lineCapStyle = .round
    crispWhite.setStroke()
    openRing.stroke()

    let dotRadius = px * 0.0479
    let dotCenterY = px * 0.3535
    let dotRect = NSRect(
        x: ringCenter.x - dotRadius,
        y: dotCenterY - dotRadius,
        width: dotRadius * 2,
        height: dotRadius * 2
    )
    azure.setFill()
    NSBezierPath(ovalIn: dotRect).fill()

    let stemWidth = px * 0.0938
    let stemTop = px * 0.2773
    let stemHeight = px * 0.1270
    let stemRect = NSRect(
        x: ringCenter.x - stemWidth * 0.5,
        y: stemTop - stemHeight,
        width: stemWidth,
        height: stemHeight
    )
    crispWhite.setFill()
    NSBezierPath(roundedRect: stemRect, xRadius: stemWidth * 0.5, yRadius: stemWidth * 0.5).fill()
    NSGraphicsContext.restoreGraphicsState()

    // Flush 12 o'clock azure sector drawn cleanly without overlapping drop shadow
    let wedgePath = NSBezierPath()
    wedgePath.appendArc(withCenter: ringCenter, radius: ringRadius + halfStroke, startAngle: 59, endAngle: 121, clockwise: false)
    wedgePath.appendArc(withCenter: ringCenter, radius: max(1, ringRadius - halfStroke), startAngle: 121, endAngle: 59, clockwise: true)
    wedgePath.close()
    azure.setFill()
    wedgePath.fill()

    NSGraphicsContext.restoreGraphicsState()

    if let png = rep.representation(using: .png, properties: [:]) {
        try png.write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
    }
}
SWIFT

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
rm -rf "$ICONSET_DIR"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>iRing 需要辅助功能权限来对齐、切换与同步你本机已安装桌面应用的窗口。</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>iRing 可选使用屏幕录制权限来缓存窗口画面，以实现原生的神奇缩放弹出效果。</string>
</dict>
</plist>
EOF

if security find-identity -v -p codesigning 2>/dev/null | grep -q '"iRing Dev"'; then
    echo "==> Code signing $APP_BUNDLE with 'iRing Dev' certificate..."
    codesign --force --deep --sign "iRing Dev" "$APP_BUNDLE"
elif security find-identity -v -p codesigning 2>/dev/null | grep -q '"AIStage Dev"'; then
    echo "==> Code signing $APP_BUNDLE with 'AIStage Dev' certificate..."
    codesign --force --deep --sign "AIStage Dev" "$APP_BUNDLE"
else
    echo "==> Ad-hoc code signing $APP_BUNDLE..."
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

if [[ "${SKIP_INSTALL:-0}" != "1" && -w "/Applications" ]]; then
    echo "==> Installing to /Applications/$APP_NAME.app..."
    rm -rf "/Applications/AIStage.app" "$HOME/Desktop/AIStage.app"
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP_BUNDLE" "/Applications/$APP_NAME.app"
    ln -sfn "/Applications/$APP_NAME.app" "$HOME/Desktop/$APP_NAME.app"
    echo "==> Created Desktop shortcut: $HOME/Desktop/$APP_NAME.app"
fi

echo "==> Done! App bundle ready at:"
echo "    /Applications/$APP_NAME.app"
echo "    $HOME/Desktop/$APP_NAME.app"
echo "    $APP_BUNDLE"
