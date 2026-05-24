"""P0-3: alembic drift guard must report a clean schema for the live tree."""

import importlib.util
import os
import sys


def _load_drift_module():
    here = os.path.dirname(os.path.abspath(__file__))
    backend_dir = os.path.dirname(here)
    script_path = os.path.join(backend_dir, "scripts", "check_alembic_drift.py")
    spec = importlib.util.spec_from_file_location("check_alembic_drift", script_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules.setdefault("check_alembic_drift", module)
    spec.loader.exec_module(module)
    return module


def test_alembic_drift_main_exits_zero(capsys):
    drift = _load_drift_module()
    issues = drift.check_drift()

    assert issues == [], "alembic drift detected: " + "; ".join(issues)


def test_alembic_drift_main_returns_zero():
    drift = _load_drift_module()
    assert drift.main() == 0
