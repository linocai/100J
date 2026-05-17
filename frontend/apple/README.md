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

## Test

```bash
cd frontend/apple
swift test
```

Use the same scratch-path workaround if needed:

```bash
swift test --scratch-path /tmp/personal-affairs-apple-build
```

## Run Backend First

```bash
cd backend
source .venv/bin/activate
export DATABASE_URL=sqlite:///./personal_affairs.db
alembic upgrade head
uvicorn app.main:app --reload
```

The macOS client defaults to:

```text
http://127.0.0.1:8000/api/v1
```

You can change it in Settings inside the app.

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
