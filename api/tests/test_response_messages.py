from application.payments.response_messages import message_for_code


def test_approved_default() -> None:
    assert message_for_code(None, approved=True) == "Pago aprobado"


def test_declined_known_code() -> None:
    assert message_for_code("51", approved=False) == "Fondos insuficientes"


def test_declined_unknown_code() -> None:
    assert message_for_code("77", approved=False) == "Pago rechazado"


def test_declined_none_code() -> None:
    assert message_for_code(None, approved=False) == "Pago rechazado"
