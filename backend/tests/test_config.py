import pytest

from app.core.config import Settings, get_settings
from app.main import validate_runtime_settings


@pytest.fixture(autouse=True)
def _reset_settings_cache():
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def test_cors_origins_accepts_comma_separated_string():
    settings = Settings(cors_origins="https://100j.linotsai.top,http://127.0.0.1:3000")

    assert settings.cors_origins == ["https://100j.linotsai.top", "http://127.0.0.1:3000"]


def test_cors_origins_accepts_json_list_string():
    settings = Settings(cors_origins='["https://100j.linotsai.top", "http://127.0.0.1:3000"]')

    assert settings.cors_origins == ["https://100j.linotsai.top", "http://127.0.0.1:3000"]


def test_cors_origins_accepts_empty_string():
    settings = Settings(cors_origins="")

    assert settings.cors_origins == []


def test_apple_allowed_audiences_accepts_comma_separated_string():
    settings = Settings(apple_allowed_audiences="com.example.one,com.example.two")

    assert settings.apple_allowed_audiences == ["com.example.one", "com.example.two"]


# ---- P0-1 production secret validation -------------------------------------------------


_STRONG_SECRET = "x" * 64
_STRONG_SALT = b"100j-prod-salt-v124-very-strong"


def _prod_env(monkeypatch, **overrides):
    base = {
        "APP_ENV": "production",
        "AUTH_MODE": "jwt",
        "JWT_SECRET_KEY": _STRONG_SECRET,
        "LLM_KEY_ENCRYPTION_SECRET": _STRONG_SECRET,
        "LLM_KEY_ENCRYPTION_SALT": _STRONG_SALT.decode("utf-8"),
        "EMAIL_OTP_ENABLED": "false",
        "SMTP_HOST": "",
    }
    base.update(overrides)
    for key, value in base.items():
        monkeypatch.setenv(key, value)
    get_settings.cache_clear()


def test_jwt_secret_min_length_in_production(monkeypatch):
    _prod_env(monkeypatch, JWT_SECRET_KEY="short-secret")
    with pytest.raises(RuntimeError) as exc:
        validate_runtime_settings()
    assert "JWT_SECRET_KEY" in str(exc.value)


def test_jwt_secret_rejects_change_me_marker_in_production(monkeypatch):
    long_but_marked = "change-me-" + ("a" * 40)
    _prod_env(monkeypatch, JWT_SECRET_KEY=long_but_marked)
    with pytest.raises(RuntimeError) as exc:
        validate_runtime_settings()
    assert "JWT_SECRET_KEY" in str(exc.value)


def test_llm_secret_min_length_in_production(monkeypatch):
    _prod_env(monkeypatch, LLM_KEY_ENCRYPTION_SECRET="too-short")
    with pytest.raises(RuntimeError) as exc:
        validate_runtime_settings()
    assert "LLM_KEY_ENCRYPTION_SECRET" in str(exc.value)


def test_llm_salt_must_be_overridden_in_production(monkeypatch):
    _prod_env(monkeypatch, LLM_KEY_ENCRYPTION_SALT="100j-llm-v1")
    with pytest.raises(RuntimeError) as exc:
        validate_runtime_settings()
    assert "LLM_KEY_ENCRYPTION_SALT" in str(exc.value)


def test_smtp_host_required_when_email_otp_enabled_and_prod(monkeypatch):
    _prod_env(monkeypatch, EMAIL_OTP_ENABLED="true", SMTP_HOST="")
    with pytest.raises(RuntimeError) as exc:
        validate_runtime_settings()
    assert "SMTP_HOST" in str(exc.value)


def test_valid_production_settings_pass(monkeypatch):
    _prod_env(monkeypatch, EMAIL_OTP_ENABLED="true", SMTP_HOST="smtp.example.com")
    validate_runtime_settings()  # should not raise


def test_development_skips_strict_validation(monkeypatch):
    monkeypatch.setenv("APP_ENV", "development")
    monkeypatch.setenv("JWT_SECRET_KEY", "change-me-in-development")
    monkeypatch.setenv("LLM_KEY_ENCRYPTION_SECRET", "change-me-32-byte-minimum-secret")
    get_settings.cache_clear()
    validate_runtime_settings()  # should not raise
