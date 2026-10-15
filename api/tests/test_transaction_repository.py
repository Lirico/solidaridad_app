from datetime import UTC, date, datetime
from unittest.mock import MagicMock

import pytest
from sqlalchemy.dialects import postgresql

from domain.authorization_outcome import AuthorizationOutcome
from domain.processor_job import ProcessorJobState
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
    row.card_number = "4111111111111111"
    row.expiration_date = "3012"
    row.authorization_outcome = "APPROVED"
    row.authorization_attempt_count = 1
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
    assert tx.card_number == "4111111111111111"
    assert tx.expiration_date == "3012"
    assert tx.authorization_outcome == AuthorizationOutcome.APPROVED
    assert "4111111111111111" not in repr(tx)
    assert "3012" not in repr(tx)


def test_to_domain_keeps_historical_rows_without_pan_unrecoverable() -> None:
    row = MagicMock(spec=TransactionModel)
    for name, value in {
        "id": 7,
        "transaction_number": "OP-260716-00000007",
        "user_id": 1,
        "installation_id": 10,
        "terminal_id": "05000001",
        "product": "GARRAFA_10",
        "processor_product_code": "993",
        "amount_minor": 150,
        "status": "APPROVED",
        "card_last4": "1111",
        "card_number": None,
        "expiration_date": None,
        "authorization_outcome": None,
        "authorization_attempt_count": 0,
        "stan": "1",
        "processor_ticket": "00000007",
        "auth_id": "A",
        "retrieval_reference": "R",
        "processor_response_code": "00",
        "user_message": "ok",
        "idempotency_key": "k",
        "void_idempotency_key": None,
        "batch_close_id": None,
        "request_fingerprint": "fp",
        "created_at": datetime.now(UTC),
        "updated_at": datetime.now(UTC),
    }.items():
        setattr(row, name, value)

    transaction = _to_domain(row)

    assert transaction.card_number is None
    assert transaction.authorization_outcome is None
    assert transaction.authorization_attempt_count == 0


def test_orm_repr_never_contains_recovery_card_data() -> None:
    row = TransactionModel(
        transaction_number="OP-261014-00000001",
        user_id=1,
        installation_id=1,
        terminal_id="05000001",
        product="GARRAFA_10",
        processor_product_code="993",
        amount_minor=100,
        status="PENDING",
        card_last4="1111",
        card_number="4111111111111111",
        expiration_date="3012",
        authorization_outcome="PENDING",
        authorization_attempt_count=1,
        idempotency_key="key",
        request_fingerprint="a" * 64,
    )

    rendered = repr(row)

    assert "4111111111111111" not in rendered
    assert "3012" not in rendered
    assert "1111" in rendered


def _current_batch_row(
    *,
    status: TransactionStatus,
    authorization_outcome: AuthorizationOutcome,
) -> MagicMock:
    row = MagicMock(spec=TransactionModel)
    row.id = 17
    row.installation_id = 2
    row.status = status.value
    row.authorization_outcome = authorization_outcome.value
    return row


def _batch_close_session(
    row: MagicMock,
    *,
    open_recovery_job: int | None,
) -> MagicMock:
    session = MagicMock()
    session.scalars.return_value.all.return_value = [row]
    session.scalar.side_effect = [None, open_recovery_job, None]
    return session


def test_close_batch_locks_current_transactions_before_recovery_check() -> None:
    row = _current_batch_row(
        status=TransactionStatus.APPROVED,
        authorization_outcome=AuthorizationOutcome.APPROVED,
    )
    session = _batch_close_session(row, open_recovery_job=9)

    result = TransactionRepository(session).close_current_batch(
        terminal_id="05000001",
        closed_by_user_id=1,
        idempotency_key="close-1",
    )

    assert result == "in_flight"
    current_query = session.scalars.call_args.args[0]
    current_sql = str(
        current_query.compile(
            dialect=postgresql.dialect(),
            compile_kwargs={"literal_binds": True},
        )
    )
    assert "FOR UPDATE" in current_sql
    assert session.scalar.call_count == 2
    assert session.add.call_count == 0


@pytest.mark.parametrize(
    "state",
    [
        ProcessorJobState.READY,
        ProcessorJobState.PROCESSING,
        ProcessorJobState.RETRY,
        ProcessorJobState.MANUAL_REVIEW,
    ],
)
def test_close_batch_blocks_each_open_recovery_job_state(
    state: ProcessorJobState,
) -> None:
    row = _current_batch_row(
        status=TransactionStatus.APPROVED,
        authorization_outcome=AuthorizationOutcome.APPROVED,
    )
    session = _batch_close_session(row, open_recovery_job=9)

    result = TransactionRepository(session).close_current_batch(
        terminal_id="05000001",
        closed_by_user_id=1,
        idempotency_key="close-1",
    )

    assert result == "in_flight"
    recovery_query = session.scalar.call_args_list[1].args[0]
    recovery_sql = str(
        recovery_query.compile(
            dialect=postgresql.dialect(),
            compile_kwargs={"literal_binds": True},
        )
    )
    assert f"'{state.value}'" in recovery_sql
    assert session.add.call_count == 0


