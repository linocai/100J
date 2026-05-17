# Project State

## Goal

Build Personal Affairs App v1 in phases: backend, macOS, iOS, local E2E testing, then backend cloud deployment.

## Current Position

Phase 4 automated local verification is complete. The local backend is running on port 8000 for manual macOS and iOS testing.

## Completed

- Phase 1 backend FastAPI service, models, migrations, repositories, routes, and tests.
- Phase 2 macOS SwiftUI client with shared Apple core.
- Phase 3 iOS SwiftUI client with TabView shell and iOS-specific screens for Personal, Company, Calendar, Agent, and Settings.
- iOS shares `PersonalAffairsCore` Domain / API / Repository with macOS.
- iOS Simulator build passes on iPhone 17, iOS 26.5.
- Phase 4 backend tests, migration check, OpenAPI check, API smoke test, macOS build/test, and iOS simulator build pass.

## Verification

Run from `frontend/apple`:

```bash
swift build --scratch-path /tmp/personal-affairs-apple-build
swift test --scratch-path /tmp/personal-affairs-apple-build
xcodebuild -quiet -scheme PersonalAffairsApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/personal-affairs-xcode-derived build
```

Latest result: all passed on 2026-05-17.

Backend Phase 4 checks:

```bash
cd backend
.venv/bin/ruff check .
.venv/bin/python -m pytest
DATABASE_URL=sqlite:////tmp/personal_affairs_phase4_migration.db .venv/bin/alembic upgrade head
.venv/bin/python scripts/phase4_smoke.py --base-url http://127.0.0.1:8000
```

## Decisions

- Keep Calendar and Agent as global top-level navigation entries on both macOS and iOS.
- Use native SwiftUI instead of web UI.
- Use scratch paths outside this repo for SwiftPM / Xcode derived data because the repository path contains `%`.
- Keep macOS-specific `NavigationSplitView` / `HSplitView` surfaces behind `#if os(macOS)` and iOS-specific views behind `#if os(iOS)`.

## Next Action

Manual test macOS and iOS against `http://127.0.0.1:8000/api/v1`, using `.planning/PHASE4_LOCAL_TEST.md` as the checklist. Stop the local backend with `kill $(cat /tmp/personal-affairs-phase4-api.pid)` when testing is done.
