# Project State

## Goal

Build Personal Affairs App v1 in phases: backend, macOS, iOS, local E2E testing, then backend cloud deployment.

## Current Position

Phase 4 automated local verification was completed for the 2026-05-17 snapshot. A P0/P1 production-hardening slice is now complete on branch `codex/production-hardening`.

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
- P0/P1 Apple hardening slice on `codex/production-hardening`:
  - `PersonalAffairsCore/ViewState` now owns shared task query, company grouping, Agent draft, and Agent confirmation prompt state.
  - macOS and iOS Agent use productized confirmation prompts; raw backend confirmation tokens are not shown to users.
  - iOS Personal / Company task flows consume shared query helpers.
  - Legacy macOS product-path UI was removed.
  - `frontend/apple/SHARING_RULES.md` records the no-duplicated-business-logic rule.

## Verification

Run from `frontend/apple`:

```bash
swift build --scratch-path /tmp/personal-affairs-apple-build
swift test --scratch-path /tmp/personal-affairs-apple-build
xcodebuild -quiet -scheme PersonalAffairsApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/personal-affairs-xcode-derived build
```

Latest Apple result: all passed on 2026-05-19 on `codex/production-hardening`.

Notes:

- `xcodebuild` printed `IDERunDestination: Supported platforms for the buildables in the current scheme is empty.`, but exited 0 and completed the iOS Simulator build.
- Backend files were not changed in this hardening slice, so backend tests were not rerun.

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
- Keep Apple-side fetch/filter/group/review business rules in `PersonalAffairsCore/ViewState` or repositories; platform views should stay layout shells.
- Keep Agent confirmation productized: do not expose raw confirmation tokens or ask users to paste them.
- Use native SwiftUI instead of web UI.
- Use scratch paths outside this repo for SwiftPM / Xcode derived data because the repository path contains `%`.
- Keep macOS-specific `NavigationSplitView` / `HSplitView` surfaces behind `#if os(macOS)` and iOS-specific views behind `#if os(iOS)`.

## Next Action

Next useful action is P2 from `AUDIT_v1.md`: Phase 5 deployment materials, OpenAPI schema snapshot test, Cmd+F search, and ProjectOverviewStrip "More" affordance.
