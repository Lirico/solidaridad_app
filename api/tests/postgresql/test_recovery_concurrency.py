import os
from concurrent.futures import ThreadPoolExecutor, TimeoutError
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, delete, func, select, text
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session

from application.payments.create_transaction import CreateTransaction
from application.payments.ports import AuthorizationGatewayOutcome, AuthorizeResult
from domain.authorization_outcome import AuthorizationOutcome
from domain.processor_job import (
    REVERSAL_CANCELLED_AUTHORIZATION_RESOLVED,
    ProcessorJobState,
)
from domain.product import Product
from domain.transaction_status import TransactionStatus
from persistence.models.installation import Installation
from persistence.models.merchant import Merchant
from persistence.models.processor_job import ProcessorJob as ProcessorJobModel
from persistence.models.recovery_alert import RecoveryAlert
from persistence.models.transaction import Transaction as TransactionModel
from persistence.models.transaction_status_event import TransactionStatusEvent
from persistence.models.user import User
from persistence.repositories.processor_job_repository import ProcessorJobRepository
from persistence.repositories.transaction_repository import TransactionRepository

NOW = datetime(2026, 11, 10, 15, tzinfo=UTC)


@dataclass(frozen=True, slots=True)
class RecoveryCase:
    engine: Engine
    transaction_id: int
    transaction_number: str
    user_id: int
    installation_id: int
    merchant_id: int


@pytest.fixture(scope="module")
def postgres_engine() -> Engine:
    database_url = os.environ.get("RECOVERY_CONCURRENCY_DATABASE_URL")
    if not database_url:
        pytest.skip("set RECOVERY_CONCURRENCY_DATABASE_URL for PostgreSQL races")
    engine = create_engine(database_url, pool_pre_ping=True)
    if engine.dialect.name != "postgresql":
        engine.dispose()
        pytest.fail("recovery concurrency tests require PostgreSQL")
    with engine.connect() as connection:
        revision = connection.scalar(text("SELECT version_num FROM alembic_version"))
    if revision != "20261110_0018":
        engine.dispose()
        pytest.fail(
            "recovery concurrency database must be migrated to 20261110_0018"
        )
    yield engine
    engine.dispose()


@pytest.fixture
def recovery_case(postgres_engine: Engine) -> RecoveryCase:
    unique = uuid4().hex
    with Session(postgres_engine) as session:
        merchant = Merchant(
            code=unique[:15],
            name="Concurrency Test",
            address="Test",
            city="Test",
            tax_id=unique[:15],
        )
        session.add(merchant)
        session.flush()
        user = User(
            merchant_id=merchant.id,
            name="Concurrency Test",
            email=f"recovery-{unique}@example.com",
            password_hash="not-used",
            must_change_password=False,
        )
        installation = Installation(
            installation_id=f"R{unique[:7]}",
            platform="test",
            last_seen_at=NOW,
        )
        session.add_all([user, installation])
        session.flush()
        transaction_number = f"OP-RACE-{unique[:12]}"
        transaction = TransactionModel(
            transaction_number=transaction_number,
            user_id=user.id,
            installation_id=installation.id,
            terminal_id=installation.installation_id,
            product=Product.GARRAFA_10.value,
            processor_product_code="993",
            amount_minor=200,
            status=TransactionStatus.PENDING.value,
            card_last4="1111",
            card_number="4111111111111111",
            expiration_date="2912",
            authorization_outcome=AuthorizationOutcome.PENDING.value,
            authorization_attempt_count=1,
            authorization_last_attempt_at=NOW - timedelta(minutes=2),
            stan="000123",
            processor_ticket=unique[:8],
            user_message="Operación en curso",
            idempotency_key=f"race-{unique}",
            request_fingerprint=unique,
            created_at=NOW - timedelta(minutes=2),
            updated_at=NOW - timedelta(minutes=2),
        )
        session.add(transaction)
        session.commit()
        case = RecoveryCase(
            engine=postgres_engine,
            transaction_id=transaction.id,
            transaction_number=transaction_number,
            user_id=user.id,
            installation_id=installation.id,
            merchant_id=merchant.id,
        )

    yield case

    with Session(postgres_engine) as session:
        job_ids = select(ProcessorJobModel.id).where(
            ProcessorJobModel.transaction_id == case.transaction_id
        )
        session.execute(delete(RecoveryAlert).where(RecoveryAlert.processor_job_id.in_(job_ids)))
        session.execute(
            delete(TransactionStatusEvent).where(
                TransactionStatusEvent.transaction_id == case.transaction_id
            )
        )
        session.execute(
            delete(ProcessorJobModel).where(
                ProcessorJobModel.transaction_id == case.transaction_id
            )
        )
        session.execute(
            delete(TransactionModel).where(TransactionModel.id == case.transaction_id)
        )
        session.execute(delete(User).where(User.id == case.user_id))
        session.execute(
            delete(Installation).where(Installation.id == case.installation_id)
        )
        session.execute(delete(Merchant).where(Merchant.id == case.merchant_id))
        session.commit()


def _stale_candidates(session: Session) -> list[object]:
    return TransactionRepository(session).list_stale_pending_without_reverse_job(
        attempted_before=NOW - timedelta(seconds=45)
    )


