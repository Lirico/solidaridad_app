from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

import pytest

from application.payments.enqueue_stale_pending_reversals import (
    EnqueueStalePendingReversals,
)
from domain.product import Product
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus


def _pending(**overrides: object) -> Transaction:
    now = datetime(2026, 10, 14, 12, tzinfo=UTC)
    values = {
        "id": 11,
        "transaction_number": "OP-261014-00000011",
        "user_id": 1,
        "installation_id": 1,
        "terminal_id": "05000001",
        "product": Product.GARRAFA_10,
        "processor_product_code": "993",
        "amount_minor": 200,
        "status": TransactionStatus.PENDING,
        "card_last4": "1111",
        "stan": "000111",
        "auth_id": None,
        "retrieval_reference": None,
        "processor_response_code": None,
        "user_message": "Operación en curso, reintente en unos segundos",
        "idempotency_key": "request-1",
        "request_fingerprint": "fingerprint",
        "created_at": now,
        "updated_at": now,
        "processor_ticket": "00000011",
    }
    values.update(overrides)
    return Transaction(**values)  # type: ignore[arg-type]


def _build(
    candidates: list[Transaction],
) -> tuple[EnqueueStalePendingReversals, MagicMock, MagicMock, MagicMock]:
    session = MagicMock()
    transactions = MagicMock()
    jobs = MagicMock()
    transactions.list_stale_pending_without_reverse_job.return_value = candidates
    now = datetime(2026, 10, 14, 12, tzinfo=UTC)
    use_case = EnqueueStalePendingReversals(
        session=session,
        transactions=transactions,
        jobs=jobs,
        stale_after=timedelta(seconds=60),
        now=lambda: now,
    )
    return use_case, session, transactions, jobs


def test_enqueues_each_stale_pending_transaction_once() -> None:
    transaction = _pending()
    use_case, session, transactions, jobs = _build([transaction])

    recovered = use_case.execute()

    assert recovered == [transaction]
    transactions.list_stale_pending_without_reverse_job.assert_called_once_with(
        created_before=datetime(2026, 10, 14, 11, 59, tzinfo=UTC)
    )
    jobs.create_reverse.assert_called_once()
    kwargs = jobs.create_reverse.call_args.kwargs
    assert kwargs["transaction_id"] == transaction.id
    assert kwargs["original_stan"] == "000111"
    assert kwargs["original_ticket"] == "00000011"
    assert len(kwargs["reversal_stan"]) == 6
    transactions.record_reversal_enqueued.assert_called_once_with(
        transaction_id=transaction.id
    )
    session.commit.assert_called_once()


def test_watchdog_rolls_back_all_recovery_writes_on_insert_failure() -> None:
    use_case, session, _, jobs = _build([_pending()])
    jobs.create_reverse.side_effect = RuntimeError("job insert failed")

    with pytest.raises(RuntimeError, match="job insert failed"):
        use_case.execute()

    session.rollback.assert_called_once()


def test_watchdog_requires_a_positive_staleness_window() -> None:
    with pytest.raises(ValueError, match="stale_after must be positive"):
        EnqueueStalePendingReversals(
            session=MagicMock(),
            transactions=MagicMock(),
            jobs=MagicMock(),
            stale_after=timedelta(0),
        )
