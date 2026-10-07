from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest

from application.payments.close_batch import CloseBatch
from domain.batch_close import BatchClose
from domain.exceptions import (
    BatchCloseHasInFlightTransactions,
    BatchIsEmpty,
    MissingIdempotencyKey,
)
from domain.product import Product
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus


def _transaction() -> Transaction:
    now = datetime.now(UTC)
    return Transaction(
        id=1,
        transaction_number="OP-261006-00000001",
        user_id=1,
        installation_id=2,
        terminal_id="05000001",
        product=Product.GARRAFA_10,
        processor_product_code="993",
        amount_minor=100,
        status=TransactionStatus.APPROVED,
        card_last4="1111",
        stan="000001",
        auth_id="AUTH01",
        retrieval_reference="RRN01",
        processor_response_code="00",
        user_message="Pago aprobado",
        idempotency_key="sale-1",
        request_fingerprint="fingerprint",
        created_at=now,
        updated_at=now,
    )


def _close() -> BatchClose:
    return BatchClose(
        id=7,
        installation_id=2,
        terminal_id="05000001",
        closed_by_user_id=1,
        idempotency_key="close-1",
        closed_at=datetime.now(UTC),
    )


def _use_case(result: object) -> tuple[CloseBatch, MagicMock, MagicMock]:
    session = MagicMock()
    transactions = MagicMock()
    transactions.close_current_batch.return_value = result
    return CloseBatch(session, transactions), session, transactions


def test_close_batch_persists_and_returns_receipt() -> None:
    use_case, session, transactions = _use_case((_close(), [_transaction()]))

    result = use_case.execute(
        installation_id="05000001",
        user_id=1,
        idempotency_key="close-1",
    )

    assert result.batch_close.id == 7
    assert result.transactions[0].transaction_number == "OP-261006-00000001"
    session.commit.assert_called_once()
    transactions.close_current_batch.assert_called_once_with(
        terminal_id="05000001",
        closed_by_user_id=1,
        idempotency_key="close-1",
    )


@pytest.mark.parametrize(
    ("idempotency_key", "repository_result", "error"),
    [
        (None, (_close(), [_transaction()]), MissingIdempotencyKey),
        ("close-1", None, BatchIsEmpty),
        ("close-1", "in_flight", BatchCloseHasInFlightTransactions),
    ],
)
def test_close_batch_rejects_invalid_or_unsettled_requests(
    idempotency_key: str | None,
    repository_result: object,
    error: type[Exception],
) -> None:
    use_case, session, _ = _use_case(repository_result)

    with pytest.raises(error):
        use_case.execute(
            installation_id="05000001",
            user_id=1,
            idempotency_key=idempotency_key,
        )

    session.commit.assert_not_called()
