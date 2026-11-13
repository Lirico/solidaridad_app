"""Change password for an authenticated user."""

import re

from pwdlib import PasswordHash
from sqlalchemy.orm import Session

from domain.exceptions import InvalidCurrentPassword, WeakPassword
from persistence.repositories.user_repository import UserRepository

MIN_PASSWORD_LENGTH = 8
MAX_PASSWORD_LENGTH = 128
_HAS_UPPER = re.compile(r"[A-Z]")
_HAS_LOWER = re.compile(r"[a-z]")
_HAS_DIGIT = re.compile(r"[0-9]")
_HAS_SPECIAL = re.compile(r"[^a-zA-Z0-9\s]")

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
        user_id: int,
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
        if (
            len(new_password) < MIN_PASSWORD_LENGTH
            or len(new_password) > MAX_PASSWORD_LENGTH
        ):
            raise WeakPassword(
                "La contraseña debe tener entre 8 y 128 caracteres",
            )
        if _HAS_UPPER.search(new_password) is None:
            raise WeakPassword("Debe contener al menos una mayúscula")
        if _HAS_LOWER.search(new_password) is None:
            raise WeakPassword("Debe contener al menos una minúscula")
        if _HAS_DIGIT.search(new_password) is None:
            raise WeakPassword("Debe contener al menos un número")
        if _HAS_SPECIAL.search(new_password) is None:
            raise WeakPassword(
                "Debe contener al menos un caracter especial (ej: .)",
            )
        if new_password == current_password:
            raise WeakPassword(
                "La nueva contraseña debe ser distinta a la actual",
            )
