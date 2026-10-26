"""Deterministic recovery scenarios across the API and its gateway boundary.

The in-memory stores deliberately model the API persistence ports, including
the atomic claim token check.  They let this suite exercise the real use cases
without a networked processor while keeping every failure mode repeatable.
"""

from dataclasses import replace
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from threading import Barrier, Lock, Thread
from uuid import UUID, uuid4

from application.payments.create_transaction import CreateTransaction
from application.payments.get_transaction_status import GetTransactionStatus
from application.payments.ports import (
    AuthorizationGatewayOutcome,
    AuthorizeResult,
    ReversalOutcome,
    ReverseResult,
)
from application.payments.reversal_job_worker import ReversalJobWorker
from application.payments.stale_processing_job_monitor import (
    StaleProcessingJobMonitor,
)
from domain.authorization_outcome import AuthorizationOutcome
from domain.installation import Installation
from domain.payment_processing_config import PaymentProcessingConfig
from domain.processor_job import (
    ProcessorJob,
    ProcessorJobState,
    ProcessorOperationType,
)
from domain.product import Product
from domain.transaction import Transaction
from domain.transaction_status import TransactionStatus

NOW = datetime(2026, 10, 15, 12, tzinfo=UTC)
WORKER_NOW = datetime(2030, 1, 1, tzinfo=UTC)
PAN = "4111111111111111"


class _Session:
    def __init__(self) -> None:
        self.commits = 0
        self.rollbacks = 0

    def commit(self) -> None:
        self.commits += 1

    def rollback(self) -> None:
        self.rollbacks += 1


class _Transactions:
    def __init__(self) -> None:
        self.rows: dict[int, Transaction] = {}
        self._idempotency: dict[tuple[int, str], int] = {}
        self._next_id = 1
        self.jobs = None

    def get_by_idempotency(
        self, *, user_id: int, idempotency_key: str
    ) -> Transaction | None:
        row_id = self._idempotency.get((user_id, idempotency_key))
        return self.rows.get(row_id) if row_id is not None else None

    def next_transaction_number(self, _business_date: object) -> str:
        return f"OP-261015-{self._next_id:08d}"

    def create_pending(self, **values: object) -> Transaction:
        row_id = self._next_id
        self._next_id += 1
        row = Transaction(
            id=row_id,
            transaction_number=str(values["transaction_number"]),
            user_id=int(values["user_id"]),
            installation_id=int(values["installation_id"]),
            terminal_id=str(values["terminal_id"]),
            product=values["product"],  # type: ignore[arg-type]
            processor_product_code=str(values["processor_product_code"]),
            amount_minor=int(values["amount_minor"]),
            status=TransactionStatus.PENDING,
            card_last4=str(values["card_last4"]),
            card_number=str(values["card_number"]),
            expiration_date=values["expiration_date"],  # type: ignore[arg-type]
            stan=str(values["stan"]),
            processor_ticket=str(values["processor_ticket"]),
            auth_id=None,
            retrieval_reference=None,
            processor_response_code=None,
            user_message=str(values["user_message"]),
            idempotency_key=str(values["idempotency_key"]),
            request_fingerprint=str(values["request_fingerprint"]),
            created_at=NOW,
            updated_at=NOW,
        )
        self.rows[row_id] = row
        self._idempotency[(row.user_id, row.idempotency_key)] = row_id
        return row

    def record_authorization_attempt(self, **values: object) -> None:
        row_id = int(values["transaction_id"])
        self.rows[row_id] = replace(
            self.rows[row_id],
            authorization_attempt_count=int(values["attempt_number"]),
        )

    def start_authorization_retry(self, *, transaction_id: int) -> int:
        row = self.rows[transaction_id]
        attempt = row.authorization_attempt_count + 1
        self.rows[transaction_id] = replace(row, authorization_attempt_count=attempt)
        return attempt

    def get_by_id_for_update(self, *, transaction_id: int) -> Transaction:
        return self.rows[transaction_id]

    def update_result(self, *, transaction_id: int, **values: object) -> Transaction:
        row = replace(self.rows[transaction_id], updated_at=NOW, **values)
        self.rows[transaction_id] = row
        return row

    def record_reversal_enqueued(self, **_values: object) -> None:
        pass

    def record_idempotent_hit(self, **_values: object) -> None:
        pass

    def get_by_id(self, *, transaction_id: int) -> Transaction | None:
        return self.rows.get(transaction_id)

    def get_by_transaction_number(
        self, *, terminal_id: str, transaction_number: str
    ) -> Transaction | None:
        return next(
            (
                row
                for row in self.rows.values()
                if row.terminal_id == terminal_id
                and row.transaction_number == transaction_number
            ),
            None,
        )

    def list_stale_pending_without_reverse_job(
        self, *, created_before: datetime
    ) -> list[Transaction]:
        selected: list[Transaction] = []
        for row in self.rows.values():
            if row.status is not TransactionStatus.PENDING:
                continue
            if row.authorization_outcome is not AuthorizationOutcome.PENDING:
                continue
            if row.created_at > created_before:
                continue
            if row.stan is None or row.processor_ticket is None:
                continue
            if (
                self.jobs is not None
                and self.jobs.get_by_transaction(
                    transaction_id=row.id,
                    operation_type=ProcessorOperationType.REVERSE,
                )
                is not None
            ):
                continue
            selected.append(row)
        return selected


