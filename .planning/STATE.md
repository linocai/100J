# Project State

## Goal

Build Personal Affairs App v1 in phases: backend, macOS, iOS, local E2E testing, then backend cloud deployment.

## Current Position

Phase 4 automated local verification was completed for the 2026-05-17 snapshot. P0/P1 production hardening, P2 / Phase 5 deployment, and the first P3 production-soak slice are now complete on branch `codex/production-hardening`.

As of 2026-05-19 16:23 CST, single-owner cloud access-code login is implemented, verified locally, deployed to HZ, and verified in production at `https://100j.linotsai.top`.

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
- P2 / Phase 5 deployment slice on `codex/production-hardening`:
  - Backend Dockerfile, Compose file, production env example, deployment docs, OpenAPI snapshot test, and CI workflow were added.
  - macOS/iOS default release API URL now points to `https://100j.linotsai.top/api/v1`.
  - Personal notes/tasks and Company workbench gained Cmd+F search affordances; ProjectOverviewStrip now has a "More" affordance.
  - HZ cloud deployment is live at `https://100j.linotsai.top` behind Nginx HTTPS reverse proxy.
  - HZ runtime uses server PostgreSQL 16, `/opt/100j/venv`, and `100j-api.service` managed by systemd.
- P3 production-soak slice on `codex/production-hardening`:
  - Backend payload limits now cap long task/project/calendar descriptions and note bodies.
  - Agent dry runs now validate command arguments before returning `dry_run`; dangerous operations validate before requesting confirmation.
  - HZ database backup and restore rehearsal scripts were added and exercised successfully.
  - Calendar query, grouping, sorting, and draft-to-request state moved into `PersonalAffairsCore/ViewState` for macOS and iOS.
  - macOS app packaging produces `frontend/apple/dist/100J.app` and a timestamped zip, with ad-hoc codesign verification.
- P3 closeout slice on `codex/production-hardening`:
  - `/agent/tools` now exposes all 16 supported Agent commands, including `archive_project`.
  - Backend tests cover all Agent tools through API execution, including confirmation for `archive_project`.
  - Swift repository tests cover task query mapping, project task routes, calendar merged fetching/sorting, and Agent execute/confirm request encoding.
  - Inspector/layout constants and key surface opacity values moved into `AppTheme` tokens; regular inspector width is now 360.
- Release-candidate operations slice on `codex/production-hardening`:
  - macOS packaging now supports Developer ID signing, hardened runtime, notarization, stapling, Gatekeeper assessment, and final re-zip when Apple credentials are supplied.
  - `scripts/prod-check.sh` now checks HTTPS health, TLS certificate dates, HZ services, latest backup presence, recent API/Nginx errors, and production smoke.
  - `scripts/verify-release.sh` is the one-command RC verification entrypoint for backend, Apple build/test, iOS simulator build, macOS package, and optional production check.
  - `frontend/apple/RELEASE.md` documents macOS notarization, iOS TestFlight handoff, and crash/usage monitoring policy.
- iPhone direct-install slice on `codex/production-hardening`:
  - `frontend/apple/PersonalAffairsApp.xcodeproj` was added as an iPhone-ready Xcode project for real-device signing and Run.
  - The Xcode project has `PersonalAffairsApp` and `PersonalAffairsCore` targets; the app target uses automatic signing and bundle id `com.linotsai.100j.dev`.
  - CI now validates the project with a generic iOS build and `CODE_SIGNING_ALLOWED=NO`.
- Single-owner cloud login local slice:
  - Backend now has `/api/v1/auth/owner-login`, guarded by `OWNER_CLOUD_ACCESS_CODE`, which returns JWT tokens for the single local owner account and default spaces.
  - macOS/iOS `AuthView` now asks for a cloud access code, not email/password, and exchanges it through shared `AuthRepository.ownerLogin`.
  - Apple app defaults were moved to `https://100j.linotsai.top/api/v1` and `个人云端`; first run migrates old local-owner default to cloud mode.
  - Deployment docs and `.env.example` now include `OWNER_CLOUD_ACCESS_CODE`.
  - HZ deployment was refreshed after SSH recovered; wrong access code returns 401, server-side configured access code returns 200, and `/me` returns `owner@100j.app`.

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
- macOS package produced: `frontend/apple/dist/100J.app` and latest zip `frontend/apple/dist/100J-macos-1.0-202605191413.zip`.
- Public macOS distribution still requires the user's Apple Developer ID certificate/notary credentials; the repo now has the scripted release path, but no private signing material is stored.

Latest backend checks on 2026-05-19:

```bash
cd backend
.venv/bin/ruff check .
.venv/bin/python -m pytest
```

Result: latest `ruff` passed; latest `pytest` passed with 26 tests, including owner cloud access-code login.

