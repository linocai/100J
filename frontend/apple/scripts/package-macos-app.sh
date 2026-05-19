#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRATCH_PATH="${SCRATCH_PATH:-/tmp/personal-affairs-apple-package-build}"
APP_NAME="${APP_NAME:-100J}"
PRODUCT_NAME="PersonalAffairsApp"
BUNDLE_ID="${BUNDLE_ID:-com.lino.100j}"
VERSION="${VERSION:-1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
ICON_SOURCE="${ICON_SOURCE:-/Users/linotsai/Pictures/GPT Image/rounded-j-appicon-v1.png}"
DIST_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"

cd "$PROJECT_DIR"

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
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "$APP_BUNDLE"