class _Jobs:
    def __init__(self) -> None:
        self.rows: dict[int, ProcessorJob] = {}
        self._lock = Lock()
        self._next_id = 1

    def get_by_transaction(
        self, *, transaction_id: int, operation_type: ProcessorOperationType
    ) -> ProcessorJob | None:
        return next(
            (
                row
                for row in self.rows.values()
                if row.transaction_id == transaction_id
                and row.operation_type is operation_type
            ),
            None,
        )

    def create_reverse(self, **values: object) -> ProcessorJob:
        row = ProcessorJob(
            id=self._next_id,
            transaction_id=int(values["transaction_id"]),
            operation_type=ProcessorOperationType.REVERSE,
            state=ProcessorJobState.READY,
            result=None,
            attempt_count=0,
            next_attempt_at=values["next_attempt_at"],  # type: ignore[arg-type]
            worker_id=None,
            claim_token=None,
            processing_started_at=None,
            original_stan=str(values["original_stan"]),
            original_ticket=str(values["original_ticket"]),
            reversal_stan=str(values["reversal_stan"]),
            last_error_code=None,
            last_error_detail_sanitized=None,
            created_at=NOW,
            updated_at=NOW,
            completed_at=None,
        )
        self.rows[row.id] = row
        self._next_id += 1
        return row

    def claim_next_due_reverse(
        self, *, worker_id: str, claim_token: UUID, claimed_at: datetime
    ) -> ProcessorJob | None:
        with self._lock:
            due = sorted(
                (
                    row
                    for row in self.rows.values()
                    if row.state in (ProcessorJobState.READY, ProcessorJobState.RETRY)
                    and row.next_attempt_at <= claimed_at
                ),
                key=lambda row: (row.next_attempt_at, row.id),
            )
            if not due:
                return None
            row = due[0]
            claimed = replace(
                row,
                state=ProcessorJobState.PROCESSING,
                worker_id=worker_id,
                claim_token=claim_token,
                processing_started_at=claimed_at,
                attempt_count=row.attempt_count + 1,
                updated_at=claimed_at,
            )
            self.rows[row.id] = claimed
            return claimed

    def finalize_claim(
        self,
        *,
        job_id: int,
        claim_token: UUID,
        target: ProcessorJobState,
        finalized_at: datetime,
        **values: object,
    ) -> bool:
        with self._lock:
            row = self.rows[job_id]
            if (
                row.state is not ProcessorJobState.PROCESSING
                or row.claim_token != claim_token
            ):
                return False
            self.rows[job_id] = replace(
                row,
                state=target,
                updated_at=finalized_at,
                next_attempt_at=values.get("next_attempt_at", row.next_attempt_at),
                result=values.get("result", row.result),
                last_error_code=values.get("last_error_code"),
                last_error_detail_sanitized=values.get("last_error_detail_sanitized"),
                completed_at=(
                    finalized_at if target is ProcessorJobState.COMPLETED else None
                ),
            )
            return True

    def move_next_stale_processing_to_manual_review(
        self, *, processing_started_before: datetime, reviewed_at: datetime
    ) -> ProcessorJob | None:
        with self._lock:
            stale = sorted(
                (
                    row
                    for row in self.rows.values()
                    if row.state is ProcessorJobState.PROCESSING
                    and row.processing_started_at is not None
                    and row.processing_started_at <= processing_started_before
                ),
                key=lambda row: (row.processing_started_at or NOW, row.id),
            )
            if not stale:
                return None
            row = stale[0]
            reviewed = replace(
                row,
                state=ProcessorJobState.MANUAL_REVIEW,
                updated_at=reviewed_at,
                last_error_code="PROCESSING_TIMEOUT",
                last_error_detail_sanitized=None,
            )
            self.rows[row.id] = reviewed
            return reviewed


