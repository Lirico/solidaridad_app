"""Stop repeated failed logins for the same account."""

from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from config import Settings
from domain.exceptions import TooManyLoginAttempts
from persistence.repositories.login_attempt_repository import LoginAttemptRepository


class LoginRateLimit:
    def __init__(
        self,
        session: Session,
        attempts: LoginAttemptRepository,
        settings: Settings,
    ) -> None:
        self._session = session
        self._attempts = attempts
        self._max_failures = settings.login_max_failures
        self._window = timedelta(minutes=settings.login_failure_window_minutes)

    def ensure_allowed(self, username: str) -> None:
        if self._attempts.count_since(self._key(username), self._since()) >= (
            self._max_failures
        ):
            raise TooManyLoginAttempts()

    def record_failure(self, username: str) -> None:
        self._attempts.add(self._key(username), datetime.now(UTC))
        self._session.commit()

    def clear(self, username: str) -> None:
        self._attempts.delete_for(self._key(username))
        self._session.commit()

    def _since(self) -> datetime:
        return datetime.now(UTC) - self._window

    @staticmethod
    def _key(username: str) -> str:
        return username.strip().lower()
