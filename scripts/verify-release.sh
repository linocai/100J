#!/usr/bin/env bash
set -euo pipefail

RUN_BACKEND="${RUN_BACKEND:-1}"
RUN_APPLE="${RUN_APPLE:-1}"
RUN_XCODEBUILD="${RUN_XCODEBUILD:-1}"
RUN_PACKAGE="${RUN_PACKAGE:-1}"
RUN_PROD_CHECK="${RUN_PROD_CHECK:-0}"
NOTARIZE="${NOTARIZE:-0}"
SCRATCH_PATH="${SCRATCH_PATH:-/tmp/personal-affairs-apple-build}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/personal-affairs-xcode-derived}"
IOS_DESTINATION="${IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=26.5}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

section() {
  printf "\n== %s ==\n" "$1"
}

if [[ "$RUN_BACKEND" == "1" ]]; then
  section "Backend lint and tests"
  (cd "$ROOT_DIR/backend" && .venv/bin/ruff check . && .venv/bin/python -m pytest)

  section "Alembic drift check"
  (cd "$ROOT_DIR/backend" && .venv/bin/python scripts/check_alembic_drift.py)
fi

if [[ "$RUN_APPLE" == "1" ]]; then
  section "Apple Swift build"
  (cd "$ROOT_DIR/frontend/apple" && swift build --scratch-path "$SCRATCH_PATH")

  section "Apple Swift tests"
  (cd "$ROOT_DIR/frontend/apple" && swift test --scratch-path "$SCRATCH_PATH")
fi

if [[ "$RUN_XCODEBUILD" == "1" ]]; then
  if ! command -v xcodebuild >/dev/null 2>&1; then
    section "xcodebuild (skipped)"
    echo "xcodebuild not found in PATH; skipping macOS test + iOS build."
    echo "Set RUN_XCODEBUILD=0 to silence this message on non-macOS hosts."
  else
    section "macOS xcodebuild test"
    # The Xcode project ships only the iOS app target; the macOS test surface
    # lives in the SwiftPM package (covered by 'swift test' above). Probe the
    # scheme for test-action support before invoking xcodebuild test so that
    # workspaces without a macOS test scheme degrade to a skip instead of a
    # release-blocking failure.
    if (cd "$ROOT_DIR/frontend/apple" && xcodebuild -showBuildSettings \
      -scheme PersonalAffairsApp \
      -destination 'platform=macOS' \
      -derivedDataPath "$DERIVED_DATA_PATH" \
      test >/dev/null 2>&1); then
      (cd "$ROOT_DIR/frontend/apple" && xcodebuild -quiet \
        -scheme PersonalAffairsApp \
        -destination 'platform=macOS' \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        test)
    else
      echo "PersonalAffairsApp scheme is not configured for macOS test action; relying on 'swift test' above."
    fi

    section "iOS Simulator build"
    (cd "$ROOT_DIR/frontend/apple" && xcodebuild -quiet \
      -scheme PersonalAffairsApp \
      -destination "$IOS_DESTINATION" \
      -derivedDataPath "$DERIVED_DATA_PATH" \
      build)
  fi
fi

if [[ "$RUN_PACKAGE" == "1" ]]; then
  section "macOS package"
  NOTARIZE="$NOTARIZE" "$ROOT_DIR/frontend/apple/scripts/package-macos-app.sh"
fi

if [[ "$RUN_PROD_CHECK" == "1" ]]; then
  section "Production check"
  "$ROOT_DIR/scripts/prod-check.sh"
fi

section "Result"
echo "release verification passed"
