from datetime import UTC, date, datetime
from unittest.mock import MagicMock

import pytest

from domain.product import Product
from domain.transaction_status import TransactionStatus
from domain.transaction_status_event import (
    TransactionStatusActorType,
    TransactionStatusEventType,
)
from persistence.models.transaction import Transaction as TransactionModel
from persistence.models.transaction import TransactionNumberCounter
from persistence.models.transaction_status_event import TransactionStatusEvent
from persistence.repositories.transaction_repository import (
    TransactionRepository,
    _to_domain,
)


def test_to_domain_maps_fields() -> None:
    now = datetime.now(UTC)
    row = MagicMock(spec=TransactionModel)
    row.id = 7
    row.transaction_number = "OP-260716-00000007"
    row.user_id = 1
    row.installation_id = 10
    row.terminal_id = "05000001"
    row.product = "GARRAFA_10"
    row.processor_product_code = "993"
    row.amount_minor = 150
    row.status = "APPROVED"
    row.card_last4 = "1111"
    row.stan = "1"
    row.processor_ticket = "00000007"
    row.auth_id = "A"
    row.retrieval_reference = "R"
    row.processor_response_code = "00"
    row.user_message = "ok"
    row.idempotency_key = "k"
    row.void_idempotency_key = None
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
    assert repo.get_by_idempotency(user_id=1, idempotency_key="k") is None


def test_next_transaction_number_creates_counter() -> None:
    session = MagicMock()
    counter = TransactionNumberCounter(business_date=date(2026, 7, 16), last_value=0)
    # first select: None, then after add/flush: counter, then one() for re-lock
    session.scalars.return_value.first.side_effect = [None, counter]
    session.scalars.return_value.one.return_value = counter
    repo = TransactionRepository(session)
    number = repo.next_transaction_number(date(2026, 7, 16))
    assert number == "OP-260716-00000001"
    assert counter.last_value == 1


def test_next_transaction_number_beyond_former_daily_cap() -> None:
    session = MagicMock()
    counter = TransactionNumberCounter(business_date=date(2026, 7, 16), last_value=9999)
    session.scalars.return_value.first.return_value = counter
    repo = TransactionRepository(session)
    number = repo.next_transaction_number(date(2026, 7, 16))
    assert number == "OP-260716-00010000"
    assert counter.last_value == 10000


def _session_with_identity() -> tuple[MagicMock, list[object]]:
    session = MagicMock()
    added: list[object] = []

    def add(obj: object) -> None:
        added.append(obj)

    def flush() -> None:
        for obj in added:
            if isinstance(obj, TransactionModel) and obj.id is None:
                obj.id = 1

    session.add.side_effect = add
    session.flush.side_effect = flush
    return session, added


def test_create_pending_and_update_result() -> None:
    session, added = _session_with_identity()
    repo = TransactionRepository(session)
    user_id = 1

    created = repo.create_pending(
        transaction_number="OP-260716-00000001",
        user_id=user_id,
        installation_id=10,
        terminal_id="05000001",
        product=Product.GARRAFA_10,
        processor_product_code="993",
        amount_minor=150,
        card_last4="1111",
        stan="000001",
        processor_ticket="00000001",
        idempotency_key="k",
        request_fingerprint="fp",
        user_message="pending",
    )
    assert created.status == TransactionStatus.PENDING
    assert created.id == 1
    create_events = [e for e in added if isinstance(e, TransactionStatusEvent)]
    assert len(create_events) == 1
    assert create_events[0].event_type == TransactionStatusEventType.CREATED.value
    assert create_events[0].from_status is None
    assert create_events[0].to_status == TransactionStatus.PENDING.value
    assert create_events[0].actor_type == TransactionStatusActorType.USER.value

    row = MagicMock(spec=TransactionModel)
    row.id = 1
    row.transaction_number = "OP-260716-00000001"
    row.user_id = user_id
    row.installation_id = 10
    row.terminal_id = "05000001"
    row.product = "GARRAFA_10"
    row.processor_product_code = "993"
    row.amount_minor = 150
    row.status = "PENDING"
    row.card_last4 = "1111"
    row.stan = "000001"
    row.processor_ticket = "00000001"
    row.auth_id = None
    row.retrieval_reference = None
    row.processor_response_code = None
    row.user_message = "pending"
    row.idempotency_key = "k"
    row.void_idempotency_key = None
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
    gateway_events = [
        e
        for e in added
        if isinstance(e, TransactionStatusEvent)
        and e.event_type == TransactionStatusEventType.GATEWAY_RESULT.value
    ]
    assert len(gateway_events) == 1
    assert gateway_events[0].from_status == TransactionStatus.PENDING.value
    assert gateway_events[0].to_status == TransactionStatus.APPROVED.value
    assert gateway_events[0].actor_type == TransactionStatusActorType.SYSTEM.value


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


def test_apply_void_result_appends_event() -> None:
    session, added = _session_with_identity()
    repo = TransactionRepository(session)
    row = MagicMock(spec=TransactionModel)
    row.id = 1
    row.transaction_number = "OP-260716-00000001"
    row.user_id = 1
    row.installation_id = 10
    row.terminal_id = "05000001"
    row.product = "GARRAFA_10"
    row.processor_product_code = "993"
    row.amount_minor = 150
    row.status = "APPROVED"
    row.card_last4 = "1111"
    row.stan = "000001"
    row.processor_ticket = "00000001"
    row.auth_id = "A"
    row.retrieval_reference = "R"
    row.processor_response_code = "00"
    row.user_message = "Pago aprobado"
    row.idempotency_key = "k"
    row.void_idempotency_key = None
    row.request_fingerprint = "fp"
    row.created_at = datetime.now(UTC)
    row.updated_at = datetime.now(UTC)
    session.get.return_value = row

    voided = repo.apply_void_result(
        transaction_id=1,
        status=TransactionStatus.VOIDED,
        void_idempotency_key="void-1",
        user_message="Anulación aprobada",
        processor_response_code="00",
    )
    assert voided.status == TransactionStatus.VOIDED
    events = [e for e in added if isinstance(e, TransactionStatusEvent)]
    assert len(events) == 1
    assert events[0].event_type == TransactionStatusEventType.VOID_RESULT.value
    assert events[0].from_status == TransactionStatus.APPROVED.value
    assert events[0].to_status == TransactionStatus.VOIDED.value
    assert events[0].idempotency_key == "void-1"


def test_record_idempotent_hit() -> None:
    session, added = _session_with_identity()
    repo = TransactionRepository(session)
    repo.record_idempotent_hit(
        transaction_id=1,
        status=TransactionStatus.APPROVED,
        actor_user_id=9,
        idempotency_key="k1",
        user_message="Pago aprobado",
        processor_response_code="00",
    )
    events = [e for e in added if isinstance(e, TransactionStatusEvent)]
    assert len(events) == 1
    assert events[0].event_type == TransactionStatusEventType.IDEMPOTENT_HIT.value
    assert events[0].from_status == TransactionStatus.APPROVED.value
    assert events[0].to_status == TransactionStatus.APPROVED.value
    assert events[0].actor_user_id == 9
    assert events[0].idempotency_key == "k1"
