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

## [ERR-20260519-001] docker_compose_percent_path_schema

**Logged**: 2026-05-19T13:22:00+08:00
**Priority**: low
**Status**: resolved
**Area**: infra

### Summary
`docker compose config` failed when run from the repository path containing `%`.

### Error
```text
validating /Users/linotsai/Lino/100%J/docker-compose.yml: error in parsing "compose-spec.json": parse "file:///Users/linotsai/Lino/100%J/compose-spec.json": invalid URL escape "%J/"
```

### Context
- Command: `ONEJ_ENV_FILE=backend/.env.example ONEJ_API_PORT=8020 docker compose config`
- Working directory: `/Users/linotsai/Lino/100%J`
- Docker Compose attempted to parse a local schema URL and treated `%J` as an invalid URL escape.

### Suggested Fix
Run Docker Compose checks from a temporary copy outside the `%` path, such as `/tmp/100j-compose-check`.

### Metadata
- Reproducible: yes
- Related Files: `docker-compose.yml`

---

## [ERR-20260519-002] local_docker_daemon_unavailable

**Logged**: 2026-05-19T13:24:00+08:00
**Priority**: low
**Status**: pending
**Area**: infra

### Summary
Local Docker image build could not run because the local Docker daemon was not available.

### Error
```text
Cannot connect to the Docker daemon at unix:///Users/linotsai/.docker/run/docker.sock. Is the docker daemon running?
```

### Context
- Command: `docker compose --env-file backend/.env.example build api`
- Working directory: `/tmp/100j-compose-check`
- Remote HZ server Docker is active, so deployment can still build on the server.

### Suggested Fix
Use the HZ server Docker daemon for deployment builds, or start Docker Desktop locally before local image-build verification.

### Metadata
- Reproducible: yes
- Related Files: `backend/Dockerfile`, `docker-compose.yml`

---

## [ERR-20260519-003] hz_deploy_opt_directory_permission

**Logged**: 2026-05-19T13:27:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: infra

### Summary
HZ deployment script could not create `/opt/100j` as the non-root deploy user.

### Error
```text
mkdir: cannot create directory '/opt/100j': Permission denied
```

### Context
- Command: `scripts/deploy-hz.sh`
- Remote: `deploy@118.178.122.194`
- `/opt` is root-owned; app-specific directories need sudo creation and deploy ownership.

### Suggested Fix
Use `sudo install -d -o deploy -g deploy` for `/opt/100j/current` and `/opt/100j/env` before rsync.

### Metadata
- Reproducible: yes
- Related Files: `scripts/deploy-hz.sh`

---

## [ERR-20260519-004] hz_pip_package_resolution_instability

**Logged**: 2026-05-19T13:41:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: infra

### Summary
HZ deployment failed during backend dependency installation because pip temporarily could not resolve `cryptography>=43.0.0`.

### Error
```text
ERROR: Could not find a version that satisfies the requirement cryptography>=43.0.0 (from personal-affairs-backend) (from versions: none)
ERROR: No matching distribution found for cryptography>=43.0.0
```

### Context
- Command: `scripts/deploy-hz.sh`
- Remote: `deploy@118.178.122.194`
- A follow-up `pip index versions cryptography` on the same host later succeeded, so this was source/network instability rather than an unsupported Python platform.

### Suggested Fix
Use the Alibaba Cloud PyPI mirror by default on HZ and set explicit pip timeout/retry values in the deployment script.

### Metadata
- Reproducible: unknown
- Related Files: `scripts/deploy-hz.sh`, `deployment.md`

---

## [ERR-20260519-005] cors_origins_pydantic_settings_predecode

**Logged**: 2026-05-19T13:46:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: backend

### Summary
`100j-api.service` failed in `ExecStartPre` because `pydantic-settings` tried to JSON-decode comma-style `CORS_ORIGINS` before the custom validator could split it.

### Error
```text
pydantic_settings.exceptions.SettingsError: error parsing value for field "cors_origins" from source "EnvSettingsSource"
```

### Context
- Command: `scripts/deploy-hz.sh`
- Remote service: `100j-api.service`
- `CORS_ORIGINS=https://100j.linotsai.top` is valid for the app's intended comma-separated config style, but list fields are pre-decoded by `pydantic-settings` unless disabled.

### Suggested Fix
Mark `cors_origins` with `NoDecode` and keep the validator responsible for both comma-separated strings and JSON arrays.

### Metadata
- Reproducible: yes
- Related Files: `backend/app/core/config.py`

---

