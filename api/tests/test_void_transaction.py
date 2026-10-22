import hashlib
from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest

from application.payments.ports import GatewayOutcome, VoidResult
from application.payments.void_transaction import (
    VoidTransaction,
    VoidTransactionHttpStatus,
)
from domain.exceptions import (
    CardMismatch,
    IdempotencyConflict,
    InvalidCardNumber,
    MissingIdempotencyKey,
    TransactionBatchClosed,
    TransactionNotFound,
    TransactionNotVoidable,
)
from domain.product import Product
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus
from domain.void_operation import (
    VoidOperation,
    VoidOperationOutcome,
    VoidOperationStatus,
)
from presentation.controllers.transactions_controller import _void_response


def _tx(**overrides: object) -> Transaction:
    now = datetime.now(UTC)
    base = dict(
        id=1,
        transaction_number="OP-261022-00000001",
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
        idempotency_key="sale-1",
        request_fingerprint="fp",
        created_at=now,
        updated_at=now,
        processor_ticket="00000001",
    )
    base.update(overrides)
    return Transaction(**base)  # type: ignore[arg-type]


def _operation(
    *,
    status: VoidOperationStatus = VoidOperationStatus.PENDING,
    outcome: VoidOperationOutcome = VoidOperationOutcome.PENDING,
    fingerprint: str = hashlib.sha256(b"4111111111111111|").hexdigest(),
) -> VoidOperation:
    now = datetime.now(UTC)
    return VoidOperation(
        id=4,
        transaction_id=1,
        idempotency_key="void-1",
        request_fingerprint=fingerprint,
        stan="123456",
        void_ticket="123456",
        original_ticket="00000001",
        outcome=outcome,
        status=status,
        processor_response_code=None,
        user_message="Anulación en curso",
        created_at=now,
        updated_at=now,
    )


def _build(
    *,
    transaction: Transaction | None = None,
    gateway_result: VoidResult | None = None,
) -> tuple[VoidTransaction, MagicMock, MagicMock, MagicMock, MagicMock]:
    session = MagicMock()
    transactions = MagicMock()
    operations = MagicMock()
    gateway = MagicMock()
    transactions.get_by_transaction_number.return_value = transaction or _tx()
    operations.get_by_idempotency.return_value = None
    operations.get_active_for_transaction.return_value = None
    operations.create_pending.return_value = _operation()
    operations.apply_result.return_value = _operation(
        status=VoidOperationStatus.VOIDED,
        outcome=VoidOperationOutcome.APPROVED,
    )
    transactions.apply_void_result.return_value = _tx(
        status=TransactionStatus.VOIDED,
        user_message="Anulación aprobada",
    )
    gateway.void.return_value = gateway_result or VoidResult(
        outcome=GatewayOutcome.APPROVED,
        response_code="00",
    )
    return (
        VoidTransaction(
            session=session,
            transactions=transactions,
            void_operations=operations,
            gateway=gateway,
        ),
        session,
        transactions,
        operations,
        gateway,
    )


def _execute(use_case: VoidTransaction) -> object:
    return use_case.execute(
        terminal_id="05000001",
        transaction_number="OP-261022-00000001",
        idempotency_key="void-1",
        card_number="4111111111111111",
    )


def test_void_approves_and_persists_identifiers_before_gateway() -> None:
    use_case, session, transactions, operations, gateway = _build()

    result = _execute(use_case)

    assert result.http_status == VoidTransactionHttpStatus.OK
    assert result.transaction.status == TransactionStatus.VOIDED
    operations.create_pending.assert_called_once()
    assert session.commit.call_count == 2
    gateway.void.assert_called_once()
    request = gateway.void.call_args.args[0]
    assert request.stan == request.void_ticket == "123456"
    transactions.apply_void_result.assert_called_once()


def test_ambiguous_void_keeps_sale_approved_and_opens_review_alert() -> None:
    use_case, _, transactions, operations, _ = _build(
        gateway_result=VoidResult(outcome=GatewayOutcome.UNKNOWN)
    )
    operations.apply_result.return_value = _operation(
        status=VoidOperationStatus.UNDER_REVIEW,
        outcome=VoidOperationOutcome.INDETERMINATE,
    )

    result = _execute(use_case)

    assert result.http_status == VoidTransactionHttpStatus.OK
    assert result.transaction.status == TransactionStatus.APPROVED
    transactions.apply_void_result.assert_not_called()
    assert operations.apply_result.call_args.kwargs["status"] == (
        VoidOperationStatus.UNDER_REVIEW
    )
    operations.open_alert_once.assert_called_once_with(
        void_operation_id=4,
        cause="VOID_INDETERMINATE",
    )


def test_gateway_exception_is_persisted_as_review_before_propagating() -> None:
    use_case, _, _, operations, gateway = _build()
    gateway.void.side_effect = RuntimeError("socket closed")
    operations.apply_result.return_value = _operation(
        status=VoidOperationStatus.UNDER_REVIEW,
        outcome=VoidOperationOutcome.INDETERMINATE,
    )

    with pytest.raises(RuntimeError, match="socket closed"):
        _execute(use_case)

    operations.open_alert_once.assert_called_once_with(
        void_operation_id=4,
        cause="VOID_INDETERMINATE",
    )


