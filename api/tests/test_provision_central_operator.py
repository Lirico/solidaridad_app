from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest

from application.auth.provision_central_operator import ProvisionCentralOperator
from config import Settings
from domain.exceptions import (
    CentralOperatorProvisioningForbidden,
    EmailAlreadyExists,
)
from domain.user import User, UserRole


class _Hasher:
    def hash(self, password: str) -> str:
        return f"hash:{password}"


def _settings() -> Settings:
    return Settings(central_operator_provisioning_token="provision-secret")


def _user() -> User:
    now = datetime.now(UTC)
    return User(
        id=7,
        name="Central Ada",
        email="central@example.com",
        password_hash="hash:password123",
        must_change_password=True,
        created_at=now,
        updated_at=now,
        role=UserRole.CENTRAL_OPERATOR,
    )


def _use_case() -> tuple[ProvisionCentralOperator, MagicMock, MagicMock]:
    session = MagicMock()
    users = MagicMock()
    return (
        ProvisionCentralOperator(
            session=session,
            users=users,
            settings=_settings(),
            hasher=_Hasher(),  # type: ignore[arg-type]
        ),
        session,
        users,
    )


def test_provision_creates_only_central_operator() -> None:
    use_case, session, users = _use_case()
    users.get_by_email.return_value = None
    users.create.return_value = _user()

    result = use_case.execute(
        provisioning_token="provision-secret",
        name=" Central Ada ",
        email="CENTRAL@EXAMPLE.COM",
        password="password123",
    )

    assert result.email == "central@example.com"
    users.create.assert_called_once_with(
        name="Central Ada",
        email="central@example.com",
        password_hash="hash:password123",
        must_change_password=True,
        role=UserRole.CENTRAL_OPERATOR,
    )
    session.commit.assert_called_once_with()


@pytest.mark.parametrize("token", [None, "incorrect-token"])
def test_provision_rejects_missing_or_invalid_admin_token(token: str | None) -> None:
    use_case, session, users = _use_case()

    with pytest.raises(CentralOperatorProvisioningForbidden):
        use_case.execute(
            provisioning_token=token,
            name="Central Ada",
            email="central@example.com",
            password="password123",
        )

    users.create.assert_not_called()
    session.commit.assert_not_called()


def test_provision_rejects_existing_email() -> None:
    use_case, session, users = _use_case()
    users.get_by_email.return_value = _user()

    with pytest.raises(EmailAlreadyExists):
        use_case.execute(
            provisioning_token="provision-secret",
            name="Central Ada",
            email="central@example.com",
            password="password123",
        )

    users.create.assert_not_called()
    session.commit.assert_not_called()
