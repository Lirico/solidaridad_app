from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest

from application.payments.get_transaction import GetTransaction
from domain.exceptions import TransactionNotFound
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
    )
    base.update(overrides)
    return Transaction(**base)  # type: ignore[arg-type]


def test_get_transaction_returns_match() -> None:
    transactions = MagicMock()
    existing = _tx()
    transactions.get_by_transaction_number.return_value = existing
    use_case = GetTransaction(transactions=transactions)

    result = use_case.execute(
        terminal_id="05000001",
        transaction_number="OP-260716-00000001",
    )

    assert result is existing
    transactions.get_by_transaction_number.assert_called_once_with(
        transaction_number="OP-260716-00000001",
        terminal_id="05000001",
    )


def test_get_transaction_truncates_terminal_id() -> None:
    transactions = MagicMock()
    transactions.get_by_transaction_number.return_value = _tx()
    use_case = GetTransaction(transactions=transactions)

    use_case.execute(
        terminal_id="05000001-extra",
        transaction_number="OP-260716-00000001",
    )

    assert (
        transactions.get_by_transaction_number.call_args.kwargs["terminal_id"]
        == "05000001"
    )


def test_get_transaction_missing() -> None:
    transactions = MagicMock()
    transactions.get_by_transaction_number.return_value = None
    use_case = GetTransaction(transactions=transactions)

    with pytest.raises(TransactionNotFound):
        use_case.execute(
            terminal_id="05000001",
            transaction_number="OP-260716-99999999",
        )
