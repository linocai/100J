# Personal Affairs Apple App

SwiftUI macOS client for Personal Affairs App v1.

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

`PersonalAffairsCore` is designed to be reused by Phase 3 iOS.

## Build

```bash
cd frontend/apple
swift build
```

This repository path contains `%`, which can confuse SwiftPM's index store on some toolchains. If `swift build` emits paths like `100bJ` or invalid `SwiftShims` module cache errors, build with a scratch path outside the repo:

```bash
swift build --scratch-path /tmp/personal-affairs-apple-build
```

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
