"""Map processor response codes to the client's response catalog."""

MSG_APPROVED = "Aprobada"

# Descripción del catálogo de respuestas del cliente, en el mismo registro
# que el resto de los mensajes de la app. Los códigos que ese catálogo no
# lista quedan en el texto genérico de rechazo.
_MESSAGES: dict[str, str] = {
    "00": MSG_APPROVED,
    "03": "Comercio desconocido / suspendido",
    "04": "Titular en boletín",
    "05": "Transacción denegada",
    "06": "Tipo de transacción desconocido",
    "07": "Retenga y llame",
    "13": "Monto inválido",
    "14": "Titular desconocido / suspendido",
    "15": "Nro. documento desconocido",
    "16": "Error en fecha desde",
    "17": "Cupón duplicado",
    "18": "Error en dígito verificador",
    "19": "Error en grabación",
    "21": "Cuotas excede tope del comercio",
    "23": "Error en cantidad de cuotas",
    "25": "Anulación desconocida",
    "30": "Error en formato",
    "31": "Plan 1, error fechas promoción",
    "38": "Comercio suspendido",
    "40": "Falta boletín",
    "41": "Retenga y llame",
    "48": "Cuotas excede tope comercio",
    "49": "Error en fecha de vencimiento",
    "53": "Comercio fidelidad desconocido",
    "54": "Tarjeta vencida",
    "61": "Falta / excede límite",
    "65": "Excede límite propio",
    "76": "No encontró registro al anular",
    "77": "Error plan cuotas",
    "78": "Anulación desconocida",
    "80": "No tiene movimientos al cerrar cajero",
    "89": "Terminal desconocida",
    "91": "Emisor fuera de línea",
    "95": "Cierre con diferencia",
}

MSG_PENDING = "Operación en curso, reintente en unos segundos"
MSG_FAILED = "No se pudo procesar el pago. Intente nuevamente."
MSG_UNKNOWN = (
    "No pudimos confirmar el pago. No vuelva a intentarlo; consulte la operación."
)
MSG_UNDER_REVIEW = (
    "No fue posible confirmar el resultado. Verifique la operación con casa "
    "central ante un posible cobro duplicado."
)
MSG_DECLINED_DEFAULT = "Pago rechazado"
MSG_VOIDED = "Anulación aprobada"
MSG_VOID_DECLINED = "Anulación rechazada"
MSG_VOID_UNKNOWN = (
    "No pudimos confirmar la anulación. Consulte el estado de la operación."
)
MSG_VOID_FAILED = "No se pudo anular. Intente nuevamente."

MSG_BALANCE_OK = "Consulta de saldo exitosa"
MSG_BALANCE_DECLINED_DEFAULT = "No se pudo consultar el saldo"
MSG_BALANCE_FAILED = "No se pudo consultar el saldo. Intente nuevamente."


def message_for_code(response_code: str | None, *, approved: bool) -> str:
    if approved:
        return _MESSAGES.get(response_code or "00", MSG_APPROVED)
    if response_code is None:
        return MSG_DECLINED_DEFAULT
    return _MESSAGES.get(response_code, MSG_DECLINED_DEFAULT)


def balance_message_for_code(response_code: str | None) -> str:
    if response_code is None:
        return MSG_BALANCE_DECLINED_DEFAULT
    return _MESSAGES.get(response_code, MSG_BALANCE_DECLINED_DEFAULT)
