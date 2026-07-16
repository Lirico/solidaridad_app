"""Unit tests for LoginUser use case."""

from datetime import UTC, datetime
from unittest.mock import MagicMock
from uuid import uuid4

import pytest

from application.auth.login_user import LoginUser
from domain.exceptions import InvalidCredentials, InvalidInstallationId
from domain.user import User


def _user(
    *,
    email: str = "ada@example.com",
    must_change_password: bool = True,
) -> User:
    now = datetime.now(UTC)
    return User(
        id=uuid4(),
        name="Ada",
        email=email,
        password_hash="hashed",
        must_change_password=must_change_password,
        created_at=now,
        updated_at=now,
    )


def _build_use_case(
    *,
    user: User | None = None,
) -> tuple[LoginUser, MagicMock, MagicMock, MagicMock, MagicMock, User | None]:
    session = MagicMock()
    users = MagicMock()
    installations = MagicMock()
    tokens = MagicMock()
    hasher = MagicMock()
    existing = user if user is not None else _user()

    users.get_by_email.return_value = existing
    hasher.verify.return_value = True
    tokens.create_access_token.return_value = "jwt-token"

    use_case = LoginUser(
        session=session,
        users=users,
        installations=installations,
        tokens=tokens,
        hasher=hasher,
    )
    return use_case, users, installations, tokens, hasher, existing


def test_login_user_success() -> None:
    existing = _user(email="ada@example.com", must_change_password=True)
    use_case, users, installations, tokens, _hasher, _ = _build_use_case(
        user=existing,
    )

    result = use_case.execute(
        username=" Ada@Example.com ",
        password="password1",
        installation_id=" inst-1 ",
    )

    assert result.name == "Ada"
    assert result.email == "ada@example.com"
    assert result.token == "jwt-token"
    assert result.must_change_password is True

    users.get_by_email.assert_called_once_with("ada@example.com")
    installations.upsert.assert_called_once_with("inst-1")
    tokens.create_access_token.assert_called_once_with(
        user_id=existing.id,
        email=existing.email,
        installation_id="inst-1",
    )


def test_login_user_rejects_unknown_email() -> None:
    use_case, users, installations, tokens, _hasher, _ = _build_use_case()
    users.get_by_email.return_value = None

    with pytest.raises(InvalidCredentials):
        use_case.execute(
            username="ghost@example.com",
            password="password1",
            installation_id="inst-1",
        )

    installations.upsert.assert_not_called()
    tokens.create_access_token.assert_not_called()


def test_login_user_rejects_bad_password() -> None:
    use_case, _users, installations, tokens, hasher, _ = _build_use_case()
    hasher.verify.return_value = False

    with pytest.raises(InvalidCredentials):
        use_case.execute(
            username="ada@example.com",
            password="wrong-pass",
            installation_id="inst-1",
        )

    installations.upsert.assert_not_called()
    tokens.create_access_token.assert_not_called()


def test_login_user_rejects_blank_installation_id() -> None:
    use_case, users, _installations, _tokens, _hasher, _ = _build_use_case()

    with pytest.raises(InvalidInstallationId):
        use_case.execute(
            username="ada@example.com",
            password="password1",
            installation_id="   ",
        )

    users.get_by_email.assert_not_called()
