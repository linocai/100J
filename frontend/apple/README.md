# Personal Affairs Apple App

SwiftUI Apple client for Personal Affairs App v1. The app targets macOS and iOS while sharing `PersonalAffairsCore` for Domain, API Client, Repositories, and token storage.

## Structure

```text
frontend/apple/
├── Package.swift
├── Sources/
│   ├── PersonalAffairsCore/
│   │   ├── API/
│   │   ├── Domain/
│   │   ├── Repositories/
│   │   └── Utilities/
│   └── PersonalAffairsApp/
│       ├── App/
│       ├── DesignSystem/
│       └── Features/
└── Tests/
```

## Build

macOS / SwiftPM:

```bash
cd frontend/apple
swift build
```

This repository path contains `%`, which can confuse SwiftPM's index store on some toolchains. If `swift build` emits paths like `100bJ` or invalid `SwiftShims` module cache errors, build with a scratch path outside the repo:

```bash
swift build --scratch-path /tmp/personal-affairs-apple-build
```

iOS Simulator / Xcode:

```bash
cd frontend/apple
xcodebuild -scheme PersonalAffairsApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -derivedDataPath /tmp/personal-affairs-xcode-derived \
  build
```

The exact simulator name can be replaced with any available iOS Simulator from `xcrun simctl list devices available`.

## Run On Your iPhone

Open the iPhone-ready Xcode project, not only the Swift package:

```text
frontend/apple/PersonalAffairsApp.xcodeproj
```

In Xcode:

1. Select the `PersonalAffairsApp` scheme.
2. Select the `PersonalAffairsApp` target, then `Signing & Capabilities`.
3. Enable `Automatically manage signing`.
4. Choose your Apple ID / Personal Team.
5. Keep or adjust the Bundle Identifier. The default is `com.linotsai.100j.dev`.
6. Select your iPhone as the destination and run.

The project target is iPhone-only and links the existing shared `PersonalAffairsCore` static library target.

## Test

```bash
cd frontend/apple
swift test
```

Use the same scratch-path workaround if needed:

```bash
swift test --scratch-path /tmp/personal-affairs-apple-build
```

## Package macOS

```bash
frontend/apple/scripts/package-macos-app.sh
```

The script builds the macOS release executable with a scratch path under `/tmp`, creates
`frontend/apple/dist/100J.app`, ad-hoc signs it for local distribution, verifies the signature,
and writes a timestamped zip next to the app bundle.

For public macOS distribution, use Developer ID signing plus notarization:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARIZE=1 \
NOTARY_PROFILE=100j-notary \
frontend/apple/scripts/package-macos-app.sh
```

See `frontend/apple/RELEASE.md` for notarization, TestFlight, and crash-reporting handoff notes.

## Run Backend First

```bash
cd backend
source .venv/bin/activate
export DATABASE_URL=sqlite:///./personal_affairs.db
alembic upgrade head
uvicorn app.main:app --reload
```

The Apple client defaults to local owner mode. In local owner mode it does not show login,
does not read Keychain tokens, and does not send an Authorization header; the backend lazily
creates the single local owner account and the Personal / Company spaces.

The client defaults to:

```text
http://127.0.0.1:8000/api/v1
```

You can change it in Settings inside the app. Switch Settings to cloud login mode only when
testing the JWT register/login flow against a cloud-style backend.

## Phase 3 iOS Scope

The iOS shell uses a five-tab structure: Personal, Company, Calendar, Agent, and Settings.

- Personal: segmented Tasks / Notes, create, edit, complete, archive, note-to-task conversion.
- Company: segmented Tasks / Projects, all / no-project / with-project / project filtering, create, edit, complete, archive, project detail, project task creation.
- Calendar: global agenda, all / personal / company / project filtering, create, edit, delete.
- Agent: command execution, dry run, confirmation token, LLM key, action logs.
- Settings: API base URL, refresh, logout, session metadata.

Verified commands:

```bash
swift build --scratch-path /tmp/personal-affairs-apple-build
swift test --scratch-path /tmp/personal-affairs-apple-build
xcodebuild -quiet -scheme PersonalAffairsApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/personal-affairs-xcode-derived build
```

From the repository root, the full release-candidate verification entrypoint is:

```bash
scripts/verify-release.sh
```
