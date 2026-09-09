"""Consultar saldo para todos los productos de una tarjeta.

El autorizador legacy solo devuelve el saldo de UN producto por consulta
(DE49), así que este caso de uso itera el catálogo y agrega una respuesta por
producto. Los productos sin saldo asignado (código 06) se listan con 0.
"""

import secrets
from dataclasses import dataclass

from application.payments.ports import (
    BalanceRequest,
    GatewayOutcome,
    PaymentGateway,
)
from application.payments.response_messages import (
    MSG_BALANCE_FAILED,
    MSG_BALANCE_OK,
    balance_message_for_code,
)
from domain.exceptions import (
    InvalidCardNumber,
    InvalidEntryMode,
    MissingTerminalId,
)
from domain.product import list_products, processor_product_code
from persistence.repositories.installation_repository import InstallationRepository


@dataclass(frozen=True, slots=True)
class BalanceItem:
    product: str
    label: str
    available_balance_minor: int


@dataclass(frozen=True, slots=True)
class CheckBalanceResult:
    status: str
    user_message: str
    balances: list[BalanceItem]


def _validate_pan(card_number: str) -> str:
    pan = card_number.replace(" ", "").strip()
    if not pan.isdigit() or not (13 <= len(pan) <= 19):
        raise InvalidCardNumber()
    return pan


class CheckBalance:
    def __init__(
        self,
        installations: InstallationRepository,
        gateway: PaymentGateway,
    ) -> None:
        self._installations = installations
        self._gateway = gateway

    def execute(
        self,
        *,
        installation_id: str,
        card_number: str,
        expiration_date: str | None = None,
        entry_mode: str = "012",
        track2: str | None = None,
    ) -> CheckBalanceResult:
        pan = _validate_pan(card_number)
        if entry_mode not in ("012", "022"):
            raise InvalidEntryMode()
        exp = expiration_date.strip() if expiration_date else None
        if exp == "":
            exp = None

        installation = self._installations.get_by_installation_id(installation_id)
        if installation is None:
            raise MissingTerminalId()
        terminal_id = installation.installation_id.strip()
        if not terminal_id:
            raise MissingTerminalId()

        balances: list[BalanceItem] = []
        any_success = False
        any_gateway_error = False
        hard_code: str | None = None

        for info in list_products(active_only=True):
            stan = f"{secrets.randbelow(1_000_000):06d}"
            result = self._gateway.balance(
                BalanceRequest(
                    product_code=processor_product_code(info.code),
                    card_number=pan,
                    terminal_id=terminal_id[:8].ljust(8),
                    stan=stan,
                    expiration_date=exp,
                    entry_mode=entry_mode,
                    track2=track2,
                )
            )

            if (
                result.outcome == GatewayOutcome.APPROVED
                and result.available_balance_minor is not None
            ):
                any_success = True
                balances.append(
                    BalanceItem(
                        product=info.code.value,
                        label=info.label,
                        available_balance_minor=result.available_balance_minor,
                    )
                )
            elif result.response_code == "06":
                # Producto sin saldo asignado: tarjeta válida, saldo 0.
                any_success = True
                balances.append(
                    BalanceItem(
                        product=info.code.value,
                        label=info.label,
                        available_balance_minor=0,
                    )
                )
            elif result.outcome == GatewayOutcome.DECLINED:
                hard_code = hard_code or result.response_code
            else:
                any_gateway_error = True

        if any_success:
            return CheckBalanceResult(
                status="APPROVED",
                user_message=MSG_BALANCE_OK,
                balances=balances,
            )

        if any_gateway_error:
            return CheckBalanceResult(
                status="FAILED",
                user_message=MSG_BALANCE_FAILED,
                balances=[],
            )

        return CheckBalanceResult(
            status="DECLINED",
            user_message=balance_message_for_code(hard_code),
            balances=[],
        )
