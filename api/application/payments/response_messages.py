"""Map processor response codes to the client's response catalog."""

MSG_APPROVED = "APROBADA"

# Descripción del catálogo de respuestas del cliente. Los códigos que ese
# catálogo no lista quedan en el texto genérico de rechazo.
_MESSAGES: dict[str, str] = {
    "00": MSG_APPROVED,
    "03": "COMERCIO DESCONOCIDO / SUSPENDIDO",
    "04": "TITULAR EN BOLETIN",
    "05": "TRANSACCION DENEGADA",
    "06": "TIPO DE TRANSACCION DESCONOCIDO",
    "07": "RETENGA Y LLAME",
    "13": "MONTO INVALIDO",
    "14": "TITULAR DESCONOCIDO / SUSPENDIDO",
    "15": "NRO DOCUMENTO DESCONOCIDO",
    "16": "ERROR EN FECHA DESDE",
    "17": "CUPON DUPLICADO",
    "18": "ERROR EN DIGITO VERIFICADOR",
    "19": "ERROR EN GRABACION",
    "21": "CUOTAS EXCEDE TOPE DEL COMERCIO",
    "23": "ERROR EN CANTIDAD DE CUOTAS",
    "25": "ANULACION DESCONOCIDA",
    "30": "ERROR EN FORMATO",
    "31": "PLAN 1, ERROR FECHAS PROMOCION",
    "38": "COMERCIO SUSPENDIDO",
    "40": "FALTA BOLETIN",
    "41": "RETENGA Y LLAME",
    "48": "CUOTAS EXCEDE TOPE COMERCIO",
    "49": "ERROR EN FECHA DE VENCIMIENTO",
    "53": "COMERCIO FIDELIDAD DESCONOCIDO",
    "54": "TARJETA VENCIDA",
    "61": "FALTA / EXCEDE LIMITE",
    "65": "EXCEDE LIMITE PROPIO",
    "76": "NO ENCONTRO REGISTRO AL ANULAR",
    "77": "ERROR PLAN CUOTAS",
    "78": "ANULACION DESCONOCIDA",
    "80": "NO TIENE MOVIMIENTOS AL CERRAR CAJERO",
    "89": "TERMINAL DESCONOCIDA",
    "91": "EMISOR FUERA DE LINEA",
    "95": "CIERRE CON DIFERENCIA",
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
