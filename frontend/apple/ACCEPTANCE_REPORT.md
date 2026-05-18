# 100J macOS Acceptance Report

Date: 2026-05-18  
Scope: local product acceptance, ad-hoc signed macOS app, local FastAPI + temporary SQLite database.  
Out of scope: Developer ID, notarization, DMG, App Store distribution, backend API/model changes.

## Environment

- Workspace: `/Users/linotsai/Lino/100%J`
- App bundle: `/Users/linotsai/Lino/100%J/frontend/apple/dist/100J.app`
- Bundle id: `com.lino.100j`
- Backend URL used by the app: `http://127.0.0.1:8001/api/v1`
- Temporary database: `sqlite:////tmp/100j_acceptance.db`
- Note: port `8000` was already occupied locally, so UI acceptance used `8001` with the same temporary database.

## Disposable Test User

- Email: `phase4_1779068855@example.com`
- Password: `Phase4-pass-123`
- Personal space: `2dba114f-415b-486f-80bb-829f2900951c`
- Company space: `d935b00e-0123-420a-8bdb-b12b61811a52`
- Project: `bbc3f064-4724-4ed9-b7ce-889294010053`

## Automated Verification

| Check | Result |
| --- | --- |
| `cd backend && .venv/bin/pytest` | Pass, 9 tests |
| `DATABASE_URL=sqlite:////tmp/100j_acceptance.db .venv/bin/alembic upgrade head` | Pass |
| `.venv/bin/python scripts/phase4_smoke.py --base-url http://127.0.0.1:8001` | Pass |
| `cd frontend/apple && swift test --scratch-path /tmp/personal-affairs-apple-build` | Pass, 4 tests |
| `xcodebuild -quiet -scheme PersonalAffairsApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/personal-affairs-xcode-derived build` | Pass |
| `cd frontend/apple && ./scripts/package-macos-app.sh` | Pass |
| `plutil -lint frontend/apple/dist/100J.app/Contents/Info.plist` | Pass |
| `codesign --verify --deep --strict --verbose=2 frontend/apple/dist/100J.app` | Pass, ad-hoc signature |

Package notes:

- `Info.plist` includes `NSAppTransportSecurity -> NSAllowsLocalNetworking = true`.
- `CFBundleIconFile = AppIcon`; app icon is present at `Contents/Resources/AppIcon.icns`.
- App bundle size: `4.7M`.

## Screenshot Evidence

Screenshots are intentionally stored under ignored output:

- `frontend/apple/dist/acceptance/2026-05-18/01-login.png`
- `frontend/apple/dist/acceptance/2026-05-18/02-today-wide.png`
- `frontend/apple/dist/acceptance/2026-05-18/03-calendar-wide.png`
- `frontend/apple/dist/acceptance/2026-05-18/04-calendar-1180.png`
- `frontend/apple/dist/acceptance/2026-05-18/05-today-900.png`
- `frontend/apple/dist/acceptance/2026-05-18/06-agent-dry-run-900.png`
- `frontend/apple/dist/acceptance/2026-05-18/07-quick-capture-validation.png`
- `frontend/apple/dist/acceptance/2026-05-18/08-settings-session.png`
- `frontend/apple/dist/acceptance/2026-05-18/09-error-banner.png`

## Functional Acceptance

