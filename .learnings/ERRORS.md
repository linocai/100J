## [ERR-20260517-001] pip_editable_install_package_discovery

**Logged**: 2026-05-17T10:00:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: backend

### Summary
Editable install failed because setuptools discovered both `app` and `alembic` as top-level packages.

### Error
```text
error: Multiple top-level packages discovered in a flat-layout: ['app', 'alembic'].
```

### Context
- Command: `python -m pip install -e ".[dev]"`
- Working directory: `backend`
- Cause: `pyproject.toml` did not restrict package discovery.

### Suggested Fix
Setuptools package discovery should include only `app*` for this backend package.

### Metadata
- Reproducible: yes
- Related Files: `backend/pyproject.toml`

---

## [ERR-20260517-005] ios_build_ios16_contentunavailable_hsplitview

**Logged**: 2026-05-17T11:35:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: frontend

### Summary
iOS simulator build failed because the package targets iOS 16 while new iOS views used iOS 17-only `ContentUnavailableView`, and macOS `HSplitView` files were compiled for iOS.

### Error
```text
'ContentUnavailableView' is only available in iOS 17.0 or newer
'HSplitView' is unavailable in iOS
```

### Context
- Command: `xcodebuild -scheme PersonalAffairsApp -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/personal-affairs-xcode-derived build`
- Working directory: `frontend/apple`

### Suggested Fix
Use a custom iOS 16-compatible empty-state view and wrap macOS-only SwiftUI screens with `#if os(macOS)`.

### Metadata
- Reproducible: yes
- Related Files: `frontend/apple/Sources/PersonalAffairsApp/Features/iOS`, `frontend/apple/Sources/PersonalAffairsApp/Features/Company/CompanyProjectsView.swift`, `frontend/apple/Sources/PersonalAffairsApp/Features/Agent/AgentView.swift`

---

## [ERR-20260517-004] swiftpm_percent_path_index_store

**Logged**: 2026-05-17T11:00:00+08:00
**Priority**: medium
**Status**: pending
**Area**: frontend

### Summary
SwiftPM build failed when the workspace path contained `%`.

### Error
```text
failed to create temporary file: /Users/linotsai/Lino/100bJ/frontend/apple/.build/...
missing required module 'SwiftShims'
```

### Context
- Command: `swift build`
- Working directory: `/Users/linotsai/Lino/100%J/frontend/apple`
- SwiftPM / Swift index store appears to mis-handle `%J` in the source path.

### Suggested Fix
Use a scratch path outside the `%` directory, such as `swift build --scratch-path /tmp/personal-affairs-apple-build`, and document this workaround for this repo path.

### Metadata
- Reproducible: yes
- Related Files: `frontend/apple/README.md`

---

## [ERR-20260517-006] phase4_smoke_reserved_email_domain

**Logged**: 2026-05-17T12:00:00+08:00
**Priority**: low
**Status**: resolved
**Area**: backend

### Summary
Phase 4 API smoke registration failed because `email-validator` rejects reserved test domains such as `local.test`.

### Error
```text
value is not a valid email address: The part after the @-sign is a special-use or reserved name
```

### Context
- Command: Phase 4 smoke script against local API.
- Input email: `phase4_<timestamp>@local.test`

### Suggested Fix
Use a syntactically valid disposable email under an accepted domain, such as `phase4_<timestamp>@example.com`, for local smoke tests.

### Metadata
- Reproducible: yes
- Related Files: `backend/scripts/phase4_smoke.py`

---

## [ERR-20260517-007] detached_uvicorn_nohup_unreliable

**Logged**: 2026-05-17T12:00:00+08:00
**Priority**: low
**Status**: resolved
**Area**: backend

### Summary
Starting uvicorn through a one-line `nohup env ... uvicorn ... &` command exited silently in this Codex desktop session.

### Error
```text
backend did not become healthy
```

### Context
- Command: detached local Phase 4 API startup.
- Log file was empty and no server process remained.

### Suggested Fix
Launch the local API with Python `subprocess.Popen(..., start_new_session=True)` and write PID/log paths explicitly.

### Metadata
- Reproducible: unknown
- Related Files: `.planning/PHASE4_LOCAL_TEST.md`

---

## [ERR-20260517-002] passlib_bcrypt_5_incompatibility

**Logged**: 2026-05-17T10:00:00+08:00
**Priority**: high
**Status**: resolved
**Area**: backend

### Summary
`passlib==1.7.4` failed with `bcrypt==5.0.0` during password hashing and logs noisy backend warnings with newer bcrypt 4.1+ releases.

### Error
```text
ValueError: password cannot be longer than 72 bytes, truncate manually if necessary
AttributeError: module 'bcrypt' has no attribute '__about__'
```

### Context
- Command: `pytest`
- Failure happened on registration before any business-rule tests could run.
- `passlib[bcrypt]` allowed the latest `bcrypt` release, but Passlib's bcrypt backend is not compatible with bcrypt 5.0.0.

### Suggested Fix
Pin `bcrypt<4.1.0` while using Passlib 1.7.4.

### Metadata
- Reproducible: yes
- Related Files: `backend/pyproject.toml`, `backend/app/core/security.py`

---

## [ERR-20260517-003] alembic_percent_path_interpolation

**Logged**: 2026-05-17T10:00:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: backend

### Summary
Alembic failed to read `alembic.ini` because the project path contains `%`.

### Error
```text
configparser.InterpolationSyntaxError: '%' must be followed by '%' or '(', found: '%J/backend'
```

### Context
- Command: `DATABASE_URL=sqlite:///./tmp/migration_check.db alembic upgrade head`
- Working directory path includes `100%J`.
- An empty `[post_write_hooks]` section caused Alembic/configparser to interpolate default values containing the current path.

### Suggested Fix
Avoid unnecessary ini interpolation in paths containing `%`; Alembic env files can build an engine directly from `DATABASE_URL`.

### Metadata
- Reproducible: yes
- Related Files: `backend/alembic.ini`, `backend/alembic/env.py`

---
