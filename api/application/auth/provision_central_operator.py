"""Explicit administrative provisioning for central recovery operators."""

from dataclasses import dataclass
from secrets import compare_digest

from pwdlib import PasswordHash
from sqlalchemy.orm import Session

from application.auth.register_user import MIN_PASSWORD_LENGTH, password_hasher
from config import Settings
from domain.exceptions import (
    CentralOperatorProvisioningForbidden,
    EmailAlreadyExists,
    WeakPassword,
)
from domain.user import UserRole
from persistence.repositories.user_repository import UserRepository


@dataclass(frozen=True, slots=True)
class ProvisionCentralOperatorResult:
    name: str
    email: str


class ProvisionCentralOperator:
    """Create only CENTRAL_OPERATOR accounts through a configured admin secret."""

    def __init__(
        self,
        *,
        session: Session,
        users: UserRepository,
        settings: Settings,
        hasher: PasswordHash | None = None,
    ) -> None:
        self._session = session
        self._users = users
        self._provisioning_token = settings.central_operator_provisioning_token
        self._hasher = hasher or password_hasher

    def execute(
        self,
        *,
        provisioning_token: str | None,
        name: str,
        email: str,
        password: str,
    ) -> ProvisionCentralOperatorResult:
        configured_token = self._provisioning_token
        if (
            not configured_token
            or provisioning_token is None
            or not compare_digest(provisioning_token, configured_token)
        ):
            raise CentralOperatorProvisioningForbidden()
        if len(password) < MIN_PASSWORD_LENGTH:
            raise WeakPassword()

        normalized_email = email.strip().lower()
        if self._users.get_by_email(normalized_email) is not None:
            raise EmailAlreadyExists(normalized_email)

        user = self._users.create(
            name=name.strip(),
            email=normalized_email,
            password_hash=self._hasher.hash(password),
            must_change_password=True,
            role=UserRole.CENTRAL_OPERATOR,
        )
        self._session.commit()
        return ProvisionCentralOperatorResult(name=user.name, email=user.email)
