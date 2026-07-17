"""Unit tests for ChangePassword use case."""

from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest

from application.auth.change_password import ChangePassword
from domain.exceptions import InvalidCurrentPassword, WeakPassword
from domain.user import User


def _user(*, must_change_password: bool = True) -> User:
    now = datetime.now(UTC)
    return User(
        id=1,
        name="Ada",
        email="ada@example.com",
        password_hash="hashed-current",
        must_change_password=must_change_password,
        created_at=now,
        updated_at=now,
    )


def _build_use_case(
    *,
    user: User | None = None,
) -> tuple[ChangePassword, MagicMock, MagicMock, User | None]:
    session = MagicMock()
    users = MagicMock()
    hasher = MagicMock()
    existing = user if user is not None else _user()

    users.get_by_id.return_value = existing
    users.update_password.return_value = existing
    hasher.verify.return_value = True
    hasher.hash.return_value = "hashed-new"

    use_case = ChangePassword(
        session=session,
        users=users,
        hasher=hasher,
    )
    return use_case, users, hasher, existing


def test_change_password_success_clears_must_change_flag() -> None:
    use_case, users, hasher, user = _build_use_case()
    assert user is not None

    use_case.execute(
        user_id=user.id,
        current_password="current12",
        new_password="newpass12",
    )

    hasher.verify.assert_called_once_with("current12", "hashed-current")
    hasher.hash.assert_called_once_with("newpass12")
    users.update_password.assert_called_once_with(
        user.id,
        password_hash="hashed-new",
        must_change_password=False,
    )


def test_change_password_rejects_wrong_current() -> None:
    use_case, users, hasher, user = _build_use_case()
    assert user is not None
    hasher.verify.return_value = False

    with pytest.raises(InvalidCurrentPassword):
        use_case.execute(
            user_id=user.id,
            current_password="wrong-pass",
            new_password="newpass12",
        )

    users.update_password.assert_not_called()


def test_change_password_rejects_missing_user() -> None:
    use_case, users, _hasher, _user = _build_use_case()
    users.get_by_id.return_value = None
    user_id = 999

    with pytest.raises(InvalidCurrentPassword):
        use_case.execute(
            user_id=user_id,
            current_password="current12",
            new_password="newpass12",
        )

    users.update_password.assert_not_called()


def test_change_password_rejects_short_new_password() -> None:
    use_case, users, _hasher, user = _build_use_case()
    assert user is not None

    with pytest.raises(WeakPassword):
        use_case.execute(
            user_id=user.id,
            current_password="current12",
            new_password="short",
        )

    users.get_by_id.assert_not_called()


def test_change_password_rejects_same_as_current() -> None:
    use_case, users, _hasher, user = _build_use_case()
    assert user is not None

    with pytest.raises(WeakPassword, match="distinta"):
        use_case.execute(
            user_id=user.id,
            current_password="samepass1",
            new_password="samepass1",
        )

    users.get_by_id.assert_not_called()
