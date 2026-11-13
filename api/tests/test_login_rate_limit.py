"""Login failure window. Sales do not use this counter."""

from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest

from application.auth.login_rate_limit import LoginRateLimit
from config import Settings
from domain.exceptions import TooManyLoginAttempts


def _limiter(*, count: int) -> tuple[LoginRateLimit, MagicMock, MagicMock]:
    session = MagicMock()
    attempts = MagicMock()
    attempts.count_since.return_value = count
    limiter = LoginRateLimit(
        session=session,
        attempts=attempts,
        settings=Settings(login_max_failures=5, login_failure_window_minutes=15),
    )
    return limiter, attempts, session


def test_sixth_failure_in_the_window_is_rejected() -> None:
    limiter, attempts, session = _limiter(count=5)

    with pytest.raises(TooManyLoginAttempts, match="Demasiados intentos"):
        limiter.ensure_allowed(" Ada@Example.com ")

    attempts.count_since.assert_called_once()
    key, since = attempts.count_since.call_args.args
    assert key == "ada@example.com"
    assert since <= datetime.now(UTC)
    attempts.add.assert_not_called()
    session.commit.assert_not_called()


def test_fifth_failure_is_still_recorded() -> None:
    limiter, attempts, session = _limiter(count=4)

    limiter.ensure_allowed("ada@example.com")
    limiter.record_failure("ADA@example.com")

    attempts.add.assert_called_once()
    assert attempts.add.call_args.args[0] == "ada@example.com"
    session.commit.assert_called_once()


def test_successful_login_clears_the_counter() -> None:
    limiter, attempts, session = _limiter(count=2)

    limiter.clear(" ada@example.com ")

    attempts.delete_for.assert_called_once_with("ada@example.com")
    session.commit.assert_called_once()
