from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest

from application.payments.create_transaction import (
    CreateTransaction,
    CreateTransactionHttpStatus,
)
from application.payments.ports import AuthorizeResult, GatewayOutcome
from domain.exceptions import (
    IdempotencyConflict,
    InvalidCardNumber,
    MissingIdempotencyKey,
    MissingTerminalId,
)
from domain.installation import Installation
from domain.product import Product
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus


def _tx(**overrides: object) -> Transaction:
    base = dict(
        id=1,
        transaction_number="OP-260716-00000001",
        user_id=1,
        installation_id=10,
        terminal_id="05000001",
        product=Product.GARRAFA_10,
        processor_product_code="993",
        amount_minor=150,
        status=TransactionStatus.APPROVED,
        card_last4="1111",
        stan="000001",
        auth_id="AUTH01",
        retrieval_reference="RRN001",
        processor_response_code="00",
        user_message="Pago aprobado",
        idempotency_key="key-1",
        request_fingerprint="",
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
    )
    base.update(overrides)
    return Transaction(**base)  # type: ignore[arg-type]


def _build(
    *,
    existing: Transaction | None = None,
    gateway_result: AuthorizeResult | None = None,
    installation_code: str | None = "05000001",
) -> tuple[CreateTransaction, MagicMock, MagicMock, MagicMock]:
    session = MagicMock()
    transactions = MagicMock()
    installations = MagicMock()
    gateway = MagicMock()

    transactions.get_by_idempotency.return_value = existing
    installations.get_by_installation_id.return_value = (
        Installation(
            id=10,
            installation_id=installation_code,
            platform="local",
            last_seen_at=datetime.now(UTC),
            created_at=datetime.now(UTC),
        )
        if installation_code is not None
        else None
    )
    transactions.next_transaction_number.return_value = "OP-260716-00000001"
    pending = _tx(status=TransactionStatus.PENDING, user_message="pending")
    # fingerprint filled by use case after create; for create path we stub update
    transactions.create_pending.return_value = pending
    final = _tx(status=TransactionStatus.APPROVED)
    transactions.update_result.return_value = final
    gateway.authorize.return_value = gateway_result or AuthorizeResult(
        outcome=GatewayOutcome.APPROVED,
        response_code="00",
        auth_id="A1",
        retrieval_reference="R1",
    )

    use_case = CreateTransaction(
        session=session,
        transactions=transactions,
        installations=installations,
        gateway=gateway,
    )
    return use_case, transactions, installations, gateway


def test_create_approves() -> None:
    use_case, transactions, _, gateway = _build()
    result = use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="k1",
        product="GARRAFA_10",
        amount="1.50",
        card_number="4111111111111111",
        cvv="123",
    )
    assert result.http_status == CreateTransactionHttpStatus.CREATED
    assert result.transaction.status == TransactionStatus.APPROVED
    gateway.authorize.assert_called_once()
    auth_req = gateway.authorize.call_args.args[0]
    assert auth_req.ticket_number == "00000001"
    transactions.create_pending.assert_called_once()
    create_kwargs = transactions.create_pending.call_args.kwargs
    assert create_kwargs["processor_ticket"] == "00000001"
    transactions.update_result.assert_called_once()


def test_missing_idempotency_key() -> None:
    use_case, *_ = _build()
    with pytest.raises(MissingIdempotencyKey):
        use_case.execute(
            user_id=1,
            installation_id="inst-1",
            idempotency_key=None,
            product="GARRAFA_10",
            amount="1.50",
            card_number="4111111111111111",
            cvv="123",
        )


def test_invalid_pan() -> None:
    use_case, *_ = _build()
    with pytest.raises(InvalidCardNumber):
        use_case.execute(
            user_id=1,
            installation_id="inst-1",
            idempotency_key="k1",
            product="GARRAFA_10",
            amount="1.50",
            card_number="606300101400740X",
            cvv="123",
        )


def test_processor_pan_without_luhn_is_accepted() -> None:
    use_case, transactions, _, gateway = _build()
    result = use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="k1",
        product="GARRAFA_10",
        amount="1.50",
        card_number="6063001014007403",
        cvv="123",
    )
    assert result.http_status == CreateTransactionHttpStatus.CREATED
    assert result.transaction.status == TransactionStatus.APPROVED
    gateway.authorize.assert_called_once()
    transactions.update_result.assert_called_once()


