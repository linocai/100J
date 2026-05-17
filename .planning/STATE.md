# Project State

## Goal

Build Personal Affairs App v1 in phases: backend, macOS, iOS, local E2E testing, then backend cloud deployment.

## Current Position

Phase 3 iOS is implemented and locally build-verified. Next useful action is Phase 4 local testing: run backend, seed or create a test user, then verify backend + macOS + iOS cross-client flows.

## Completed

- Phase 1 backend FastAPI service, models, migrations, repositories, routes, and tests.
- Phase 2 macOS SwiftUI client with shared Apple core.
- Phase 3 iOS SwiftUI client with TabView shell and iOS-specific screens for Personal, Company, Calendar, Agent, and Settings.
- iOS shares `PersonalAffairsCore` Domain / API / Repository with macOS.
- iOS Simulator build passes on iPhone 17, iOS 26.5.

## Verification

Run from `frontend/apple`:

```bash
swift build --scratch-path /tmp/personal-affairs-apple-build
swift test --scratch-path /tmp/personal-affairs-apple-build
xcodebuild -quiet -scheme PersonalAffairsApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/personal-affairs-xcode-derived build
```

Latest result: all passed on 2026-05-17.

## Decisions

- Keep Calendar and Agent as global top-level navigation entries on both macOS and iOS.
- Use native SwiftUI instead of web UI.
- Use scratch paths outside this repo for SwiftPM / Xcode derived data because the repository path contains `%`.
- Keep macOS-specific `NavigationSplitView` / `HSplitView` surfaces behind `#if os(macOS)` and iOS-specific views behind `#if os(iOS)`.

## Next Action

Start Phase 4 by running backend migrations and API server locally, then perform E2E checks across macOS and iOS against the same local API.
