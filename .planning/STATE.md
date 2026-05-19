# Project State

## Goal

Build Personal Affairs App v1 in phases: backend, macOS, iOS, local E2E testing, then backend cloud deployment.

## Current Position

Phase 4 automated local verification was completed for the 2026-05-17 snapshot. Since then, an additional macOS visual / shell redesign pass has been in flight.

As of 2026-05-19, `AUDIT_v1.md` is the highest-authority production guidance file. The active implementation documents are now:

- `AUDIT_v1.md`
- `plan.md`
- `personal_affairs_backend_blueprint_v1.md`
- `100j_swiftui_frontend_redesign_blueprint_v1.md`

Stopped frontend documents were removed to end the source-of-truth split.

## Completed

- Phase 1 backend FastAPI service, models, migrations, repositories, routes, and tests.
- Phase 2 macOS SwiftUI client with shared Apple core.
- Phase 3 iOS SwiftUI client with TabView shell and iOS-specific screens for Personal, Company, Calendar, Agent, and Settings.
- iOS shares `PersonalAffairsCore` Domain / API / Repository with macOS.
- iOS Simulator build passes on iPhone 17, iOS 26.5.
- Phase 4 backend tests, migration check, OpenAPI check, API smoke test, macOS build/test, and iOS simulator build pass.
- Documentation source-of-truth cleanup: old frontend blueprint, temporary frontend review memo, and HTML visual prototype were removed.

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

- Treat `AUDIT_v1.md` as the current production guidance file until superseded by a newer audit or explicit user instruction.
- Treat `100j_swiftui_frontend_redesign_blueprint_v1.md` as the active frontend v1.1 blueprint.
- Deleted stopped frontend documents instead of keeping superseded copies in the repo.
- Keep Calendar and Agent as global top-level navigation entries on both macOS and iOS.
- Keep Today as the macOS default command center, constrained to aggregate existing Task / CalendarItem / Note / Project data without new backend objects or APIs.
- Use native SwiftUI instead of web UI.
- Use scratch paths outside this repo for SwiftPM / Xcode derived data because the repository path contains `%`.
- Keep macOS-specific `NavigationSplitView` / `HSplitView` surfaces behind `#if os(macOS)` and iOS-specific views behind `#if os(iOS)`.

## Next Action

When the user asks to resume implementation, start with the P0 items in `AUDIT_v1.md`: Agent confirmation UI, STATE/worktree cleanup, then iOS sharing rules and ViewModel extraction.