def test_missing_terminal() -> None:
    use_case, *_ = _build(installation_code=None)
    with pytest.raises(MissingTerminalId):
        use_case.execute(
            user_id=1,
            installation_id="inst-1",
            idempotency_key="k1",
            product="GARRAFA_10",
            amount="1.50",
            card_number="4111111111111111",
            cvv="123",
        )


def test_replay_pending_returns_202() -> None:
    # fingerprint for GARRAFA_10|150|1111|
    from application.payments.create_transaction import _fingerprint

    fp = _fingerprint(
        product=Product.GARRAFA_10,
        amount_minor=150,
        card_last4="1111",
        expiration_date=None,
    )
    existing = _tx(status=TransactionStatus.PENDING, request_fingerprint=fp)

    use_case, transactions, _, gateway = _build(existing=existing)
    result = use_case.execute(
        user_id=existing.user_id,
        installation_id="inst-1",
        idempotency_key="key-1",
        product="GARRAFA_10",
        amount="1.50",
        card_number="4111111111111111",
        cvv="123",
    )
    assert result.http_status == CreateTransactionHttpStatus.ACCEPTED
    assert result.transaction.status == TransactionStatus.PENDING
    gateway.authorize.assert_not_called()
    transactions.create_pending.assert_not_called()
    transactions.record_idempotent_hit.assert_called_once()
    session = use_case._session
    session.commit.assert_called()


def test_replay_approved_returns_201_without_gateway() -> None:
    from application.payments.create_transaction import _fingerprint

    fp = _fingerprint(
        product=Product.GARRAFA_10,
        amount_minor=150,
        card_last4="1111",
        expiration_date=None,
    )
    existing = _tx(status=TransactionStatus.APPROVED, request_fingerprint=fp)
    use_case, transactions, _, gateway = _build(existing=existing)
    result = use_case.execute(
        user_id=existing.user_id,
        installation_id="inst-1",
        idempotency_key="key-1",
        product="GARRAFA_10",
        amount="1.50",
        card_number="4111111111111111",
        cvv="123",
    )
    assert result.http_status == CreateTransactionHttpStatus.CREATED
    assert result.transaction.status == TransactionStatus.APPROVED
    gateway.authorize.assert_not_called()
    transactions.record_idempotent_hit.assert_called_once_with(
        transaction_id=existing.id,
        status=TransactionStatus.APPROVED,
        actor_user_id=existing.user_id,
        idempotency_key="key-1",
        user_message=existing.user_message,
        processor_response_code=existing.processor_response_code,
    )


def test_replay_conflict_on_different_body() -> None:
    existing = _tx(status=TransactionStatus.APPROVED, request_fingerprint="other")
    use_case, *_ = _build(existing=existing)
    with pytest.raises(IdempotencyConflict):
        use_case.execute(
            user_id=existing.user_id,
            installation_id="inst-1",
            idempotency_key="key-1",
            product="GARRAFA_10",
            amount="1.50",
            card_number="4111111111111111",
            cvv="123",
        )


def test_gateway_timeout_maps_to_unknown() -> None:
    use_case, transactions, _, _ = _build(
        gateway_result=AuthorizeResult(outcome=GatewayOutcome.UNKNOWN),
    )
    transactions.update_result.return_value = _tx(status=TransactionStatus.UNKNOWN)
    result = use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="k1",
        product="GARRAFA_10",
        amount="1.50",
        card_number="4111111111111111",
        cvv="123",
    )
    assert result.transaction.status == TransactionStatus.UNKNOWN
    kwargs = transactions.update_result.call_args.kwargs
    assert kwargs["status"] == TransactionStatus.UNKNOWN


def test_gateway_connect_failure_maps_to_failed() -> None:
    use_case, transactions, _, _ = _build(
        gateway_result=AuthorizeResult(outcome=GatewayOutcome.FAILED),
    )
    transactions.update_result.return_value = _tx(status=TransactionStatus.FAILED)
    result = use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="k1",
        product="GARRAFA_10",
        amount="1.50",
        card_number="4111111111111111",
        cvv="123",
    )
    assert result.transaction.status == TransactionStatus.FAILED


def test_gateway_declined() -> None:
    use_case, transactions, _, _ = _build(
        gateway_result=AuthorizeResult(
            outcome=GatewayOutcome.DECLINED,
            response_code="51",
        ),
    )
    transactions.update_result.return_value = _tx(status=TransactionStatus.DECLINED)
    result = use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="k1",
        product="GARRAFA_10",
        amount="1.50",
        card_number="4111111111111111",
        cvv="123",
        expiration_date="2912",
    )
    assert result.transaction.status == TransactionStatus.DECLINED


