from fastapi import APIRouter, Depends

from app.api.deps import get_current_user
from app.api.v1 import agent, auth, calendar_items, notes, projects, spaces, tasks
from app.models import User
from app.schemas.auth import UserRead

api_router = APIRouter()


@api_router.get("/health")
def health():
    return {"status": "ok"}


@api_router.get("/me", response_model=UserRead)
def me(current_user: User = Depends(get_current_user)):
    return current_user


api_router.include_router(auth.router)
api_router.include_router(spaces.router)
api_router.include_router(tasks.router)
api_router.include_router(projects.router)
api_router.include_router(calendar_items.router)
api_router.include_router(notes.router)
api_router.include_router(agent.router)
