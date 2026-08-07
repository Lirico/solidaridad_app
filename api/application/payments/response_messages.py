"""Map processor response codes to stable Spanish user messages."""

_MESSAGES: dict[str, str] = {
    "00": "Pago aprobado",
    "05": "Transacción no autorizada",
    "14": "Tarjeta inválida",
    "51": "Fondos insuficientes",
    "54": "Tarjeta vencida",
    "55": "CVV inválido",
    "57": "Transacción no permitida",
    "61": "Excede el límite",
    "65": "Excede frecuencia de uso",
    "91": "Emisor no disponible",
    "96": "Error del sistema",
}

MSG_PENDING = "Operación en curso, reintente en unos segundos"
MSG_FAILED = "No se pudo procesar el pago. Intente nuevamente."
MSG_UNKNOWN = (
    "No pudimos confirmar el pago. No vuelva a intentarlo; consulte la operación."
)
MSG_DECLINED_DEFAULT = "Pago rechazado"
MSG_VOIDED = "Anulación aprobada"
MSG_VOID_DECLINED = "Anulación rechazada"
MSG_VOID_UNKNOWN = (
    "No pudimos confirmar la anulación. Consulte el estado de la operación."
)
MSG_VOID_FAILED = "No se pudo anular. Intente nuevamente."


def message_for_code(response_code: str | None, *, approved: bool) -> str:
    if approved:
        return _MESSAGES.get(response_code or "00", "Pago aprobado")
    if response_code is None:
        return MSG_DECLINED_DEFAULT
    return _MESSAGES.get(response_code, MSG_DECLINED_DEFAULT)