@pytest.mark.parametrize(
    ("gateway_result", "outcome", "status"),
    [
        (
            VoidResult(outcome=GatewayOutcome.DECLINED, response_code="76"),
            VoidOperationOutcome.DECLINED,
            VoidOperationStatus.DECLINED,
        ),
        (
            VoidResult(outcome=GatewayOutcome.FAILED),
            VoidOperationOutcome.NOT_SENT,
            VoidOperationStatus.FAILED,
        ),
    ],
)
def test_final_unsuccessful_void_keeps_sale_approved(
    gateway_result: VoidResult,
    outcome: VoidOperationOutcome,
    status: VoidOperationStatus,
) -> None:
    use_case, _, transactions, operations, _ = _build(gateway_result=gateway_result)
    operations.apply_result.return_value = _operation(status=status, outcome=outcome)
    transactions.apply_void_result.return_value = _tx()

    result = _execute(use_case)

    assert result.transaction.status == TransactionStatus.APPROVED
    assert operations.apply_result.call_args.kwargs["outcome"] == outcome
    assert operations.apply_result.call_args.kwargs["status"] == status


def test_replay_of_stranded_pending_void_escalates_to_under_review() -> None:
    use_case, _, transactions, operations, gateway = _build()
    pending = _operation()
    operations.get_by_idempotency.return_value = pending
    operations.apply_result.return_value = _operation(
        status=VoidOperationStatus.UNDER_REVIEW,
        outcome=VoidOperationOutcome.INDETERMINATE,
    )

    result = _execute(use_case)

    assert result.http_status == VoidTransactionHttpStatus.OK
    gateway.void.assert_not_called()
    operations.open_alert_once.assert_called_once()
    transactions.record_idempotent_hit.assert_called_once()


def test_replay_of_reviewed_void_never_sends_again() -> None:
    use_case, _, transactions, operations, gateway = _build()
    reviewed = _operation(
        status=VoidOperationStatus.UNDER_REVIEW,
        outcome=VoidOperationOutcome.INDETERMINATE,
    )
    operations.get_by_idempotency.return_value = reviewed

    result = _execute(use_case)

    assert result.void_operation == reviewed
    gateway.void.assert_not_called()
    operations.apply_result.assert_not_called()
    transactions.record_idempotent_hit.assert_called_once()


def test_replay_with_different_request_is_rejected() -> None:
    use_case, _, _, operations, _ = _build()
    operations.get_by_idempotency.return_value = _operation(fingerprint="other")

    with pytest.raises(IdempotencyConflict):
        _execute(use_case)


def test_second_key_is_rejected_while_void_is_under_review() -> None:
    use_case, _, _, operations, _ = _build()
    operations.get_active_for_transaction.return_value = _operation(
        status=VoidOperationStatus.UNDER_REVIEW,
        outcome=VoidOperationOutcome.INDETERMINATE,
    )

    with pytest.raises(TransactionNotVoidable):
        use_case.execute(
            terminal_id="05000001",
            transaction_number="OP-261022-00000001",
            idempotency_key="void-2",
            card_number="4111111111111111",
        )


@pytest.mark.parametrize(
    ("transaction", "error"),
    [
        (None, TransactionNotFound),
        (_tx(batch_close_id=3), TransactionBatchClosed),
        (_tx(status=TransactionStatus.DECLINED), TransactionNotVoidable),
    ],
)
def test_void_rejects_unavailable_transactions(
    transaction: Transaction | None,
    error: type[Exception],
) -> None:
    use_case, _, transactions, _, gateway = _build()
    transactions.get_by_transaction_number.return_value = transaction

    with pytest.raises(error):
        _execute(use_case)
    gateway.void.assert_not_called()


def test_void_rejects_invalid_card_or_missing_key() -> None:
    use_case, _, _, _, _ = _build()
    with pytest.raises(MissingIdempotencyKey):
        use_case.execute(
            terminal_id="05000001",
            transaction_number="OP-261022-00000001",
            idempotency_key=None,
            card_number="4111111111111111",
        )
    with pytest.raises(InvalidCardNumber):
        use_case.execute(
            terminal_id="05000001",
            transaction_number="OP-261022-00000001",
            idempotency_key="void-1",
            card_number="x",
        )
    with pytest.raises(CardMismatch):
        use_case.execute(
            terminal_id="05000001",
            transaction_number="OP-261022-00000001",
            idempotency_key="void-1",
            card_number="4111111111119999",
        )


def test_voided_sale_is_idempotent_without_creating_another_operation() -> None:
    use_case, _, transactions, operations, gateway = _build(
        transaction=_tx(status=TransactionStatus.VOIDED, user_message="Anulada")
    )

    result = _execute(use_case)

    assert result.void_operation is None
    gateway.void.assert_not_called()
    operations.create_pending.assert_not_called()
    transactions.record_idempotent_hit.assert_called_once()


@pytest.mark.parametrize(
    ("internal_status", "expected_status", "expected_reason", "may_start_new_void"),
    [
        (
            VoidOperationStatus.UNDER_REVIEW,
            "FAILED",
            "UNDER_REVIEW",
            False,
        ),
        (VoidOperationStatus.FAILED, "FAILED", "NOT_SENT", True),
    ],
)
def test_void_public_projection_keeps_failed_as_the_only_error_status(
    internal_status: VoidOperationStatus,
    expected_status: str,
    expected_reason: str,
    may_start_new_void: bool,
) -> None:
    operation = _operation(status=internal_status)

    response = _void_response(
        "OP-261022-00000001",
        operation,
        fallback_status="VOIDED",
        fallback_message="Anulada",
        created_at=operation.created_at,
    )

    assert response.status == expected_status
    assert response.reason == expected_reason
    assert response.may_start_new_void is may_start_new_void
