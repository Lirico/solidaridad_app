from application.payments.response_messages import message_for_code


def test_approved_default() -> None:
    assert message_for_code(None, approved=True) == "APROBADA"


def test_declined_known_code() -> None:
    assert (
        message_for_code("14", approved=False)
        == "TITULAR DESCONOCIDO / SUSPENDIDO"
    )
    assert message_for_code("13", approved=False) == "MONTO INVALIDO"
    assert message_for_code("65", approved=False) == "EXCEDE LIMITE PROPIO"
    assert message_for_code("77", approved=False) == "ERROR PLAN CUOTAS"
    assert message_for_code("89", approved=False) == "TERMINAL DESCONOCIDA"


def test_declined_unknown_code() -> None:
    assert message_for_code("99", approved=False) == "Pago rechazado"
    assert message_for_code("51", approved=False) == "Pago rechazado"


def test_declined_none_code() -> None:
    assert message_for_code(None, approved=False) == "Pago rechazado"