class _Alerts:
    def __init__(self) -> None:
        self.opened: set[tuple[int, str]] = set()

    def open_for_job(
        self, *, processor_job_id: int, cause: str, opened_at: datetime
    ) -> bool:
        del opened_at
        marker = (processor_job_id, cause)
        if marker in self.opened:
            return False
        self.opened.add(marker)
        return True


class _Installations:
    @staticmethod
    def get_by_installation_id(installation_id: str) -> Installation | None:
        if installation_id != "05000001":
            return None
        return Installation(
            id=1,
            installation_id=installation_id,
            platform="local",
            last_seen_at=NOW,
            created_at=NOW,
        )


class _Configs:
    @staticmethod
    def get_default() -> PaymentProcessingConfig:
        return PaymentProcessingConfig(
            id=1,
            config_name="default",
            max_authorization_attempts=2,
            authorization_initial_delay_ms=0,
            authorization_max_delay_ms=0,
            authorization_backoff_multiplier=Decimal("1"),
            max_reversal_attempts=2,
            reversal_initial_delay_seconds=0,
            reversal_max_delay_seconds=0,
            reversal_backoff_multiplier=Decimal("1"),
            jitter_percentage=0,
            processing_timeout_seconds=60,
            worker_poll_interval_seconds=Decimal("1"),
            created_at=NOW,
            updated_at=NOW,
        )


class _ProcessorMock:
    def __init__(
        self,
        *,
        authorizations: list[AuthorizeResult],
        reversals: list[ReverseResult] | None = None,
    ) -> None:
        self._authorizations = authorizations
        self._reversals = reversals or []
        self.authorization_requests: list[object] = []
        self.reverse_requests: list[object] = []

    def authorize(self, request: object) -> AuthorizeResult:
        self.authorization_requests.append(request)
        return self._authorizations.pop(0)

    def reverse(self, request: object) -> ReverseResult:
        self.reverse_requests.append(request)
        return self._reversals.pop(0)