def _create_reverse(session: Session, transaction_id: int) -> None:
    ProcessorJobRepository(session).create_reverse(
        transaction_id=transaction_id,
        original_stan="000123",
        original_ticket="00000001",
        reversal_stan="900123",
        next_attempt_at=NOW,
    )


def test_two_watchdogs_do_not_lock_or_enqueue_the_same_sale(
    recovery_case: RecoveryCase,
) -> None:
    with Session(recovery_case.engine) as first:
        selected = _stale_candidates(first)
        assert [item.id for item in selected] == [recovery_case.transaction_id]

        with ThreadPoolExecutor(max_workers=1) as executor:
            second = executor.submit(_select_and_commit, recovery_case.engine)
            assert second.result(timeout=3) == []

        _create_reverse(first, recovery_case.transaction_id)
        first.commit()

    with Session(recovery_case.engine) as verification:
        count = verification.scalar(
            select(func.count(ProcessorJobModel.id)).where(
                ProcessorJobModel.transaction_id == recovery_case.transaction_id
            )
        )
    assert count == 1


def _select_and_commit(engine: Engine) -> list[int]:
    with Session(engine) as session:
        selected = [item.id for item in _stale_candidates(session)]
        session.commit()
        return selected


def test_late_approval_waits_for_watchdog_and_cancels_unsent_reverse(
    recovery_case: RecoveryCase,
) -> None:
    with Session(recovery_case.engine) as watchdog:
        assert len(_stale_candidates(watchdog)) == 1

        with ThreadPoolExecutor(max_workers=1) as executor:
            approval = executor.submit(
                _approve_and_cancel,
                recovery_case.engine,
                recovery_case.transaction_id,
            )
            with pytest.raises(TimeoutError):
                approval.result(timeout=0.2)

            TransactionRepository(watchdog).update_result(
                transaction_id=recovery_case.transaction_id,
                status=TransactionStatus.PENDING,
                authorization_outcome=AuthorizationOutcome.INDETERMINATE,
                user_message="Resultado desconocido",
            )
            _create_reverse(watchdog, recovery_case.transaction_id)
            watchdog.commit()
            approval.result(timeout=3)

    with Session(recovery_case.engine) as verification:
        transaction = verification.get(
            TransactionModel, recovery_case.transaction_id
        )
        job = verification.scalar(
            select(ProcessorJobModel).where(
                ProcessorJobModel.transaction_id == recovery_case.transaction_id
            )
        )
        assert transaction is not None
        assert job is not None
        assert transaction.status == TransactionStatus.APPROVED.value
        assert job.state == ProcessorJobState.CANCELLED.value
        assert job.result == REVERSAL_CANCELLED_AUTHORIZATION_RESOLVED


def _approve_and_cancel(engine: Engine, transaction_id: int) -> None:
    with Session(engine) as session:
        transactions = TransactionRepository(session)
        transactions.get_by_id_for_update(transaction_id=transaction_id)
        ProcessorJobRepository(session).cancel_unsent_reverse(
            transaction_id=transaction_id,
            cancelled_at=NOW,
            reason=REVERSAL_CANCELLED_AUTHORIZATION_RESOLVED,
        )
        transactions.update_result(
            transaction_id=transaction_id,
            status=TransactionStatus.APPROVED,
            authorization_outcome=AuthorizationOutcome.APPROVED,
            user_message="Aprobada",
            processor_response_code="00",
        )
        session.commit()


def test_late_result_does_not_overwrite_a_completed_reversal(
    recovery_case: RecoveryCase,
) -> None:
    token = uuid4()
    with Session(recovery_case.engine) as session:
        _create_reverse(session, recovery_case.transaction_id)
        session.commit()
        jobs = ProcessorJobRepository(session)
        claimed = jobs.claim_next_due_reverse(
            worker_id="postgres-test",
            claim_token=token,
            claimed_at=NOW,
        )
        assert claimed is not None
        assert jobs.finalize_claim(
            job_id=claimed.id,
            claim_token=token,
            target=ProcessorJobState.COMPLETED,
            finalized_at=NOW,
            result="REVERSED_CONFIRMED",
        )
        TransactionRepository(session).update_result(
            transaction_id=recovery_case.transaction_id,
            status=TransactionStatus.FAILED,
            authorization_outcome=AuthorizationOutcome.INDETERMINATE,
            user_message="Reversada",
        )
        session.commit()

    with Session(recovery_case.engine) as late_result:
        transactions = TransactionRepository(late_result)
        use_case = CreateTransaction(
            session=late_result,
            transactions=transactions,
            installations=MagicMock(),
            gateway=MagicMock(),
            configs=MagicMock(),
            jobs=ProcessorJobRepository(late_result),
        )
        current = transactions.get_by_id(
            transaction_id=recovery_case.transaction_id
        )
        assert current is not None
        final = use_case._apply_gateway_result(
            current,
            AuthorizeResult(
                outcome=AuthorizationGatewayOutcome.APPROVED,
                response_code="00",
            ),
            reversal_grace_seconds=45,
        )
        late_result.commit()

    assert final.status is TransactionStatus.FAILED
    with Session(recovery_case.engine) as verification:
        persisted = verification.get(
            TransactionModel, recovery_case.transaction_id
        )
        assert persisted is not None
        assert persisted.status == TransactionStatus.FAILED.value
