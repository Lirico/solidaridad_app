"""Mock ISO processor for local development without authkig."""

from domain.authorization import (
    AuthorizationResult,
    AuthorizationStatus,
    AuthorizeCommand,
    VoidCommand,
)


class MockIsoProcessor:
    """Approves unless PAN is the known decline test card."""

    DECLINE_PAN = "4000000000000002"

    def authorize(self, command: AuthorizeCommand) -> AuthorizationResult:
        if command.card_number == self.DECLINE_PAN:
            return AuthorizationResult(
                status=AuthorizationStatus.DECLINED,
                response_code="05",
                user_message="Denegada",
                auth_id=None,
                retrieval_reference=None,
            )
        return AuthorizationResult(
            status=AuthorizationStatus.APPROVED,
            response_code="00",
            user_message="Aprobada",
            auth_id="MOCK01",
            retrieval_reference=command.stan.zfill(12),
        )

    def void(self, command: VoidCommand) -> AuthorizationResult:
        if command.card_number == self.DECLINE_PAN:
            return AuthorizationResult(
                status=AuthorizationStatus.DECLINED,
                response_code="05",
                user_message="Denegada",
                auth_id=None,
                retrieval_reference=None,
            )
        return AuthorizationResult(
            status=AuthorizationStatus.APPROVED,
            response_code="00",
            user_message="Aprobada",
            auth_id="MOCKVD",
            retrieval_reference=command.stan.zfill(12),
        )
