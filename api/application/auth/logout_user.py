"""Revoke every session issued for an account up to now."""

from sqlalchemy.orm import Session

from domain.exceptions import InvalidCurrentPassword
from persistence.repositories.user_repository import UserRepository


class LogoutUser:
    def __init__(self, session: Session, users: UserRepository) -> None:
        self._session = session
        self._users = users

    def execute(self, *, user_id: int) -> None:
        if self._users.revoke_sessions(user_id) is None:
            raise InvalidCurrentPassword("Token inválido o expirado")
        self._session.commit()
