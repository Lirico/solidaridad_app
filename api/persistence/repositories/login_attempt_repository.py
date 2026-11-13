"""Persistence for failed login attempts."""

from datetime import datetime

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from persistence.models.login_attempt import LoginAttempt


class LoginAttemptRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def count_since(self, username: str, since: datetime) -> int:
        count = self._session.scalar(
            select(func.count())
            .select_from(LoginAttempt)
            .where(
                LoginAttempt.username == username,
                LoginAttempt.attempted_at >= since,
            )
        )
        return int(count or 0)

    def add(self, username: str, attempted_at: datetime) -> None:
        self._session.add(
            LoginAttempt(username=username, attempted_at=attempted_at)
        )
        self._session.flush()

    def delete_for(self, username: str) -> None:
        self._session.execute(
            delete(LoginAttempt).where(LoginAttempt.username == username)
        )
        self._session.flush()
