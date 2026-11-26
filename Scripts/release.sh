#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="iRing"
VERSION_FILE="$ROOT_DIR/VERSION"
ARCH="$(uname -m)"

PUBLISH=0
CUSTOM_VERSION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --publish)
            PUBLISH=1
            shift
            ;;
        --version)
            CUSTOM_VERSION="${2:-}"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--version X.Y.Z-beta.N] [--publish]"
            exit 1
            ;;
    esac
done

cd "$ROOT_DIR"

if [[ -n "$CUSTOM_VERSION" ]]; then
    printf "%s\n" "$CUSTOM_VERSION" > "$VERSION_FILE"
fi

APP_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
if [[ -z "$APP_VERSION" ]]; then
    echo "Error: VERSION file is empty."
    exit 1
fi

TAG="v$APP_VERSION"
DIST_DIR="$ROOT_DIR/dist"
DMG_NAME="$APP_NAME-$TAG-macOS-$ARCH.dmg"
ZIP_NAME="$APP_NAME-$TAG-macOS-$ARCH.zip"
DMG_PATH="$DIST_DIR/$DMG_NAME"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
SUMS_PATH="$DIST_DIR/SHA256SUMS.txt"

echo "==> [1/4] Running AIStageSelfTest..."
swift run AIStageSelfTest

echo "==> [2/4] Building $APP_NAME $TAG (Release, portable ad-hoc signed)..."
SKIP_INSTALL=1 "$ROOT_DIR/Scripts/build_app.sh"

APP_SRC="$ROOT_DIR/build/$APP_NAME.app"
STAGE_DIR="$DIST_DIR/stage-$TAG"
rm -rf "$STAGE_DIR" "$DMG_PATH" "$ZIP_PATH" "$SUMS_PATH"
mkdir -p "$STAGE_DIR"

cp -R "$APP_SRC" "$STAGE_DIR/$APP_NAME.app"
codesign --force --deep --sign - "$STAGE_DIR/$APP_NAME.app"
ln -s /Applications "$STAGE_DIR/Applications"

echo "==> [3/4] Packaging $DMG_NAME and $ZIP_NAME..."
hdiutil create \
    -volname "$APP_NAME $TAG" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

ditto -c -k --sequesterRsrc --keepParent "$STAGE_DIR/$APP_NAME.app" "$ZIP_PATH"
rm -rf "$STAGE_DIR"

(
    cd "$DIST_DIR"
    shasum -a 256 "$DMG_NAME" "$ZIP_NAME" > "$SUMS_PATH"
)

echo "==> Release artifacts ready:"
cat "$SUMS_PATH"

if [[ "$PUBLISH" -eq 1 ]]; then
    echo "==> [4/4] Tagging and publishing GitHub Release $TAG..."
    if ! git rev-parse "$TAG" >/dev/null 2>&1; then
        git tag -a "$TAG" -m "Release $TAG"
    fi
    git push origin main
    git push origin "$TAG"

    NOTES_FILE="$DIST_DIR/release_notes_$TAG.md"
    cat > "$NOTES_FILE" <<EOF
## iRing $TAG 内测版

### 快速安装
1. 下载下方 **\`$DMG_NAME\`**（或备用 \`.zip\`），将 \`iRing.app\` 拖入「应用程序」文件夹。
2. 由于内测包暂未经过 Apple 公证，首次打不开时在终端执行一次：
   \`\`\`bash
   xattr -cr /Applications/iRing.app
   \`\`\`
3. 打开 **iRing** 后按引导开启 **辅助功能权限** 即可使用完整切窗与 8 向分屏能力。

### 校验值 (SHA256)
\`\`\`
$(cat "$SUMS_PATH")
\`\`\`
EOF

    PRERELEASE_FLAG=()
    if [[ "$APP_VERSION" == *-* ]]; then
        PRERELEASE_FLAG+=(--prerelease)
    fi

    if gh release view "$TAG" >/dev/null 2>&1; then
        gh release upload "$TAG" "$DMG_PATH" "$ZIP_PATH" "$SUMS_PATH" --clobber
    else
        gh release create "$TAG" "$DMG_PATH" "$ZIP_PATH" "$SUMS_PATH" \
            --title "iRing $TAG" \
            --notes-file "$NOTES_FILE" \
            "${PRERELEASE_FLAG[@]}"
    fi
    rm -f "$NOTES_FILE"
fi