class _Harness:
    def __init__(
        self,
        *,
        authorizations: list[AuthorizeResult],
        reversals: list[ReverseResult] | None = None,
    ) -> None:
        self.session = _Session()
        self.transactions = _Transactions()
        self.jobs = _Jobs()
        self.transactions.jobs = self.jobs
        self.alerts = _Alerts()
        self.configs = _Configs()
        self.gateway = _ProcessorMock(
            authorizations=authorizations,
            reversals=reversals,
        )

    def create(self, idempotency_key: str = "sale-1") -> object:
        return CreateTransaction(
            self.session,  # type: ignore[arg-type]
            self.transactions,  # type: ignore[arg-type]
            _Installations(),  # type: ignore[arg-type]
            self.gateway,  # type: ignore[arg-type]
            self.configs,  # type: ignore[arg-type]
            self.jobs,  # type: ignore[arg-type]
            sleep=lambda _seconds: None,
            monotonic=lambda: 0,
            random_value=lambda: 0.5,
        ).execute(
            user_id=1,
            installation_id="05000001",
            idempotency_key=idempotency_key,
            product=Product.GARRAFA_10.value,
            amount="2",
            card_number=PAN,
            expiration_date="2912",
        )

    def worker(
        self, worker_id: str, now: datetime = WORKER_NOW
    ) -> ReversalJobWorker:
        return ReversalJobWorker(
            worker_id=worker_id,
            session=self.session,  # type: ignore[arg-type]
            transactions=self.transactions,  # type: ignore[arg-type]
            jobs=self.jobs,  # type: ignore[arg-type]
            alerts=self.alerts,  # type: ignore[arg-type]
            configs=self.configs,  # type: ignore[arg-type]
            gateway=self.gateway,  # type: ignore[arg-type]
            now=lambda: now,
            random_value=lambda: 0.5,
            claim_token_factory=uuid4,
        )


def test_end_to_end_normal_approval_and_decline_do_not_create_reversal_jobs() -> None:
    approved = _Harness(
        authorizations=[
            AuthorizeResult(
                outcome=AuthorizationGatewayOutcome.APPROVED,
                response_code="00",
            )
        ]
    )
    declined = _Harness(
        authorizations=[
            AuthorizeResult(
                outcome=AuthorizationGatewayOutcome.DECLINED,
                response_code="05",
            )
        ]
    )

    approved_result = approved.create()
    declined_result = declined.create()

    assert approved_result.transaction.status is TransactionStatus.APPROVED
    assert declined_result.transaction.status is TransactionStatus.DECLINED
    assert approved.jobs.rows == {}
    assert declined.jobs.rows == {}


def test_end_to_end_unsent_authorization_retries_then_fails_without_reversal() -> None:
    harness = _Harness(
        authorizations=[
            AuthorizeResult(outcome=AuthorizationGatewayOutcome.NOT_SENT),
            AuthorizeResult(outcome=AuthorizationGatewayOutcome.NOT_SENT),
        ]
    )

    result = harness.create()

    assert result.transaction.status is TransactionStatus.FAILED
    assert result.transaction.authorization_outcome is AuthorizationOutcome.NOT_SENT
    assert len(harness.gateway.authorization_requests) == 2
    assert harness.jobs.rows == {}


def test_end_to_end_lost_authorization_response_is_reversed_by_worker() -> None:
    harness = _Harness(
        authorizations=[
            AuthorizeResult(
                outcome=AuthorizationGatewayOutcome.INDETERMINATE,
                response_code=None,
            )
        ],
        reversals=[
            ReverseResult(
                outcome=ReversalOutcome.REVERSED_CONFIRMED,
                response_code="00",
            )
        ],
    )

    pending = harness.create()
    assert pending.http_status == 202
    assert pending.public_status is not None
    assert pending.public_status.reason == "PROCESSING"
    assert len(harness.gateway.reverse_requests) == 0

    assert harness.worker("worker-a").run_once() is True

    transaction = harness.transactions.rows[pending.transaction.id]
    job = next(iter(harness.jobs.rows.values()))
    assert transaction.status is TransactionStatus.FAILED
    assert job.state is ProcessorJobState.COMPLETED
    assert len(harness.gateway.reverse_requests) == 1


