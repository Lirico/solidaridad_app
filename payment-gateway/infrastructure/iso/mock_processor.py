"""Mock ISO processor for local development without authkig."""

from domain.authorization import (
    AuthorizationResult,
    AuthorizationStatus,
    AuthorizeCommand,
    VoidCommand,
)
from domain.balance import BalanceCommand, BalanceResult
from domain.reversal import ReversalResult, ReversalStatus, ReverseCommand
from infrastructure.iso.audit_log import log_iso_exchange
from infrastructure.iso.packer import IsoMessage


class MockIsoProcessor:
    """Approves unless PAN is the known decline test card."""

    DECLINE_PAN = "4000000000000002"

    def authorize(self, command: AuthorizeCommand) -> AuthorizationResult:
        if command.card_number == self.DECLINE_PAN:
            result = AuthorizationResult(
                status=AuthorizationStatus.DECLINED,
                response_code="05",
                user_message="Denegada",
                auth_id=None,
                retrieval_reference=None,
            )
        else:
            result = AuthorizationResult(
                status=AuthorizationStatus.APPROVED,
                response_code="00",
                user_message="Aprobada",
                auth_id="MOCK01",
                retrieval_reference=command.stan.zfill(12),
            )
        self._audit(
            operation="authorize",
            mti="0200",
            response_mti="0210",
            card_number=command.card_number,
            terminal_id=command.terminal_id,
            merchant_code=command.merchant_code,
            amount_minor=command.amount_minor,
            stan=command.stan,
            response_code=result.response_code,
            auth_id=result.auth_id,
            retrieval_reference=result.retrieval_reference,
        )
        return result

    def void(self, command: VoidCommand) -> AuthorizationResult:
        if command.card_number == self.DECLINE_PAN:
            result = AuthorizationResult(
                status=AuthorizationStatus.DECLINED,
                response_code="05",
                user_message="Denegada",
                auth_id=None,
                retrieval_reference=None,
            )
        else:
            result = AuthorizationResult(
                status=AuthorizationStatus.APPROVED,
                response_code="00",
                user_message="Aprobada",
                auth_id="MOCKVD",
                retrieval_reference=command.stan.zfill(12),
            )
        self._audit(
            operation="void",
            mti="0200",
            response_mti="0210",
            card_number=command.card_number,
            terminal_id=command.terminal_id,
            merchant_code=command.merchant_code,
            amount_minor=command.amount_minor,
            stan=command.stan,
            response_code=result.response_code,
            auth_id=result.auth_id,
            retrieval_reference=result.retrieval_reference,
        )
        return result

    def reverse(self, command: ReverseCommand) -> ReversalResult:
        if command.card_number == self.DECLINE_PAN:
            result = ReversalResult(
                status=ReversalStatus.PROCESSOR_DECLINED,
                response_code="05",
                user_message="Denegada",
            )
        else:
            result = ReversalResult(
                status=ReversalStatus.REVERSED_CONFIRMED,
                response_code="00",
                user_message="Reverso aceptado",
            )
        self._audit(
            operation="reverse",
            mti="0400",
            response_mti="0410",
            card_number=command.card_number,
            terminal_id=command.terminal_id,
            merchant_code=command.merchant_code,
            amount_minor=command.amount_minor,
            stan=command.original_stan,
            response_code=result.response_code,
        )
        return result

    def balance(self, command: BalanceCommand) -> BalanceResult:
        if command.card_number == self.DECLINE_PAN:
            result = BalanceResult(
                status=AuthorizationStatus.DECLINED,
                response_code="05",
                user_message="Denegada",
            )
        else:
            result = BalanceResult(
                status=AuthorizationStatus.APPROVED,
                response_code="00",
                user_message="Aprobada",
                available_balance_minor=100000,
                assigned_products=(
                    "Tipo de asignacion: Garrafa 10 kg Garrafa 15 kg "
                    "Garrafa 30 kg Tubo 45 kg Granel"
                ),
            )
        self._audit(
            operation="balance",
            mti="0100",
            response_mti="0110",
            card_number=command.card_number,
            terminal_id=command.terminal_id,
            merchant_code=command.merchant_code,
            stan=command.stan,
            response_code=result.response_code,
        )
        return result

    def _audit(
        self,
        *,
        operation: str,
        mti: str,
        response_mti: str,
        card_number: str,
        terminal_id: str,
        merchant_code: str,
        response_code: str,
        amount_minor: int | None = None,
        stan: str | None = None,
        auth_id: str | None = None,
        retrieval_reference: str | None = None,
    ) -> None:
        log_iso_exchange(
            operation=operation,
            transport="mock",
            request=IsoMessage(
                mtype=mti,
                pan_2=card_number,
                amount_4="" if amount_minor is None else f"{amount_minor:012d}",
                systracenum_11=stan or "",
                termid_41=terminal_id,
                merchid_42=merchant_code,
            ),
            outcome="sent",
            response_mti=response_mti,
            response_code=response_code,
            auth_id=auth_id,
            retrieval_reference=retrieval_reference,
        )
