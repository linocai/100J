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

## [ERR-20260517-002] passlib_bcrypt_5_incompatibility

**Logged**: 2026-05-17T10:00:00+08:00
**Priority**: high
**Status**: resolved
**Area**: backend

### Summary
`passlib==1.7.4` failed with `bcrypt==5.0.0` during password hashing.

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
Pin `bcrypt<5.0.0` while using Passlib 1.7.4.

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
