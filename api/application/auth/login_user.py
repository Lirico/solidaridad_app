"""Authenticate an existing user and issue an access token."""

from dataclasses import dataclass

from pwdlib import PasswordHash
from sqlalchemy.orm import Session

from application.auth.token_service import TokenService
from domain.exceptions import InvalidCredentials, InvalidInstallationId
from persistence.repositories.installation_repository import InstallationRepository
from persistence.repositories.user_repository import UserRepository

MAX_INSTALLATION_ID_LENGTH = 128

password_hasher = PasswordHash.recommended()


@dataclass(frozen=True, slots=True)
class LoginResult:
    name: str
    email: str
    token: str
    must_change_password: bool


class LoginUser:
    def __init__(
        self,
        session: Session,
        users: UserRepository,
        installations: InstallationRepository,
        tokens: TokenService,
        hasher: PasswordHash | None = None,
    ) -> None:
        self._session = session
        self._users = users
        self._installations = installations
        self._tokens = tokens
        self._hasher = hasher or password_hasher

    def execute(
        self,
        *,
        username: str,
        password: str,
        installation_id: str,
    ) -> LoginResult:
        normalized_email = username.strip().lower()
        normalized_installation_id = installation_id.strip()

        self._validate_installation_id(normalized_installation_id)

        user = self._users.get_by_email(normalized_email)
        if user is None or not self._hasher.verify(password, user.password_hash):
            raise InvalidCredentials()

        self._installations.upsert(normalized_installation_id)
        self._session.commit()

        token = self._tokens.create_access_token(
            user_id=user.id,
            email=user.email,
            installation_id=normalized_installation_id,
        )
        return LoginResult(
            name=user.name,
            email=user.email,
            token=token,
            must_change_password=user.must_change_password,
        )

    @staticmethod
    def _validate_installation_id(installation_id: str) -> None:
        if not installation_id:
            raise InvalidInstallationId()
        if len(installation_id) > MAX_INSTALLATION_ID_LENGTH:
            max_len = MAX_INSTALLATION_ID_LENGTH
            raise InvalidInstallationId(
                f"installation_id no puede superar {max_len} caracteres"
            )