def test_end_to_end_reversal_retry_and_ambiguous_response() -> None:
    retrying = _Harness(
        authorizations=[AuthorizeResult(AuthorizationGatewayOutcome.INDETERMINATE)],
        reversals=[
            ReverseResult(ReversalOutcome.NOT_SENT),
            ReverseResult(ReversalOutcome.REVERSED_CONFIRMED, response_code="00"),
        ],
    )
    retrying.create()

    assert retrying.worker("worker-a").run_once() is True
    assert next(iter(retrying.jobs.rows.values())).state is ProcessorJobState.RETRY
    assert retrying.worker("worker-b").run_once() is True
    assert next(iter(retrying.jobs.rows.values())).state is ProcessorJobState.COMPLETED

    ambiguous = _Harness(
        authorizations=[AuthorizeResult(AuthorizationGatewayOutcome.INDETERMINATE)],
        reversals=[ReverseResult(ReversalOutcome.INDETERMINATE)],
    )
    created = ambiguous.create()

    assert ambiguous.worker("worker-a").run_once() is True
    status = GetTransactionStatus(ambiguous.transactions, ambiguous.jobs).execute(
        terminal_id="05000001",
        transaction_number=created.transaction.transaction_number,
    )
    assert status.public_status.reason == "UNDER_REVIEW"
    assert status.public_status.may_start_new_sale is True
    assert ambiguous.worker("worker-b").run_once() is False
    assert len(ambiguous.gateway.reverse_requests) == 1


def test_end_to_end_worker_crash_quarantines_job_and_prevents_a_second_send() -> None:
    harness = _Harness(
        authorizations=[AuthorizeResult(AuthorizationGatewayOutcome.INDETERMINATE)],
        reversals=[ReverseResult(ReversalOutcome.REVERSED_CONFIRMED)],
    )
    harness.create()
    claimed = harness.jobs.claim_next_due_reverse(
        worker_id="crashed-worker",
        claim_token=UUID("12345678-1234-5678-1234-567812345678"),
        claimed_at=WORKER_NOW,
    )
    assert claimed is not None

    monitor = StaleProcessingJobMonitor(
        session=harness.session,  # type: ignore[arg-type]
        jobs=harness.jobs,  # type: ignore[arg-type]
        alerts=harness.alerts,  # type: ignore[arg-type]
        transactions=harness.transactions,  # type: ignore[arg-type]
        configs=harness.configs,  # type: ignore[arg-type]
        now=lambda: WORKER_NOW + timedelta(seconds=61),
    )

    assert monitor.run_once() is True
    assert (
        next(iter(harness.jobs.rows.values())).state
        is ProcessorJobState.MANUAL_REVIEW
    )
    assert harness.alerts.opened == {(claimed.id, "PROCESSING_TIMEOUT")}
    assert (
        harness.worker("replacement", WORKER_NOW + timedelta(seconds=61)).run_once()
        is False
    )
    assert harness.gateway.reverse_requests == []


def test_concurrent_workers_claim_once_and_review_allows_new_sale() -> None:
    harness = _Harness(
        authorizations=[
            AuthorizeResult(AuthorizationGatewayOutcome.INDETERMINATE),
            AuthorizeResult(AuthorizationGatewayOutcome.APPROVED, response_code="00"),
        ],
        reversals=[ReverseResult(ReversalOutcome.INDETERMINATE)],
    )
    first = harness.create("first-sale")

    barrier = Barrier(2)
    outcomes: list[bool] = []

    def run(worker_id: str) -> None:
        barrier.wait()
        outcomes.append(harness.worker(worker_id).run_once())

    workers = [Thread(target=run, args=(worker_id,)) for worker_id in ("a", "b")]
    for worker in workers:
        worker.start()
    for worker in workers:
        worker.join()

    assert sorted(outcomes) == [False, True]
    assert len(harness.gateway.reverse_requests) == 1

    second = harness.create("second-sale")
    assert first.transaction.id != second.transaction.id
    assert second.transaction.status is TransactionStatus.APPROVED
