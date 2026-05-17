#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PersonalAffairsApp"
DISPLAY_NAME="Personal Affairs"
BUNDLE_ID="com.linocai.personal-affairs"
VERSION="0.1.0"
BUILD_NUMBER="1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${APPLE_DIR}/../.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/personal-affairs-macos-release}"
DIST_DIR="${DIST_DIR:-${REPO_ROOT}/dist/macos}"
PRODUCT_PATH="${DERIVED_DATA_PATH}/Build/Products/Release/${APP_NAME}"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
ZIP_PATH="${DIST_DIR}/${APP_NAME}-macOS.zip"

rm -rf "${DERIVED_DATA_PATH}"
(
  cd "${APPLE_DIR}"
  xcodebuild \
    -quiet \
    -configuration Release \
    -scheme "${APP_NAME}" \
    -destination "generic/platform=macOS" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    build
)

if [[ ! -x "${PRODUCT_PATH}" ]]; then
  echo "Missing built executable: ${PRODUCT_PATH}" >&2
  exit 1
fi

rm -rf "${APP_BUNDLE}" "${ZIP_PATH}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"
cp "${PRODUCT_PATH}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
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
</dict>
</plist>
PLIST

printf "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

plutil -lint "${APP_BUNDLE}/Contents/Info.plist"
codesign --force --deep --sign - "${APP_BUNDLE}"
codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"

(
  cd "${DIST_DIR}"
  ditto -c -k --keepParent "${APP_NAME}.app" "${ZIP_PATH}"
)

echo "Created app: ${APP_BUNDLE}"
echo "Created zip: ${ZIP_PATH}"
