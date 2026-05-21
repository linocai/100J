# 100J v1.1.0 Release Notes

## Summary

v1.1 moves 100J to the productionized personal-cloud flow: Apple-native clients, shared ViewModels, onboarding, offline write queue, diagnostics export, widgets, shortcuts, and HZ backend deployment.

## Highlights

- Backend now supports Apple sign-in, owner access-code login, device registration, rate limits, stricter length constraints, idempotent demo seeding, and production `EMAIL_OTP_ENABLED=false`.
- macOS and iOS share the same core ViewModels for Today, Plan, Calendar, Agent, tasks, projects, notes, and composer behavior.
- First authenticated launch shows v1.1 onboarding with optional 5-task / 2-calendar demo data.
- Core writes for tasks, notes, calendar items, and projects are queued offline and replayed when the network returns.
- Settings includes feedback/help links and sanitized diagnostics export.
- Apple identifiers are unified on `top.linotsai.app.PersonalAffairs` and `group.top.linotsai.app.PersonalAffairs`.
- P6 personal-account release produces local install artifacts only: no App Store upload and no public distribution signing.

## Deployment

- Backend target: `https://100j.linotsai.top`.
- Production login acceptance uses the advanced/self-host access-code path.
- Email OTP remains in source for local/test use, but HZ production disables it.

## Verification

- Backend lint and tests pass: `ruff check .`, `pytest` with 41 tests.
- Apple Swift build/tests pass, and the generic iOS Xcode build passes with signing disabled.
- macOS ad-hoc package builds and signs locally: `frontend/apple/dist/100J-macos-1.1.0-202605211538.zip`.
- HZ deploy passed on 2026-05-21; `scripts/prod-check.sh` passed for `https://100j.linotsai.top`.
- Production Email OTP request returns 404, owner access-code login returns 200, and `seed-demo` is idempotent after deploy.
