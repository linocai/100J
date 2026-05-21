#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRATCH_PATH="${SCRATCH_PATH:-/tmp/personal-affairs-apple-package-build}"
APP_NAME="${APP_NAME:-100J}"
PRODUCT_NAME="PersonalAffairsApp"
BUNDLE_ID="${BUNDLE_ID:-top.linotsai.app.PersonalAffairs}"
VERSION="${VERSION:-1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
ICON_SOURCE="${ICON_SOURCE:-/Users/linotsai/Pictures/GPT Image/rounded-j-appicon-v1.png}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-${SIGN_IDENTITY:--}}"
ENTITLEMENTS_PATH="${ENTITLEMENTS_PATH:-$PROJECT_DIR/Sources/PersonalAffairsApp/Resources/PersonalAffairsApp.macOS.entitlements}"
NOTARIZE="${NOTARIZE:-0}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_APP_SPECIFIC_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"
STAPLE="${STAPLE:-1}"
DIST_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/$APP_NAME-macos-$VERSION-$BUILD_NUMBER.zip"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"

cd "$PROJECT_DIR"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_notarization_credentials() {
  if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
    echo "NOTARIZE=1 requires CODESIGN_IDENTITY='Developer ID Application: ...'." >&2
    exit 1
  fi

  if [[ -n "$NOTARY_PROFILE" ]]; then
    return
  fi

  if [[ -z "$APPLE_ID" || -z "$APPLE_TEAM_ID" || -z "$APPLE_APP_SPECIFIC_PASSWORD" ]]; then
    echo "NOTARIZE=1 requires either NOTARY_PROFILE or APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_SPECIFIC_PASSWORD." >&2
    exit 1
  fi
}

create_zip() {
  rm -f "$ZIP_PATH"
  (cd "$DIST_DIR" && ditto -c -k --keepParent "$APP_NAME.app" "$ZIP_PATH")
}

codesign_app() {
  # 关键稳定性配置（解决 ad-hoc 重打包触发 Keychain "允许访问"对话框）：
  # 1. --identifier "$BUNDLE_ID"  让 keychain ACL 用稳定 bundle id 匹配 App。
  # 2. --requirements 'designated => identifier ...'
  #      让 designated requirement 用 identifier 字符串而不是 cdhash，
  #      旧版本写入的 keychain item 在新版本启动时仍然能直接读到。
  # 3. entitlements 中的 keychain-access-groups 让 SecItem 用 access group
  #      作为身份键 — 这是 macOS Sequoia+ 推荐的最终方案。
  # codesign --requirements 接收 "=<source>" 表示 inline 源码（非文件路径）。
  local designated_req='=designated => identifier "'"$BUNDLE_ID"'"'
  local args=(
    --force --deep
    --identifier "$BUNDLE_ID"
    --requirements "$designated_req"
    --sign "$CODESIGN_IDENTITY"
  )
  if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
    args+=(--options runtime --timestamp)
  fi
  if [[ -n "$ENTITLEMENTS_PATH" ]]; then
    if [[ ! -f "$ENTITLEMENTS_PATH" ]]; then
      echo "Missing entitlements file: $ENTITLEMENTS_PATH" >&2
      exit 1
    fi
    args+=(--entitlements "$ENTITLEMENTS_PATH")
  fi

  codesign "${args[@]}" "$APP_BUNDLE"
  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
}

notarize_app() {
  require_notarization_credentials
  require_command xcrun

  create_zip

  if [[ -n "$NOTARY_PROFILE" ]]; then
    xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  else
    xcrun notarytool submit "$ZIP_PATH" \
      --apple-id "$APPLE_ID" \
      --team-id "$APPLE_TEAM_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --wait
  fi

  if [[ "$STAPLE" == "1" ]]; then
    xcrun stapler staple "$APP_BUNDLE"
    xcrun stapler validate "$APP_BUNDLE"
    create_zip
  fi

  spctl --assess --type execute --verbose=4 "$APP_BUNDLE"
}

if [[ "$NOTARIZE" == "1" ]]; then
  require_notarization_credentials
  require_command xcrun
fi

swift build \
  -c release \
  --scratch-path "$SCRATCH_PATH" \
  --product "$PRODUCT_NAME"

EXECUTABLE="$SCRATCH_PATH/release/$PRODUCT_NAME"
if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Missing release executable: $EXECUTABLE" >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
install -m 755 "$EXECUTABLE" "$MACOS_DIR/$PRODUCT_NAME"

generate_icon() {
  local ppm_path="$RESOURCES_DIR/AppIcon.ppm"
  local png_path="$RESOURCES_DIR/AppIcon-1024.png"
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"

  if [[ -f "$ICON_SOURCE" ]]; then
    sips -z 1024 1024 "$ICON_SOURCE" --out "$png_path" >/dev/null
  else
    python3 - "$ppm_path" <<'PY'
import math
import sys

path = sys.argv[1]
size = 1024
with open(path, "wb") as f:
    f.write(f"P6\n{size} {size}\n255\n".encode())
    for y in range(size):
        for x in range(size):
            nx = x / (size - 1)
            ny = y / (size - 1)
            radius = math.hypot(nx - 0.5, ny - 0.5)
            if radius > 0.47:
                r, g, b = 238, 234, 225
            else:
                t = (nx + ny) / 2
                r = int(67 * (1 - t) + 131 * t)
                g = int(118 * (1 - t) + 87 * t)
                b = int(244 * (1 - t) + 216 * t)
                if 0.47 < nx < 0.57 or (0.55 < ny < 0.66 and 0.34 < nx < 0.57):
                    r, g, b = 255, 255, 255
            f.write(bytes((r, g, b)))
PY

    sips -s format png "$ppm_path" --out "$png_path" >/dev/null
  fi

  for spec in \
    "16 icon_16x16.png" \
    "32 icon_16x16@2x.png" \
    "32 icon_32x32.png" \
    "64 icon_32x32@2x.png" \
    "128 icon_128x128.png" \
    "256 icon_128x128@2x.png" \
    "256 icon_256x256.png" \
    "512 icon_256x256@2x.png" \
    "512 icon_512x512.png" \
    "1024 icon_512x512@2x.png"; do
    set -- $spec
    sips -z "$1" "$1" "$png_path" --out "$ICONSET_DIR/$2" >/dev/null
  done
  iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
  rm -rf "$ICONSET_DIR" "$ppm_path" "$png_path"
}

generate_icon

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$PRODUCT_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon.icns</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
  </dict>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST

printf "APPL????" > "$CONTENTS_DIR/PkgInfo"

plutil -lint "$CONTENTS_DIR/Info.plist"
codesign_app

if [[ "$NOTARIZE" == "1" ]]; then
  notarize_app
else
  create_zip
fi

echo "$APP_BUNDLE"
echo "$ZIP_PATH"
