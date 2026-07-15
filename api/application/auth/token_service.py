"""JWT access token issuance and verification."""

from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID, uuid4

import jwt

from config import Settings


class TokenService:
    def __init__(self, settings: Settings) -> None:
        self._secret = settings.jwt_secret
        self._algorithm = settings.jwt_algorithm
        self._expire_minutes = settings.jwt_expire_minutes

    def create_access_token(
        self,
        *,
        user_id: UUID,
        email: str,
        installation_id: str,
    ) -> str:
        now = datetime.now(UTC)
        payload: dict[str, Any] = {
            "sub": str(user_id),
            "email": email,
            "installation_id": installation_id,
            "jti": str(uuid4()),
            "iat": now,
            "exp": now + timedelta(minutes=self._expire_minutes),
        }
        return jwt.encode(payload, self._secret, algorithm=self._algorithm)

    def verify(self, token: str) -> dict[str, Any]:
        """Decode and validate a JWT. Used by Phase 3 Bearer dependency."""
        return jwt.decode(
            token,
            self._secret,
            algorithms=[self._algorithm],
        )
