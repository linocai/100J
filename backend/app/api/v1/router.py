from fastapi import APIRouter, Depends

from app.core.database import get_db
from app.api.deps import get_current_user
from app.api.v1 import agent, auth, calendar_items, devices, notes, projects, spaces, tasks
from app.models import User
from app.schemas.auth import UserRead
from app.schemas.seed_demo import SeedDemoResponse
from app.services.seed_demo_service import seed_demo

api_router = APIRouter()


@api_router.get("/health")
def health():
    return {"status": "ok"}


@api_router.get("/me", response_model=UserRead)
def me(current_user: User = Depends(get_current_user)):
    return current_user


@api_router.post("/me/seed-demo", response_model=SeedDemoResponse)
def seed_demo_data(db=Depends(get_db), current_user: User = Depends(get_current_user)):
    return seed_demo(db, current_user.id)


api_router.include_router(auth.router)
api_router.include_router(devices.router)
api_router.include_router(spaces.router)
api_router.include_router(tasks.router)
api_router.include_router(projects.router)
api_router.include_router(calendar_items.router)
api_router.include_router(notes.router)
api_router.include_router(agent.router)
