from typing import List, Optional, Tuple

from sqlalchemy.orm import Session


def paginate(db: Session, statement, limit: int = 50, cursor: Optional[str] = None) -> Tuple[List, Optional[str]]:
    safe_limit = min(max(limit or 50, 1), 100)
    offset = 0
    if cursor:
        try:
            offset = max(int(cursor), 0)
        except ValueError:
            offset = 0

    rows = list(db.scalars(statement.offset(offset).limit(safe_limit + 1)).all())
    next_cursor = None
    if len(rows) > safe_limit:
        rows = rows[:safe_limit]
        next_cursor = str(offset + safe_limit)
    return rows, next_cursor

