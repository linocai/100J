# 100J Apple Release

This document is the release handoff for the native Apple client. Do not commit Apple ID credentials, app-specific passwords, provisioning profiles, private keys, or exported certificates.

## macOS Local Package

```bash
frontend/apple/scripts/package-macos-app.sh
```

The default package is ad-hoc signed for local/private testing and writes:

- `frontend/apple/dist/100J.app`
- `frontend/apple/dist/100J-macos-<version>-<build>.zip`

## macOS Developer ID Package

Prerequisites:

- Apple Developer Program membership.
- A valid `Developer ID Application` certificate in the login keychain.
- A notarytool keychain profile, or Apple ID + team ID + app-specific password.

Recommended credential setup:

```bash
xcrun notarytool store-credentials 100j-notary \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD"
```

Build, sign, notarize, staple, and re-zip:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARIZE=1 \
NOTARY_PROFILE=100j-notary \
frontend/apple/scripts/package-macos-app.sh
```

The script signs with hardened runtime and timestamp when `CODESIGN_IDENTITY` is not ad-hoc. With `NOTARIZE=1`, it submits the zip to Apple, staples the accepted ticket to the app bundle, validates the staple, runs Gatekeeper assessment, and recreates the final zip.

## iOS TestFlight

Current source builds for the iOS Simulator through the SwiftPM/Xcode scheme:

```bash
cd frontend/apple
xcodebuild -quiet \
  -scheme PersonalAffairsApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -derivedDataPath /tmp/personal-affairs-xcode-derived \
  build
```

For TestFlight distribution, create or use an App Store Connect app record for the chosen bundle ID, set the Apple Development Team in Xcode, archive for a generic iOS device, validate, and upload through Xcode Organizer or Transporter. Keep provisioning and signing material outside git.

## Crash And Usage Monitoring

For the first release candidate, use Apple-native reporting first:

- TestFlight feedback and crash reports.
- Xcode Organizer crash reports for macOS and iOS.
- Backend `scripts/prod-check.sh` for API health, systemd, Nginx, TLS, backups, and smoke coverage.

Add a third-party SDK such as Sentry only after deciding the privacy policy, retention window, and whether crash reports may include user task/note text.