Latest Apple checks for the cloud-login slice on 2026-05-19:

```bash
cd frontend/apple
swift build --scratch-path /tmp/personal-affairs-apple-cloud-build
swift test --scratch-path /tmp/personal-affairs-apple-cloud-test
xcodebuild -quiet -project frontend/apple/PersonalAffairsApp.xcodeproj -scheme PersonalAffairsApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/personal-affairs-xcodeproj-cloud-derived CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project frontend/apple/PersonalAffairsApp.xcodeproj -scheme PersonalAffairsApp -destination 'generic/platform=iOS' -derivedDataPath /tmp/personal-affairs-xcodeproj-cloud-generic-derived CODE_SIGNING_ALLOWED=NO build
```

Result: all passed. Swift tests executed 21 tests.

HZ database backup/restore rehearsal on 2026-05-19:

```bash
scripts/hz-db-backup.sh
scripts/hz-db-restore-rehearsal.sh
```

Result: backup created at `/opt/100j/backups/100j-20260519-134704.dump`; restore rehearsal passed with 10 public tables, 1 user, and Alembic version `0002_agent_pending_confirmations`; temporary rehearsal database was dropped.

Production deployment checks on 2026-05-19:

```bash
scripts/deploy-hz.sh
curl -fsS --resolve 100j.linotsai.top:443:118.178.122.194 https://100j.linotsai.top/health
curl -fsS --resolve 100j.linotsai.top:443:118.178.122.194 https://100j.linotsai.top/api/v1/health
ssh deploy@118.178.122.194 'cd /opt/100j/current/backend && /opt/100j/venv/bin/python scripts/phase4_smoke.py --base-url https://100j.linotsai.top --env prod'
```

Result: deploy passed; HTTPS health passed; production smoke passed. Nginx, certbot timer, and `100j-api.service` are active. Certbot issued the `100j.linotsai.top` certificate expiring on 2026-08-17 with automatic renewal configured.

Single-owner cloud login production verification on 2026-05-19:

```bash
scripts/deploy-hz.sh
curl -sS -i --resolve 100j.linotsai.top:443:118.178.122.194 -X POST https://100j.linotsai.top/api/v1/auth/owner-login -H 'Content-Type: application/json' --data '{"access_code":"wrong-code-000"}'
ssh deploy@118.178.122.194 'set -a; . /opt/100j/env/100j.env; set +a; cd /opt/100j/current/backend && /opt/100j/venv/bin/python - <<PY ... PY'
scripts/prod-check.sh
```

Result: deploy passed; wrong owner access code returned 401; configured server-side owner access code returned 200 without printing the secret; `/me` returned `owner@100j.app`; production check passed for `https://100j.linotsai.top`.

Release-candidate verification on 2026-05-19:

```bash
scripts/verify-release.sh
scripts/prod-check.sh
```

Result: release verification passed; production check passed for `https://100j.linotsai.top`. Public and API health returned `{"status":"ok"}`; `100j-api.service`, Nginx, and certbot timer were active; latest backup was `/opt/100j/backups/100j-20260519-134704.dump`; recent API errors had no entries; production smoke passed with password redaction.

iPhone Xcode project verification on 2026-05-19:

```bash
xcodebuild -list -project frontend/apple/PersonalAffairsApp.xcodeproj
xcodebuild -project frontend/apple/PersonalAffairsApp.xcodeproj -scheme PersonalAffairsApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/personal-affairs-xcodeproj-derived build
xcodebuild -project frontend/apple/PersonalAffairsApp.xcodeproj -scheme PersonalAffairsApp -destination 'generic/platform=iOS' -derivedDataPath /tmp/personal-affairs-xcodeproj-derived CODE_SIGNING_ALLOWED=NO build
```

Result: project listed targets and schemes successfully; iOS Simulator build passed; generic iOS device compile passed with signing disabled.

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
- HZ uses Python venv + systemd instead of Docker Compose because Docker Hub pulls from the server were unreliable; Dockerfile and Compose stay in the repo as portable deployment materials.
- HZ pip installs default to the Alibaba Cloud PyPI mirror with explicit timeout/retry values.
- HZ backup scripts keep deploy-owned dumps in `/opt/100j/backups`; restore rehearsal copies the selected dump to a postgres-owned temp file so the production backup directory can stay locked down.

## Next Action

Next useful action is to use Xcode to open `frontend/apple/PersonalAffairsApp.xcodeproj`, select the `PersonalAffairsApp` target, choose the user's Apple ID / Team in Signing & Capabilities, and run on the user's iPhone. On the login screen, enter the server-side `OWNER_CLOUD_ACCESS_CODE` from `/opt/100j/env/100j.env`.
