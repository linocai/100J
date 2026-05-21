from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.schemas.device import RegisterDeviceRequest
from app.services.device_service import register_device

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("", status_code=204)
def register_current_device(
    payload: RegisterDeviceRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    register_device(db, current_user.id, payload)
