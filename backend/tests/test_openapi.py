import json
from pathlib import Path

from app.main import app


SNAPSHOT_PATH = Path(__file__).with_name("openapi_snapshot.json")


def test_openapi_schema_matches_snapshot():
    current = app.openapi()
    snapshot = json.loads(SNAPSHOT_PATH.read_text())

    assert current == snapshot