def test_invalid_cvv() -> None:
    from domain.exceptions import InvalidCvv

    use_case, *_ = _build()
    with pytest.raises(InvalidCvv):
        use_case.execute(
            user_id=1,
            installation_id="inst-1",
            idempotency_key="k1",
            product="GARRAFA_10",
            amount="1.50",
            card_number="4111111111111111",
            cvv="12",
        )


def test_band_magnetic_022_allows_empty_cvv() -> None:
    """La banda magnética (entry_mode 022) no contiene CVV: se permite vacío."""
    use_case, transactions, _, gateway = _build()
    result = use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="k1",
        product="GARRAFA_10",
        amount="1.50",
        card_number="6063007014007403",
        cvv="",
        entry_mode="022",
        track2="6063007014007403=2912",
    )
    assert result.http_status == CreateTransactionHttpStatus.CREATED
    assert result.transaction.status == TransactionStatus.APPROVED
    gateway.authorize.assert_called_once()
    auth_req = gateway.authorize.call_args.args[0]
    assert auth_req.entry_mode == "022"
    assert auth_req.track2 == "6063007014007403=2912"
    transactions.create_pending.assert_called_once()
    transactions.update_result.assert_called_once()


def test_manual_012_still_validates_cvv() -> None:
    """El ingreso manual (entry_mode 012) sigue exigiendo CVV válido."""
    from domain.exceptions import InvalidCvv

    use_case, *_ = _build()
    with pytest.raises(InvalidCvv):
        use_case.execute(
            user_id=1,
            installation_id="inst-1",
            idempotency_key="k1",
            product="GARRAFA_10",
            amount="1.50",
            card_number="4111111111111111",
            cvv="",
            entry_mode="012",
        )


def test_band_022_without_track2_rejected() -> None:
    """Banda (022) sin track2 ni vencimiento: inconsistente, se rechaza."""
    from domain.exceptions import InvalidEntryMode

    use_case, *_ = _build()
    with pytest.raises(InvalidEntryMode):
        use_case.execute(
            user_id=1,
            installation_id="inst-1",
            idempotency_key="k1",
            product="GARRAFA_10",
            amount="1.50",
            card_number="6063007014007403",
            cvv="",
            entry_mode="022",
        )


def test_manual_012_with_track2_rejected() -> None:
    """Manual (012) con track2: inconsistente, se rechaza."""
    from domain.exceptions import InvalidEntryMode

    use_case, *_ = _build()
    with pytest.raises(InvalidEntryMode):
        use_case.execute(
            user_id=1,
            installation_id="inst-1",
            idempotency_key="k1",
            product="GARRAFA_10",
            amount="1.50",
            card_number="4111111111111111",
            cvv="123",
            entry_mode="012",
            track2="4111111111111111=2912",
        )


def test_unsupported_entry_mode_rejected() -> None:
    """entry_mode distinto de 012/022 se rechaza."""
    from domain.exceptions import InvalidEntryMode

    use_case, *_ = _build()
    with pytest.raises(InvalidEntryMode):
        use_case.execute(
            user_id=1,
            installation_id="inst-1",
            idempotency_key="k1",
            product="GARRAFA_10",
            amount="1.50",
            card_number="4111111111111111",
            cvv="123",
            entry_mode="999",
        )


def test_empty_terminal_string() -> None:
    use_case, *_ = _build(installation_code="   ")
    with pytest.raises(MissingTerminalId):
        use_case.execute(
            user_id=1,
            installation_id="inst-1",
            idempotency_key="k1",
            product="GARRAFA_10",
            amount="1.50",
            card_number="4111111111111111",
            cvv="123",
        )


def test_integrity_error_replays_existing() -> None:
    from sqlalchemy.exc import IntegrityError

    from application.payments.create_transaction import _fingerprint

    fp = _fingerprint(
        product=Product.GARRAFA_10,
        amount_minor=150,
        card_last4="1111",
        expiration_date=None,
    )
    existing = _tx(status=TransactionStatus.APPROVED, request_fingerprint=fp)
    use_case, transactions, _, gateway = _build()
    transactions.create_pending.side_effect = IntegrityError("x", {}, None)
    transactions.get_by_idempotency.side_effect = [None, existing]
    result = use_case.execute(
        user_id=existing.user_id,
        installation_id="inst-1",
        idempotency_key="key-1",
        product="GARRAFA_10",
        amount="1.50",
        card_number="4111111111111111",
        cvv="123",
    )
    assert result.transaction.status == TransactionStatus.APPROVED
    gateway.authorize.assert_not_called()
