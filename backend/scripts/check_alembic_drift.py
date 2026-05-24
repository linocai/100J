"""Alembic drift guard (v1.2.4 Deferred-B replacement).

Runs ``alembic upgrade head`` against a fresh SQLite database, then compares
the resulting schema (via ``sqlalchemy.inspect``) to the live
``Base.metadata``. Exits non-zero if any table or column difference is found.
Wired into ``scripts/verify-release.sh``.

The comparison intentionally limits itself to **table presence** and
**column-name presence per table** — comparing SQL types or nullability
across dialects (SQLite vs Postgres) is noisy enough to be misleading. Adds /
drops to tables/columns are the high-signal drift we care about for
single-user private cloud.

Usage::

    cd backend && python scripts/check_alembic_drift.py
"""

from __future__ import annotations

import os
import sys
import tempfile
from typing import List, Set

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect

from app.models import Base


IGNORED_TABLES = {"alembic_version"}


def _diff_tables(metadata_tables: Set[str], live_tables: Set[str]) -> List[str]:
    issues: List[str] = []
    for name in sorted(metadata_tables - live_tables):
        issues.append(f"missing table after upgrade (declared in models): {name}")
    for name in sorted(live_tables - metadata_tables - IGNORED_TABLES):
        issues.append(f"extra table after upgrade (not in models): {name}")
    return issues


def check_drift() -> List[str]:
    """Return a list of human-readable drift issues; empty list = clean."""

    here = os.path.dirname(os.path.abspath(__file__))
    backend_dir = os.path.dirname(here)
    alembic_ini = os.path.join(backend_dir, "alembic.ini")

    fd, tmp_path = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    file_url = f"sqlite:///{tmp_path}"

    cfg = Config(alembic_ini)
    # Alembic stores config via ConfigParser, which treats '%' as interpolation.
    # Escape any '%' in paths/URLs so absolute paths containing '%' (e.g. URL-
    # encoded characters in the repo directory name) don't blow up.
    cfg.set_main_option(
        "script_location", os.path.join(backend_dir, "alembic").replace("%", "%%")
    )
    cfg.set_main_option("sqlalchemy.url", file_url.replace("%", "%%"))

    # Alembic env.py reads DATABASE_URL through get_settings(); override for the
    # duration of the check and clear the lru_cache so the override takes effect.
    from app.core.config import get_settings  # noqa: WPS433 (lazy import is intentional)

    prev_db_url = os.environ.get("DATABASE_URL")
    os.environ["DATABASE_URL"] = file_url
    get_settings.cache_clear()

    issues: List[str] = []
    try:
        command.upgrade(cfg, "head")

        inspect_engine = create_engine(file_url, future=True)
        try:
            inspector = inspect(inspect_engine)
            live_tables = set(inspector.get_table_names())
            metadata_tables = set(Base.metadata.tables.keys())

            issues.extend(_diff_tables(metadata_tables, live_tables))

            for table_name in sorted(metadata_tables & live_tables):
                meta_columns = {col.name for col in Base.metadata.tables[table_name].columns}
                live_columns = {col["name"] for col in inspector.get_columns(table_name)}
                for name in sorted(meta_columns - live_columns):
                    issues.append(f"table {table_name}: missing column {name}")
                for name in sorted(live_columns - meta_columns):
                    issues.append(f"table {table_name}: extra column {name}")
        finally:
            inspect_engine.dispose()
    finally:
        if prev_db_url is None:
            os.environ.pop("DATABASE_URL", None)
        else:
            os.environ["DATABASE_URL"] = prev_db_url
        get_settings.cache_clear()
        try:
            os.unlink(tmp_path)
        except OSError:
            pass

    return issues


def main() -> int:
    issues = check_drift()
    if not issues:
        sys.stdout.write("alembic drift check: OK\n")
        return 0
    sys.stderr.write("alembic drift detected:\n")
    for issue in issues:
        sys.stderr.write(f"  - {issue}\n")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
