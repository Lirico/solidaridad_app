"""Map ISO response codes to domain authorization results."""

from domain.authorization import AuthorizationResult, AuthorizationStatus
from infrastructure.iso.packer import IsoMessage

_APPROVED_CODES = frozenset({"00", "08", "10", "11", "85"})

_MESSAGES: dict[str, str] = {
    "00": "Aprobada",
    "05": "Denegada",
    "12": "Transacción inválida",
    "13": "Monto inválido",
    "14": "Tarjeta inválida",
    "30": "Error de formato",
    "51": "Fondos insuficientes",
    "54": "Tarjeta vencida",
    "91": "Emisor no disponible",
}


def map_iso_response(iso: IsoMessage) -> AuthorizationResult:
    code = (iso.respcode_39 or "").strip() or "96"
    if code in _APPROVED_CODES:
        status = AuthorizationStatus.APPROVED
    else:
        status = AuthorizationStatus.DECLINED
    message = _MESSAGES.get(code, iso.field_63.strip() if iso.field_63 else "Rechazada")
    return AuthorizationResult(
        status=status,
        response_code=code,
        user_message=message,
        auth_id=iso.authid_38.strip() or None,
        retrieval_reference=iso.retrefnum_37.strip() or None,
    )
