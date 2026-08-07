from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest

from application.payments.ports import AuthorizeResult, GatewayOutcome
from application.payments.void_transaction import (
    VoidTransaction,
    VoidTransactionHttpStatus,
)
from domain.exceptions import (
    CardMismatch,
    InvalidCardNumber,
    MissingIdempotencyKey,
    TransactionNotFound,
    TransactionNotVoidable,
)
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
        request_fingerprint="fp",
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
        processor_ticket="00000001",
        void_idempotency_key=None,
    )
    base.update(overrides)
    return Transaction(**base)  # type: ignore[arg-type]


def _build(
    *,
    existing: Transaction | None = None,
    gateway_result: AuthorizeResult | None = None,
) -> tuple[VoidTransaction, MagicMock, MagicMock]:
    session = MagicMock()
    transactions = MagicMock()
    gateway = MagicMock()
    transactions.get_by_transaction_number.return_value = existing or _tx()
    voided = _tx(status=TransactionStatus.VOIDED, user_message="Anulación aprobada")
    transactions.apply_void_result.return_value = voided
    gateway.void.return_value = gateway_result or AuthorizeResult(
        outcome=GatewayOutcome.APPROVED,
        response_code="00",
    )
    use_case = VoidTransaction(
        session=session,
        transactions=transactions,
        gateway=gateway,
    )
    return use_case, transactions, gateway


def test_void_approves() -> None:
    use_case, transactions, gateway = _build()
    result = use_case.execute(
        terminal_id="05000001",
        transaction_number="OP-260716-00000001",
        idempotency_key="void-1",
        card_number="4111111111111111",
    )
    assert result.http_status == VoidTransactionHttpStatus.OK
    assert result.transaction.status == TransactionStatus.VOIDED
    gateway.void.assert_called_once()
    req = gateway.void.call_args.args[0]
    assert req.original_ticket == "00000001"
    assert req.void_ticket == req.stan
    transactions.apply_void_result.assert_called_once()


def test_void_already_voided_is_idempotent() -> None:
    existing = _tx(status=TransactionStatus.VOIDED, user_message="Anulación aprobada")
    use_case, transactions, gateway = _build(existing=existing)
    result = use_case.execute(
        terminal_id="05000001",
        transaction_number="OP-260716-00000001",
        idempotency_key="void-1",
        card_number="4111111111111111",
    )
    assert result.transaction.status == TransactionStatus.VOIDED
    gateway.void.assert_not_called()
    transactions.record_idempotent_hit.assert_called_once()


def test_void_same_idempotency_key_replays_without_gateway() -> None:
    existing = _tx(void_idempotency_key="void-1")
    use_case, transactions, gateway = _build(existing=existing)
    result = use_case.execute(
        terminal_id="05000001",
        transaction_number="OP-260716-00000001",
        idempotency_key="void-1",
        card_number="4111111111111111",
    )
    assert result.transaction.status == TransactionStatus.APPROVED
    gateway.void.assert_not_called()
    transactions.record_idempotent_hit.assert_called_once_with(
        transaction_id=existing.id,
        status=TransactionStatus.APPROVED,
        actor_user_id=existing.user_id,
        idempotency_key="void-1",
        user_message=existing.user_message,
        processor_response_code=existing.processor_response_code,
    )


def test_void_not_found() -> None:
    use_case, transactions, _ = _build()
    transactions.get_by_transaction_number.return_value = None
    with pytest.raises(TransactionNotFound):
        use_case.execute(
            terminal_id="05000001",
            transaction_number="OP-260716-99999999",
            idempotency_key="void-1",
            card_number="4111111111111111",
        )


def test_void_not_approved() -> None:
    use_case, _, _ = _build(existing=_tx(status=TransactionStatus.DECLINED))
    with pytest.raises(TransactionNotVoidable):
        use_case.execute(
            terminal_id="05000001",
            transaction_number="OP-260716-00000001",
            idempotency_key="void-1",
            card_number="4111111111111111",
        )


def test_void_card_mismatch() -> None:
    use_case, _, _ = _build()
    with pytest.raises(CardMismatch):
        use_case.execute(
            terminal_id="05000001",
            transaction_number="OP-260716-00000001",
            idempotency_key="void-1",
            card_number="4111111111119999",
        )


def test_void_missing_idempotency() -> None:
    use_case, _, _ = _build()
    with pytest.raises(MissingIdempotencyKey):
        use_case.execute(
            terminal_id="05000001",
            transaction_number="OP-260716-00000001",
            idempotency_key=None,
            card_number="4111111111111111",
        )


def test_void_invalid_pan() -> None:
    use_case, _, _ = _build()
    with pytest.raises(InvalidCardNumber):
        use_case.execute(
            terminal_id="05000001",
            transaction_number="OP-260716-00000001",
            idempotency_key="void-1",
            card_number="abc",
        )


def test_void_declined_keeps_approved() -> None:
    use_case, transactions, _ = _build(
        gateway_result=AuthorizeResult(
            outcome=GatewayOutcome.DECLINED,
            response_code="76",
        ),
    )
    transactions.apply_void_result.return_value = _tx(
        void_idempotency_key="void-1",
    )
    result = use_case.execute(
        terminal_id="05000001",
        transaction_number="OP-260716-00000001",
        idempotency_key="void-1",
        card_number="4111111111111111",
    )
    assert result.transaction.status == TransactionStatus.APPROVED
    kwargs = transactions.apply_void_result.call_args.kwargs
    assert kwargs["status"] == TransactionStatus.APPROVED
    assert kwargs.get("user_message") is None


def test_void_unknown_maps_status() -> None:
    use_case, transactions, _ = _build(
        gateway_result=AuthorizeResult(outcome=GatewayOutcome.UNKNOWN),
    )
    transactions.apply_void_result.return_value = _tx(
        status=TransactionStatus.UNKNOWN,
    )
    result = use_case.execute(
        terminal_id="05000001",
        transaction_number="OP-260716-00000001",
        idempotency_key="void-1",
        card_number="4111111111111111",
    )
    assert result.transaction.status == TransactionStatus.UNKNOWN
    kwargs = transactions.apply_void_result.call_args.kwargs
    assert kwargs["status"] == TransactionStatus.UNKNOWN


def test_void_failed_keeps_approved() -> None:
    use_case, transactions, _ = _build(
        gateway_result=AuthorizeResult(outcome=GatewayOutcome.FAILED),
    )
    transactions.apply_void_result.return_value = _tx(void_idempotency_key="void-1")
    result = use_case.execute(
        terminal_id="05000001",
        transaction_number="OP-260716-00000001",
        idempotency_key="void-1",
        card_number="4111111111111111",
    )
    assert result.transaction.status == TransactionStatus.APPROVED
    kwargs = transactions.apply_void_result.call_args.kwargs
    assert kwargs["status"] == TransactionStatus.APPROVED
