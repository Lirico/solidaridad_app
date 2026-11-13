"""Change password for an authenticated user."""

from datetime import timedelta

from pwdlib import PasswordHash
from sqlalchemy.orm import Session

from application.auth.token_service import TokenService
from domain.exceptions import InvalidCurrentPassword, WeakPassword
from persistence.repositories.user_repository import UserRepository

MIN_PASSWORD_LENGTH = 8

password_hasher = PasswordHash.recommended()


class ChangePassword:
    def __init__(
        self,
        session: Session,
        users: UserRepository,
        tokens: TokenService,
        hasher: PasswordHash | None = None,
    ) -> None:
        self._session = session
        self._users = users
        self._tokens = tokens
        self._hasher = hasher or password_hasher

    def execute(
        self,
        *,
        user_id: int,
        email: str,
        installation_id: str,
        current_password: str,
        new_password: str,
    ) -> str:
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

        cutoff = self._users.revoke_sessions(user_id)
        if cutoff is None:
            raise InvalidCurrentPassword()

        self._session.commit()
        return self._tokens.create_access_token(
            user_id=user_id,
            email=email,
            installation_id=installation_id,
            issued_at=cutoff + timedelta(seconds=1),
        )

    @staticmethod
    def _validate_new_password(new_password: str, current_password: str) -> None:
        if len(new_password) < MIN_PASSWORD_LENGTH:
            raise WeakPassword()
        if new_password == current_password:
            raise WeakPassword(
                "La nueva contraseña debe ser distinta a la actual",
            )
