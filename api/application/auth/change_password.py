"""Change password for an authenticated user."""

from uuid import UUID

from pwdlib import PasswordHash
from sqlalchemy.orm import Session

from domain.exceptions import InvalidCurrentPassword, WeakPassword
from persistence.repositories.user_repository import UserRepository

MIN_PASSWORD_LENGTH = 8

password_hasher = PasswordHash.recommended()


class ChangePassword:
    def __init__(
        self,
        session: Session,
        users: UserRepository,
        hasher: PasswordHash | None = None,
    ) -> None:
        self._session = session
        self._users = users
        self._hasher = hasher or password_hasher

    def execute(
        self,
        *,
        user_id: UUID,
        current_password: str,
        new_password: str,
    ) -> None:
        self._validate_new_password(new_password, current_password)

        user = self._users.get_by_id(user_id)
        if user is None or not self._hasher.verify(
            current_password,
            user.password_hash,
        ):
            raise InvalidCurrentPassword()

        updated = self._users.update_password(
            user_id,
            password_hash=self._hasher.hash(new_password),
            must_change_password=False,
        )
        if updated is None:
            raise InvalidCurrentPassword()

        self._session.commit()

    @staticmethod
    def _validate_new_password(new_password: str, current_password: str) -> None:
        if len(new_password) < MIN_PASSWORD_LENGTH:
            raise WeakPassword()
        if new_password == current_password:
            raise WeakPassword(
                "La nueva contraseña debe ser distinta a la actual",
            )
