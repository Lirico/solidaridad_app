import logging
from unittest.mock import MagicMock

import pytest
from fastapi.testclient import TestClient

from application.payments.embedded_recovery_worker import RecoveryWorkerHealth
from application.payments.ports import ReversalOutcome, ReverseResult
from application.payments.sanitize import sanitize_processor_code
from config import Settings
from main import create_app
from presentation import create_router
from tests.test_reversal_job_worker import _build, _transaction

SYNTHETIC_PAN = "4242424242424242"


def _assert_pan_absent(pan: str, *outputs: object) -> None:
    for output in outputs:
        assert pan not in str(output)


def test_sanitizer_discards_a_card_number_masquerading_as_a_processor_code() -> None:
    assert sanitize_processor_code(SYNTHETIC_PAN) == "UNSAFE_CODE"
    assert sanitize_processor_code("05") == "05"


def test_recovery_events_and_persistence_never_emit_a_synthetic_pan(
    caplog: pytest.LogCaptureFixture,
) -> None:
    worker, _, _, jobs, alerts, gateway = _build(
        transaction=_transaction(card_number=SYNTHETIC_PAN),
        outcome=ReversalOutcome.INDETERMINATE,
    )
    alerts.open_for_job.return_value = True
    gateway.reverse.return_value = ReverseResult(
        outcome=ReversalOutcome.INDETERMINATE,
        response_code=SYNTHETIC_PAN,
    )

    with caplog.at_level(logging.INFO):
        assert worker.run_once() is True

    _assert_pan_absent(
        SYNTHETIC_PAN,
        *(record.__dict__ for record in caplog.records),
        jobs.finalize_claim.call_args.kwargs,
    )
    assert any(
        getattr(record, "transaction_number", None) == "OP-261014-00000011"
        for record in caplog.records
    )
    assert jobs.finalize_claim.call_args.kwargs["last_error_detail_sanitized"] == (
        "UNSAFE_CODE"
    )


def test_operational_responses_do_not_echo_a_synthetic_pan() -> None:
    worker = MagicMock()
    worker.health.return_value = RecoveryWorkerHealth(
        enabled=False,
        alive=False,
        stopping=False,
        started_at=None,
        last_iteration_at=None,
        last_error=None,
    )
    app = create_app(
        create_router(),
        settings=Settings(),
        recovery_worker=worker,
    )

    with TestClient(app) as client:
        responses = (
            client.get("/health/ready"),
            client.post("/v1/transactions", json={"card_number": SYNTHETIC_PAN}),
        )

    _assert_pan_absent(SYNTHETIC_PAN, *(response.text for response in responses))