## [ERR-20260519-006] production_smoke_missing_httpx

**Logged**: 2026-05-19T13:52:00+08:00
**Priority**: low
**Status**: resolved
**Area**: infra

### Summary
Production smoke verification on HZ failed because the runtime venv did not include `httpx`.

### Error
```text
ModuleNotFoundError: No module named 'httpx'
```

### Context
- Command: `/opt/100j/venv/bin/python scripts/phase4_smoke.py --base-url https://100j.linotsai.top --env prod`
- `httpx` was only in the backend `dev` extra, while the HZ deployment installed the runtime package without extras.

### Suggested Fix
Add a small `smoke` optional dependency extra containing `httpx`, and have the HZ deploy script install `backend[smoke]`.

### Metadata
- Reproducible: yes
- Related Files: `backend/pyproject.toml`, `scripts/deploy-hz.sh`

---

## [ERR-20260519-007] hz_pg_dump_backup_dir_permissions

**Logged**: 2026-05-19T13:46:00+08:00
**Priority**: low
**Status**: resolved
**Area**: infra

### Summary
HZ PostgreSQL backup script failed because `pg_dump` ran as the `postgres` user and tried to write directly into a deploy-owned backup directory.

### Error
```text
pg_dump: error: could not open output file "/opt/100j/backups/100j-20260519-134631.dump": Permission denied
```

### Context
- Command: `scripts/hz-db-backup.sh`
- Remote: `deploy@118.178.122.194`
- `/opt/100j/backups` is intentionally deploy-owned and mode `750`.

### Suggested Fix
Dump to a temporary file under `/tmp` as `postgres`, then install it into `/opt/100j/backups` with deploy ownership and mode `640`.

### Metadata
- Reproducible: yes
- Related Files: `scripts/hz-db-backup.sh`

---

## [ERR-20260519-008] hz_pg_restore_backup_file_permissions

**Logged**: 2026-05-19T13:48:00+08:00
**Priority**: low
**Status**: resolved
**Area**: infra

### Summary
HZ restore rehearsal failed because `pg_restore` ran as the `postgres` user and could not read a deploy-owned backup file.

### Error
```text
pg_restore: error: could not open input file "/opt/100j/backups/100j-20260519-134704.dump": Permission denied
```

### Context
- Command: `scripts/hz-db-restore-rehearsal.sh`
- Backup files are intentionally stored as `deploy:deploy` with mode `640`.

### Suggested Fix
For rehearsal, copy the selected backup to a postgres-owned temporary file under `/tmp`, restore from that copy, then remove it in the cleanup trap.

### Metadata
- Reproducible: yes
- Related Files: `scripts/hz-db-restore-rehearsal.sh`

---

## [ERR-20260519-009] swift_urlprotocol_body_stream_in_tests

**Logged**: 2026-05-19T14:04:00+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
Swift repository tests failed when inspecting POST request bodies because `URLProtocol` received the body as `httpBodyStream` instead of `httpBody`.

### Error
```text
XCTUnwrap failed: expected non-nil value of type "Data"
```

### Context
- Command: `swift test --scratch-path /tmp/personal-affairs-apple-build`
- Test: `testAgentRepositoryEncodesExecuteAndConfirmRequests`
- `APIClient` correctly set an encoded request body, but Foundation surfaced it to the stub protocol as a stream.

### Suggested Fix
Test helpers that inspect `URLRequest` bodies should read both `httpBody` and `httpBodyStream`.

### Metadata
- Reproducible: yes
- Related Files: `frontend/apple/Tests/PersonalAffairsCoreTests/PersonalAffairsCoreTests.swift`

---

## [ERR-20260518-001] swiftui_textcontenttype_macos_availability

**Logged**: 2026-05-18T09:50:00+08:00
**Priority**: low
**Status**: resolved
**Area**: frontend

### Summary
SwiftPM rejected `TextContentType.emailAddress` in the macOS package build because that symbol is only available on newer macOS SDK targets.

### Error
```text
'emailAddress' is only available in macOS 14.0 or newer
```

### Context
- Command: `swift test --scratch-path /tmp/personal-affairs-apple-build`
- Failure happened after polishing the auth screen with platform-sensitive text content hints.

### Suggested Fix
Avoid unguarded `textContentType` modifiers in shared macOS/iOS SwiftUI views unless the package deployment target is known to support them.

### Metadata
- Reproducible: yes
- Related Files: `frontend/apple/Sources/PersonalAffairsApp/Features/Auth/AuthView.swift`

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
