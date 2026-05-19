from app.core.config import Settings


def test_cors_origins_accepts_comma_separated_string():
    settings = Settings(cors_origins="https://100j.linotsai.top,http://127.0.0.1:3000")

    assert settings.cors_origins == ["https://100j.linotsai.top", "http://127.0.0.1:3000"]


def test_cors_origins_accepts_json_list_string():
    settings = Settings(cors_origins='["https://100j.linotsai.top", "http://127.0.0.1:3000"]')

    assert settings.cors_origins == ["https://100j.linotsai.top", "http://127.0.0.1:3000"]


def test_cors_origins_accepts_empty_string():
    settings = Settings(cors_origins="")

    assert settings.cors_origins == []
