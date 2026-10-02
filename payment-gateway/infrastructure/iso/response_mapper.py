"""Map ISO response codes to domain authorization results."""

from domain.authorization import AuthorizationResult, AuthorizationStatus
from domain.balance import BalanceResult
from infrastructure.iso.packer import IsoMessage

_APPROVED_CODES = frozenset({"00", "08", "10", "11", "85"})

_MESSAGES: dict[str, str] = {
    "00": "Aprobada",
    "05": "Denegada",
    "12": "Transacción inválida",
    "13": "Monto inválido",
    "14": "Tarjeta inválida",
    "17": "Cupón duplicado",
    "19": "Error al registrar la operación",
    "25": "Operación no encontrada",
    "30": "Error de formato",
    "51": "Fondos insuficientes",
    "54": "Tarjeta vencida",
    "89": "Terminal desconocida",
    "91": "Emisor no disponible",
    "95": "Diferencia de cierre",
}


def _classify_response(iso: IsoMessage) -> tuple[AuthorizationStatus, str, str]:
    """Derive (status, response_code, user_message) from DE39/DE63."""
    code = (iso.respcode_39 or "").strip() or "96"
    if code in _APPROVED_CODES:
        status = AuthorizationStatus.APPROVED
    else:
        status = AuthorizationStatus.DECLINED
    message = _MESSAGES.get(
        code, iso.field_63.strip() if iso.field_63 else "Rechazada"
    )
    return status, code, message


def map_iso_response(iso: IsoMessage) -> AuthorizationResult:
    status, code, message = _classify_response(iso)
    return AuthorizationResult(
        status=status,
        response_code=code,
        user_message=message,
        auth_id=iso.authid_38.strip() or None,
        retrieval_reference=iso.retrefnum_37.strip() or None,
    )


def map_balance_response(iso: IsoMessage) -> BalanceResult:
    """Map a 0100 response to a balance result.

    El saldo viene en DE4 (amount_4) como 12 dígitos con 2 decimales implícitos
    (p. ej. "000000010000" → 100.00). DE63 trae los productos asignados.
    """
    status, code, message = _classify_response(iso)

    available_balance_minor: int | None = None
    amount = iso.amount_4.strip()
    if amount.isdigit():
        available_balance_minor = int(amount)

    return BalanceResult(
        status=status,
        response_code=code,
        user_message=message,
        available_balance_minor=available_balance_minor,
        assigned_products=iso.field_63.strip() or None,
    )
