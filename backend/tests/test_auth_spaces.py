from tests.conftest import register_and_auth


def test_register_creates_default_spaces(client):
    headers, spaces = register_and_auth(client)

    assert "personal" in spaces
    assert "company" in spaces
    assert spaces["personal"]["name"] == "Personal"
    assert spaces["company"]["name"] == "Company"

    me = client.get("/api/v1/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["email"] == "user@example.com"
