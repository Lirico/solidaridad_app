from datetime import UTC, date, datetime
from unittest.mock import MagicMock
from uuid import uuid4

import pytest

from domain.exceptions import TransactionNumberExhausted
from domain.product import Product
from domain.transaction_status import TransactionStatus
from persistence.models.transaction import Transaction as TransactionModel
from persistence.models.transaction import TransactionNumberCounter
from persistence.repositories.transaction_repository import (
    TransactionRepository,
    _to_domain,
)


def test_to_domain_maps_fields() -> None:
    now = datetime.now(UTC)
    row = MagicMock(spec=TransactionModel)
    row.id = 7
    row.transaction_number = "OP-260716-0007"
    row.user_id = uuid4()
    row.installation_id = "inst"
    row.terminal_id = "05000001"
    row.product = "GARRAFA_10"
    row.processor_product_code = "993"
    row.amount_minor = 150
    row.status = "APPROVED"
    row.card_last4 = "1111"
    row.stan = "1"
    row.auth_id = "A"
    row.retrieval_reference = "R"
    row.processor_response_code = "00"
    row.user_message = "ok"
    row.idempotency_key = "k"
    row.request_fingerprint = "fp"
    row.created_at = now
    row.updated_at = now
    tx = _to_domain(row)
    assert tx.id == 7
    assert tx.product == Product.GARRAFA_10
    assert tx.status == TransactionStatus.APPROVED


def test_get_by_idempotency_none() -> None:
    session = MagicMock()
    session.scalars.return_value.first.return_value = None
    repo = TransactionRepository(session)
    assert repo.get_by_idempotency(user_id=uuid4(), idempotency_key="k") is None


def test_next_transaction_number_creates_counter() -> None:
    session = MagicMock()
    counter = TransactionNumberCounter(business_date=date(2026, 7, 16), last_value=0)
    # first select: None, then after add/flush: counter, then one() for re-lock
    session.scalars.return_value.first.side_effect = [None, counter]
    session.scalars.return_value.one.return_value = counter
    repo = TransactionRepository(session)
    number = repo.next_transaction_number(date(2026, 7, 16))
    assert number == "OP-260716-0001"
    assert counter.last_value == 1


def test_next_transaction_number_exhausted() -> None:
    session = MagicMock()
    counter = TransactionNumberCounter(business_date=date(2026, 7, 16), last_value=9999)
    session.scalars.return_value.first.return_value = counter
    repo = TransactionRepository(session)
    with pytest.raises(TransactionNumberExhausted):
        repo.next_transaction_number(date(2026, 7, 16))


def test_create_pending_and_update_result() -> None:
    session = MagicMock()
    repo = TransactionRepository(session)
    user_id = uuid4()

    created = repo.create_pending(
        transaction_number="OP-260716-0001",
        user_id=user_id,
        installation_id="inst",
        terminal_id="05000001",
        product=Product.GARRAFA_10,
        processor_product_code="993",
        amount_minor=150,
        card_last4="1111",
        stan="000001",
        idempotency_key="k",
        request_fingerprint="fp",
        user_message="pending",
    )
    assert created.status == TransactionStatus.PENDING
    session.add.assert_called()
    session.flush.assert_called()

    row = MagicMock(spec=TransactionModel)
    row.id = 1
    row.transaction_number = "OP-260716-0001"
    row.user_id = user_id
    row.installation_id = "inst"
    row.terminal_id = "05000001"
    row.product = "GARRAFA_10"
    row.processor_product_code = "993"
    row.amount_minor = 150
    row.status = "PENDING"
    row.card_last4 = "1111"
    row.stan = "000001"
    row.auth_id = None
    row.retrieval_reference = None
    row.processor_response_code = None
    row.user_message = "pending"
    row.idempotency_key = "k"
    row.request_fingerprint = "fp"
    row.created_at = datetime.now(UTC)
    row.updated_at = datetime.now(UTC)
    session.get.return_value = row

    updated = repo.update_result(
        transaction_id=1,
        status=TransactionStatus.APPROVED,
        user_message="Pago aprobado",
        processor_response_code="00",
        auth_id="A",
        retrieval_reference="R",
    )
    assert updated.status == TransactionStatus.APPROVED
    assert row.status == "APPROVED"


def test_update_result_missing() -> None:
    session = MagicMock()
    session.get.return_value = None
    repo = TransactionRepository(session)
    with pytest.raises(LookupError):
        repo.update_result(
            transaction_id=99,
            status=TransactionStatus.FAILED,
            user_message="x",
        )
