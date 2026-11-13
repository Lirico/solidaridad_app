"""JWT access token issuance and verification."""

from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import uuid4

import jwt

from config import Settings


class TokenService:
    def __init__(self, settings: Settings) -> None:
        self._secret = settings.jwt_secret
        self._algorithm = settings.jwt_algorithm
        self._expire_days = settings.jwt_expire_days

    def create_access_token(
        self,
        *,
        user_id: int,
        email: str,
        installation_id: str,
        issued_at: datetime | None = None,
    ) -> str:
        now = issued_at or datetime.now(UTC)
        if now.tzinfo is None:
            now = now.replace(tzinfo=UTC)
        now = now.astimezone(UTC).replace(microsecond=0)
        payload: dict[str, Any] = {
            "sub": str(user_id),
            "email": email,
            "installation_id": installation_id,
            "jti": str(uuid4()),
            "iat": now,
            "exp": now + timedelta(days=self._expire_days),
        }
        return jwt.encode(payload, self._secret, algorithm=self._algorithm)

    def verify(self, token: str) -> dict[str, Any]:
        """Decode and validate a JWT access token."""
        return jwt.decode(
            token,
            self._secret,
            algorithms=[self._algorithm],
        )
