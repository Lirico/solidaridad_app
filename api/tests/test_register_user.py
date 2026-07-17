"""Unit tests for RegisterUser use case."""

from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest

from application.auth.register_user import RegisterUser
from domain.exceptions import EmailAlreadyExists, WeakPassword
from domain.user import User


def _user(*, email: str = "new@example.com") -> User:
    now = datetime.now(UTC)
    return User(
        id=1,
        name="Ada",
        email=email,
        password_hash="hashed",
        must_change_password=False,
        created_at=now,
        updated_at=now,
    )


def _build_use_case(
    *,
    existing: User | None = None,
    created: User | None = None,
) -> tuple[RegisterUser, MagicMock, MagicMock, MagicMock]:
    session = MagicMock()
    users = MagicMock()
    installations = MagicMock()
    tokens = MagicMock()
    hasher = MagicMock()

    users.get_by_email.return_value = existing
    users.create.return_value = created or _user()
    hasher.hash.return_value = "argon2-hash"
    tokens.create_access_token.return_value = "jwt-token"

    use_case = RegisterUser(
        session=session,
        users=users,
        installations=installations,
        tokens=tokens,
        hasher=hasher,
    )
    return use_case, users, installations, tokens


def test_register_user_success() -> None:
    created = _user(email="ada@example.com")
    use_case, users, installations, tokens = _build_use_case(created=created)

    result = use_case.execute(
        name=" Ada ",
        email="Ada@Example.com",
        password="password1",
        installation_id=" inst-1 ",
    )

    assert result.name == "Ada"
    assert result.email == "ada@example.com"
    assert result.token == "jwt-token"
    assert result.must_change_password is False

    users.get_by_email.assert_called_once_with("ada@example.com")
    users.create.assert_called_once()
    create_kwargs = users.create.call_args.kwargs
    assert create_kwargs["name"] == "Ada"
    assert create_kwargs["email"] == "ada@example.com"
    assert create_kwargs["password_hash"] == "argon2-hash"
    assert create_kwargs["must_change_password"] is False

    installations.upsert.assert_called_once_with("inst-1")
    tokens.create_access_token.assert_called_once_with(
        user_id=created.id,
        email=created.email,
        installation_id="inst-1",
    )


def test_register_user_rejects_duplicate_email() -> None:
    use_case, users, installations, _tokens = _build_use_case(
        existing=_user(email="ada@example.com"),
    )

    with pytest.raises(EmailAlreadyExists):
        use_case.execute(
            name="Ada",
            email="ada@example.com",
            password="password1",
            installation_id="inst-1",
        )

    users.create.assert_not_called()
    installations.upsert.assert_not_called()


def test_register_user_rejects_short_password() -> None:
    use_case, users, _installations, _tokens = _build_use_case()

    with pytest.raises(WeakPassword):
        use_case.execute(
            name="Ada",
            email="ada@example.com",
            password="short",
            installation_id="inst-1",
        )

    users.get_by_email.assert_not_called()
