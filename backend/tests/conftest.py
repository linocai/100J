import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, build_engine, get_db
from app.core.rate_limit import limiter
from app.main import create_app


engine = build_engine("sqlite://")
TestingSessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, expire_on_commit=False)


@pytest.fixture(autouse=True)
def reset_database():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    storage = getattr(limiter, "_storage", None)
    if storage is not None and hasattr(storage, "reset"):
        storage.reset()
    yield


@pytest.fixture
def client():
    app = create_app()

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    return TestClient(app)


def register_and_auth(client: TestClient):
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "user@example.com",
            "password": "password123",
            "display_name": "Test User",
            "timezone": "America/New_York",
        },
    )
    assert response.status_code == 201, response.text
    token = response.json()["access_token"]
    headers = {"Authorization": "Bearer {}".format(token)}
    spaces = client.get("/api/v1/spaces", headers=headers).json()["items"]
    by_type = {space["type"]: space for space in spaces}
    return headers, by_type
