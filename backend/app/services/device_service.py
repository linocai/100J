from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import DeviceToken
from app.schemas.device import RegisterDeviceRequest


def register_device(db: Session, user_id: str, payload: RegisterDeviceRequest) -> DeviceToken:
    now = datetime.now(timezone.utc)
    existing = db.scalar(
        select(DeviceToken).where(
            DeviceToken.user_id == user_id,
            DeviceToken.token == payload.token,
        )
    )
    if existing:
        existing.platform = payload.platform
        existing.app_version = payload.app_version
        existing.last_seen_at = now
        token = existing
    else:
        token = DeviceToken(
            user_id=user_id,
            platform=payload.platform,
            token=payload.token,
            app_version=payload.app_version,
            last_seen_at=now,
        )
        db.add(token)

    db.commit()
    db.refresh(token)
    return token
