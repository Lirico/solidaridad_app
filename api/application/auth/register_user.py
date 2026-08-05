"""Register a new user and issue an access token."""

from dataclasses import dataclass

from pwdlib import PasswordHash
from sqlalchemy.orm import Session

from application.auth.token_service import TokenService
from domain.exceptions import EmailAlreadyExists, WeakPassword
from persistence.repositories.installation_repository import InstallationRepository
from persistence.repositories.user_repository import UserRepository

MIN_PASSWORD_LENGTH = 8

password_hasher = PasswordHash.recommended()


@dataclass(frozen=True, slots=True)
class RegisterResult:
    name: str
    email: str
    token: str
    must_change_password: bool


class RegisterUser:
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
        name: str,
        email: str,
        password: str,
        installation_id: str,
    ) -> RegisterResult:
        normalized_email = email.strip().lower()
        normalized_name = name.strip()
        normalized_installation_id = installation_id.strip()

        self._validate_password(password)

        if self._users.get_by_email(normalized_email) is not None:
            raise EmailAlreadyExists(normalized_email)

        user = self._users.create(
            name=normalized_name,
            email=normalized_email,
            password_hash=self._hasher.hash(password),
            must_change_password=True,
        )
        self._installations.upsert(normalized_installation_id)
        self._session.commit()

        token = self._tokens.create_access_token(
            user_id=user.id,
            email=user.email,
            installation_id=normalized_installation_id,
        )
        return RegisterResult(
            name=user.name,
            email=user.email,
            token=token,
            must_change_password=user.must_change_password,
        )

    @staticmethod
    def _validate_password(password: str) -> None:
        if len(password) < MIN_PASSWORD_LENGTH:
            raise WeakPassword()