@pytest.mark.parametrize(
    ("status", "outcome"),
    [
        (TransactionStatus.PENDING, AuthorizationOutcome.PENDING),
        (TransactionStatus.APPROVED, AuthorizationOutcome.INDETERMINATE),
    ],
)
def test_close_batch_blocks_pending_or_indeterminate_transactions(
    status: TransactionStatus,
    outcome: AuthorizationOutcome,
) -> None:
    row = _current_batch_row(status=status, authorization_outcome=outcome)
    session = _batch_close_session(row, open_recovery_job=None)

    result = TransactionRepository(session).close_current_batch(
        terminal_id="05000001",
        closed_by_user_id=1,
        idempotency_key="close-1",
    )

    assert result == "in_flight"
    assert session.scalar.call_count == 1
    assert session.add.call_count == 0


def test_close_batch_allows_confirmed_transaction_without_open_recovery(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    row = _current_batch_row(
        status=TransactionStatus.APPROVED,
        authorization_outcome=AuthorizationOutcome.APPROVED,
    )
    session = _batch_close_session(row, open_recovery_job=None)

    def assign_close_id() -> None:
        if session.add.called:
            session.add.call_args.args[0].id = 23

    session.flush.side_effect = assign_close_id
    expected_close = MagicMock()
    expected_transaction = MagicMock()
    monkeypatch.setattr(
        "persistence.repositories.transaction_repository._to_batch_close",
        lambda _: expected_close,
    )
    monkeypatch.setattr(
        "persistence.repositories.transaction_repository._to_domain",
        lambda _: expected_transaction,
    )

    result = TransactionRepository(session).close_current_batch(
        terminal_id="05000001",
        closed_by_user_id=1,
        idempotency_key="close-1",
    )

    assert result == (expected_close, [expected_transaction])
    assert row.batch_close_id is not None
    session.add.assert_called_once()


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
        card_number="4111111111111111",
        expiration_date="3012",
        stan="000001",
        processor_ticket="00000001",
        idempotency_key="k",
        request_fingerprint="fp",
        user_message="pending",
    )
    assert created.status == TransactionStatus.PENDING
    assert created.card_number == "4111111111111111"
    assert created.expiration_date == "3012"
    assert created.authorization_outcome == AuthorizationOutcome.PENDING
    assert created.authorization_attempt_count == 1
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
    row.card_number = "4111111111111111"
    row.expiration_date = "3012"
    row.authorization_outcome = "PENDING"
    row.authorization_attempt_count = 1
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
        authorization_outcome=AuthorizationOutcome.APPROVED,
        user_message="Pago aprobado",
        processor_response_code="00",
        auth_id="A",
        retrieval_reference="R",
    )
    assert updated.status == TransactionStatus.APPROVED
    assert row.status == "APPROVED"
    assert row.authorization_outcome == AuthorizationOutcome.APPROVED.value
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


def test_records_authorization_retry_and_sanitized_attempt_outcome() -> None:
    session, added = _session_with_identity()
    repo = TransactionRepository(session)
    row = MagicMock(spec=TransactionModel)
    row.id = 1
    row.user_id = 1
    row.status = TransactionStatus.PENDING.value
    row.authorization_attempt_count = 1
    session.get.return_value = row

    attempt_number = repo.start_authorization_retry(transaction_id=1)
    repo.record_authorization_attempt(
        transaction_id=1,
        attempt_number=attempt_number,
        outcome=AuthorizationOutcome.NOT_SENT,
    )

    assert attempt_number == 2
    assert row.authorization_attempt_count == 2
    events = [
        event
        for event in added
        if isinstance(event, TransactionStatusEvent)
        and event.event_type
        == TransactionStatusEventType.AUTHORIZATION_ATTEMPT.value
    ]
    assert len(events) == 1
    assert events[0].attempt_number == 2
    assert events[0].authorization_outcome == AuthorizationOutcome.NOT_SENT.value
    assert events[0].processor_response_code is None
    assert events[0].user_message is None
    assert events[0].idempotency_key is None


@pytest.mark.parametrize(
    "method_name",
    ["start_authorization_retry", "record_authorization_attempt"],
)
def test_authorization_attempt_methods_require_transaction(method_name: str) -> None:
    session = MagicMock()
    session.get.return_value = None
    repo = TransactionRepository(session)

    with pytest.raises(LookupError):
        if method_name == "start_authorization_retry":
            repo.start_authorization_retry(transaction_id=99)
        else:
            repo.record_authorization_attempt(
                transaction_id=99,
                attempt_number=1,
                outcome=AuthorizationOutcome.NOT_SENT,
            )


def test_update_result_missing() -> None:
    session = MagicMock()
    session.get.return_value = None
    repo = TransactionRepository(session)
    with pytest.raises(LookupError):
        repo.update_result(
            transaction_id=99,
            status=TransactionStatus.FAILED,
            authorization_outcome=AuthorizationOutcome.NOT_SENT,
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
    row.card_number = "4111111111111111"
    row.expiration_date = "3012"
    row.authorization_outcome = "APPROVED"
    row.authorization_attempt_count = 1
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
