"""One-shot migration: re-encrypt LLM provider keys from SHA256-derived Fernet
key to scrypt-derived Fernet key (v1.2.4 #15).

Run **once** before upgrading the running v1.2.4 backend. The script is
idempotent: rows whose ciphertext already decrypts with the new scrypt-derived
key are skipped.

Usage:

    python -m backend.scripts.migrate_llm_keys_v124
        or
    cd backend && python scripts/migrate_llm_keys_v124.py
"""

from __future__ import annotations

import base64
import hashlib
import sys
from typing import Optional

from cryptography.fernet import Fernet, InvalidToken
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.database import build_engine
from app.models import LLMProviderKey


def _old_fernet() -> Fernet:
    """Pre-v1.2.4 derivation: raw SHA256(secret) → urlsafe base64."""

    secret = get_settings().llm_key_encryption_secret.encode("utf-8")
    key = base64.urlsafe_b64encode(hashlib.sha256(secret).digest())
    return Fernet(key)


def _new_fernet() -> Fernet:
    """v1.2.4 derivation: scrypt(secret, salt=llm_key_encryption_salt)."""

    settings = get_settings()
    secret = settings.llm_key_encryption_secret.encode("utf-8")
    salt = settings.llm_key_encryption_salt
    derived = hashlib.scrypt(secret, salt=salt, n=2**14, r=8, p=1, dklen=32)
    return Fernet(base64.urlsafe_b64encode(derived))


def _try_decrypt(fernet: Fernet, ciphertext: str) -> Optional[bytes]:
    try:
        return fernet.decrypt(ciphertext.encode("utf-8"))
    except InvalidToken:
        return None


def migrate(db: Session) -> dict:
    """Walk every LLMProviderKey row and re-encrypt with the new derivation."""

    old_fernet = _old_fernet()
    new_fernet = _new_fernet()

    rows = list(db.scalars(select(LLMProviderKey)).all())
    counters = {"total": len(rows), "migrated": 0, "already_new": 0, "failed": 0}

    for row in rows:
        # Already new format — skip.
        if _try_decrypt(new_fernet, row.encrypted_api_key) is not None:
            counters["already_new"] += 1
            continue
        plaintext = _try_decrypt(old_fernet, row.encrypted_api_key)
        if plaintext is None:
            counters["failed"] += 1
            sys.stderr.write(
                f"[migrate_llm_keys_v124] row id={row.id} user_id={row.user_id} "
                "could not be decrypted with either old or new key; skipping.\n"
            )
            continue
        row.encrypted_api_key = new_fernet.encrypt(plaintext).decode("utf-8")
        counters["migrated"] += 1

    db.commit()
    return counters


def main() -> int:
    settings = get_settings()
    engine = build_engine(settings.database_url)
    with Session(engine) as db:
        counters = migrate(db)
    sys.stdout.write(
        "migrate_llm_keys_v124 done: "
        "total={total} migrated={migrated} already_new={already_new} failed={failed}\n".format(
            **counters
        )
    )
    return 1 if counters["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