| # | Criterion | Result | Evidence |
| --- | --- | --- | --- |
| 1 | 登录后 macOS 默认进入 Today | Pass | UI login with disposable user; Today counts loaded |
| 2 | Sidebar has Today / Personal Tasks / Ideas / Company Workbench / Projects / Fixed Calendar / Agent / Settings | Pass | UI accessibility tree and screenshots |
| 3 | Personal Task create has no Project Picker | Pass | Quick Capture personal task target only shows title/description/priority/due date |
| 4 | Company Task Project Picker optional, can be No Project | Pass | Smoke created company project task and no-project company task |
| 5 | Today Focus Stack only shows Task | Pass | Today cards are task cards with completion circles |
| 6 | Today Fixed Schedule only shows CalendarItem | Pass | Fixed schedule shows subscription and appointment only |
| 7 | Task due_date does not enter Calendar | Pass | Personal task due `2026-05-20` appears in task card, not Fixed Calendar |
| 8 | CalendarItem does not show completion checkbox | Pass | Calendar screenshots show event cards with calendar/delete affordances only |
| 9 | Note card can Convert to Task | Pass | Smoke converted Phase4 note to task; Today shows converted task |
| 10 | Company Workbench has No Project Inbox | Pass | Today and smoke data show `Phase4 no-project company task` |
| 11 | Company Workbench groups by Project | Pass | Project task carries `Phase4 company project` tag |
| 12 | Fixed Calendar filters All / Personal / Company / Project | Pass | UI filter segmented control visible; smoke verified personal/company/project calendar queries |
| 13 | Agent confirmation does not silently execute | Pass | Smoke covers confirmation token flow; Agent UI shows dry-run/action-review wording |
| 14 | LLM Key does not display full key | Pass | UI shows `Missing` / no key saved; repository tolerates missing key |
| 15 | Refresh calls `model.refreshAll()` | Pass | Top bar and Settings refresh verified against live backend |
| 16 | ErrorBanner displays and can close | Pass | Broken local URL produced `Could not connect to the server.` banner |
| 17 | Narrow window does not let Inspector crush content | Pass | `05-today-900.png`; inspector hidden below `1180` |
| 18 | iOS still compiles | Pass | `xcodebuild` build succeeded |

## Final Acceptance Standards

| # | Standard | Result |
| --- | --- | --- |
| 1 | Today Command Center first impression | Pass |
| 2 | Left navigation clearly separates Today / Personal / Company / Calendar / Agent | Pass |
| 3 | Task and CalendarItem differ visually and interactively | Pass |
| 4 | Personal has no Project entry | Pass |
| 5 | Company supports project work and no-project small tasks | Pass |
| 6 | Fixed Calendar only carries fixed-date/time items | Pass |
| 7 | Notes are an idea library, not a task list | Pass |
| 8 | Agent feels like an in-app transaction steward | Pass |
| 9 | macOS has Sidebar + Work Area + Inspector workbench feel | Pass |
| 10 | iOS still builds | Pass |
| 11 | Light / Dark readable | Pass with caveat: light mode visually captured; implementation uses semantic SwiftUI colors/materials. Local forced-dark launch did not change the host appearance, so keep one real dark-mode screenshot pass for the next machine-level QA round. |
| 12 | Empty, error, and loading states are not temporary blank boards | Pass |
| 13 | Quick Capture can record quickly, but save requires an explicit target | Pass |

## Changes Made For Acceptance

- Polished Auth layout so macOS login actions stay visible at normal window sizes.
- Added API base URL entry on Auth for local backend E2E.
- Added fallback date decoding for backend SQLite naive ISO timestamps.
- Made missing LLM key non-fatal for initial data load.
- Tightened Quick Capture focus, target heuristics, validation, and save enablement.
- Reworded Agent dry-run/action-review areas toward product language.
- Lowered macOS minimum width to `900`, keeping Inspector hidden below `1180`.
- Unified packaging on `frontend/apple/scripts/package-macos-app.sh` and removed the duplicate underscore script.
- Added generated `AppIcon.icns`, local HTTP ATS allowance, and ad-hoc signing verification.

## Residual Risks

- This is a local ad-hoc bundle only. It is not notarized and is not a distributable production release artifact.
- Dark mode still deserves one explicit human screenshot on a machine already running dark appearance.
- E2E used port `8001` because `8000` was occupied by another local backend process.
- Screenshots are QA artifacts under ignored `frontend/apple/dist/`; they should not be committed.
