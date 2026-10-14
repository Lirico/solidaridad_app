from datetime import UTC, datetime
from decimal import Decimal
from unittest.mock import MagicMock, call

import pytest

from application.payments.create_transaction import (
    CreateTransaction,
    CreateTransactionHttpStatus,
)
from application.payments.ports import (
    AuthorizationGatewayOutcome,
    AuthorizeResult,
)
from domain.authorization_outcome import AuthorizationOutcome
from domain.exceptions import (
    IdempotencyConflict,
    InvalidAmount,
    InvalidCardNumber,
    MissingIdempotencyKey,
    MissingTerminalId,
)
from domain.installation import Installation
from domain.payment_processing_config import PaymentProcessingConfig
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
        amount_minor=200,
        status=TransactionStatus.APPROVED,
        card_last4="1111",
        stan="000001",
        auth_id="AUTH01",
        retrieval_reference="RRN001",
        processor_response_code="00",
        user_message="Pago aprobado",
        idempotency_key="key-1",
        request_fingerprint="",
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
    )
    base.update(overrides)
    return Transaction(**base)  # type: ignore[arg-type]


def _build(
    *,
    existing: Transaction | None = None,
    gateway_result: AuthorizeResult | None = None,
    gateway_results: list[AuthorizeResult] | None = None,
    installation_code: str | None = "05000001",
    max_authorization_attempts: int = 1,
    processing_timeout_seconds: int = 3,
    monotonic: MagicMock | None = None,
) -> tuple[CreateTransaction, MagicMock, MagicMock, MagicMock]:
    session = MagicMock()
    transactions = MagicMock()
    installations = MagicMock()
    gateway = MagicMock()
    configs = MagicMock()
    sleeper = MagicMock()

    transactions.get_by_idempotency.return_value = existing
    installations.get_by_installation_id.return_value = (
        Installation(
            id=10,
            installation_id=installation_code,
            platform="local",
            last_seen_at=datetime.now(UTC),
            created_at=datetime.now(UTC),
        )
        if installation_code is not None
        else None
    )
    transactions.next_transaction_number.return_value = "OP-260716-00000001"
    pending = _tx(status=TransactionStatus.PENDING, user_message="pending")
    # fingerprint filled by use case after create; for create path we stub update
    transactions.create_pending.return_value = pending
    final = _tx(status=TransactionStatus.APPROVED)
    transactions.update_result.return_value = final
    default_result = gateway_result or AuthorizeResult(
        outcome=AuthorizationGatewayOutcome.APPROVED,
        response_code="00",
        auth_id="A1",
        retrieval_reference="R1",
    )
    if gateway_results is None:
        gateway.authorize.return_value = default_result
    else:
        gateway.authorize.side_effect = gateway_results
    transactions.start_authorization_retry.side_effect = iter(
        range(2, max_authorization_attempts + 1)
    )
    now = datetime.now(UTC)
    configs.get_default.return_value = PaymentProcessingConfig(
        id=1,
        config_name="default",
        max_authorization_attempts=max_authorization_attempts,
        authorization_initial_delay_ms=100,
        authorization_max_delay_ms=500,
        authorization_backoff_multiplier=Decimal("2"),
        max_reversal_attempts=5,
        reversal_initial_delay_seconds=5,
        reversal_max_delay_seconds=300,
        reversal_backoff_multiplier=Decimal("2"),
        jitter_percentage=0,
        processing_timeout_seconds=processing_timeout_seconds,
        worker_poll_interval_seconds=Decimal("1"),
        created_at=now,
        updated_at=now,
    )

    use_case = CreateTransaction(
        session=session,
        transactions=transactions,
        installations=installations,
        gateway=gateway,
        configs=configs,
        sleep=sleeper,
        monotonic=monotonic or MagicMock(return_value=0.0),
        random_value=lambda: 0.5,
    )
    return use_case, transactions, installations, gateway


def test_create_approves() -> None:
    use_case, transactions, _, gateway = _build()
    result = use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="k1",
        product="GARRAFA_10",
        amount="2",
        card_number="4111111111111111",
        cvv="123",
    )
    assert result.http_status == CreateTransactionHttpStatus.CREATED
    assert result.transaction.status == TransactionStatus.APPROVED
    gateway.authorize.assert_called_once()
    auth_req = gateway.authorize.call_args.args[0]
    assert auth_req.ticket_number == "00000001"
    transactions.create_pending.assert_called_once()
    create_kwargs = transactions.create_pending.call_args.kwargs
    assert create_kwargs["processor_ticket"] == "00000001"
    assert create_kwargs["card_number"] == "4111111111111111"
    assert create_kwargs["expiration_date"] is None
    assert "cvv" not in create_kwargs
    transactions.update_result.assert_called_once()
    update_kwargs = transactions.update_result.call_args.kwargs
    assert update_kwargs["authorization_outcome"] == AuthorizationOutcome.APPROVED


def test_missing_idempotency_key() -> None:
    use_case, *_ = _build()
    with pytest.raises(MissingIdempotencyKey):
        use_case.execute(
            user_id=1,
            installation_id="inst-1",
            idempotency_key=None,
            product="GARRAFA_10",
            amount="2",
            card_number="4111111111111111",
            cvv="123",
        )


def test_invalid_pan() -> None:
    use_case, *_ = _build()
    with pytest.raises(InvalidCardNumber):
        use_case.execute(
            user_id=1,
            installation_id="inst-1",
            idempotency_key="k1",
            product="GARRAFA_10",
            amount="2",
            card_number="606300101400740X",
            cvv="123",
        )


def test_processor_pan_without_luhn_is_accepted() -> None:
    use_case, transactions, _, gateway = _build()
    result = use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="k1",
        product="GARRAFA_10",
        amount="2",
        card_number="6063001014007403",
        cvv="123",
    )
    assert result.http_status == CreateTransactionHttpStatus.CREATED
    assert result.transaction.status == TransactionStatus.APPROVED
    gateway.authorize.assert_called_once()
    transactions.update_result.assert_called_once()


def test_missing_terminal() -> None:
    use_case, *_ = _build(installation_code=None)
    with pytest.raises(MissingTerminalId):
        use_case.execute(
            user_id=1,
            installation_id="inst-1",
            idempotency_key="k1",
            product="GARRAFA_10",
            amount="2",
            card_number="4111111111111111",
            cvv="123",
        )


def test_replay_pending_returns_202() -> None:
    # fingerprint for GARRAFA_10|200|1111|
    from application.payments.create_transaction import _fingerprint

    fp = _fingerprint(
        product=Product.GARRAFA_10,
        amount_minor=200,
        card_number="4111111111111111",
        expiration_date=None,
    )
    existing = _tx(status=TransactionStatus.PENDING, request_fingerprint=fp)

    use_case, transactions, _, gateway = _build(existing=existing)
    result = use_case.execute(
        user_id=existing.user_id,
        installation_id="inst-1",
        idempotency_key="key-1",
        product="GARRAFA_10",
        amount="2",
        card_number="4111111111111111",
        cvv="123",
    )
    assert result.http_status == CreateTransactionHttpStatus.ACCEPTED
    assert result.transaction.status == TransactionStatus.PENDING
    gateway.authorize.assert_not_called()
    transactions.create_pending.assert_not_called()
    transactions.record_idempotent_hit.assert_called_once()
    session = use_case._session
    session.commit.assert_called()


def test_replay_approved_returns_201_without_gateway() -> None:
    from application.payments.create_transaction import _fingerprint

    fp = _fingerprint(
        product=Product.GARRAFA_10,
        amount_minor=200,
        card_number="4111111111111111",
        expiration_date=None,
    )
    existing = _tx(status=TransactionStatus.APPROVED, request_fingerprint=fp)
    use_case, transactions, _, gateway = _build(existing=existing)
    result = use_case.execute(
        user_id=existing.user_id,
        installation_id="inst-1",
        idempotency_key="key-1",
        product="GARRAFA_10",
        amount="2",
        card_number="4111111111111111",
        cvv="123",
    )
    assert result.http_status == CreateTransactionHttpStatus.CREATED
    assert result.transaction.status == TransactionStatus.APPROVED
    gateway.authorize.assert_not_called()
    transactions.record_idempotent_hit.assert_called_once_with(
        transaction_id=existing.id,
        status=TransactionStatus.APPROVED,
        actor_user_id=existing.user_id,
        idempotency_key="key-1",
        user_message=existing.user_message,
        processor_response_code=existing.processor_response_code,
    )


def test_replay_conflict_on_different_body() -> None:
    existing = _tx(status=TransactionStatus.APPROVED, request_fingerprint="other")
    use_case, *_ = _build(existing=existing)
    with pytest.raises(IdempotencyConflict):
        use_case.execute(
            user_id=existing.user_id,
            installation_id="inst-1",
            idempotency_key="key-1",
            product="GARRAFA_10",
            amount="2",
            card_number="4111111111111111",
            cvv="123",
        )


def test_gateway_timeout_maps_to_unknown() -> None:
    use_case, transactions, _, _ = _build(
        gateway_result=AuthorizeResult(
            outcome=AuthorizationGatewayOutcome.INDETERMINATE
        ),
    )
    transactions.update_result.return_value = _tx(status=TransactionStatus.UNKNOWN)
    result = use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="k1",
        product="GARRAFA_10",
        amount="2",
        card_number="4111111111111111",
        cvv="123",
    )
    assert result.transaction.status == TransactionStatus.UNKNOWN
    kwargs = transactions.update_result.call_args.kwargs
    assert kwargs["status"] == TransactionStatus.UNKNOWN
    assert kwargs["authorization_outcome"] == AuthorizationOutcome.INDETERMINATE


def test_gateway_connect_failure_maps_to_failed() -> None:
    use_case, transactions, _, _ = _build(
        gateway_result=AuthorizeResult(outcome=AuthorizationGatewayOutcome.NOT_SENT),
    )
    transactions.update_result.return_value = _tx(status=TransactionStatus.FAILED)
    result = use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="k1",
        product="GARRAFA_10",
        amount="2",
        card_number="4111111111111111",
        cvv="123",
    )
    assert result.transaction.status == TransactionStatus.FAILED
    kwargs = transactions.update_result.call_args.kwargs
    assert kwargs["authorization_outcome"] == AuthorizationOutcome.NOT_SENT


def test_maximum_one_makes_no_additional_attempts() -> None:
    use_case, transactions, _, gateway = _build(
        gateway_result=AuthorizeResult(outcome=AuthorizationGatewayOutcome.NOT_SENT),
        max_authorization_attempts=1,
    )
    transactions.update_result.return_value = _tx(status=TransactionStatus.FAILED)

    use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="k1",
        product="GARRAFA_10",
        amount="2",
        card_number="4111111111111111",
    )

    gateway.authorize.assert_called_once()
    transactions.start_authorization_retry.assert_not_called()
    use_case._sleep.assert_not_called()


@pytest.mark.parametrize(
    "final_result",
    [
        AuthorizeResult(
            outcome=AuthorizationGatewayOutcome.APPROVED,
            response_code="00",
        ),
        AuthorizeResult(
            outcome=AuthorizationGatewayOutcome.DECLINED,
            response_code="51",
        ),
    ],
)
def test_retries_not_sent_then_stops_on_definitive_result(
    final_result: AuthorizeResult,
) -> None:
    use_case, transactions, _, gateway = _build(
        gateway_results=[
            AuthorizeResult(outcome=AuthorizationGatewayOutcome.NOT_SENT),
            final_result,
        ],
        max_authorization_attempts=3,
    )

    use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="stable-key",
        product="GARRAFA_10",
        amount="2",
        card_number="4111111111111111",
    )

    assert gateway.authorize.call_count == 2
    first_request = gateway.authorize.call_args_list[0].args[0]
    second_request = gateway.authorize.call_args_list[1].args[0]
    assert second_request is first_request
    assert first_request.idempotency_key == "stable-key"
    assert first_request.stan == second_request.stan
    assert first_request.ticket_number == second_request.ticket_number
    use_case._sleep.assert_called_once_with(0.1)
    assert [
        call.kwargs["outcome"]
        for call in transactions.record_authorization_attempt.call_args_list
    ] == [
        AuthorizationOutcome.NOT_SENT,
        AuthorizationOutcome(final_result.outcome.value),
    ]
    assert use_case._configs.get_default.call_count == 1


def test_indeterminate_stops_without_retry_even_when_attempts_remain() -> None:
    use_case, transactions, _, gateway = _build(
        gateway_result=AuthorizeResult(
            outcome=AuthorizationGatewayOutcome.INDETERMINATE
        ),
        max_authorization_attempts=3,
    )

    use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="k1",
        product="GARRAFA_10",
        amount="2",
        card_number="4111111111111111",
    )

    gateway.authorize.assert_called_once()
    transactions.start_authorization_retry.assert_not_called()
    use_case._sleep.assert_not_called()


def test_exhausted_not_sent_attempts_publish_failed() -> None:
    not_sent = AuthorizeResult(outcome=AuthorizationGatewayOutcome.NOT_SENT)
    use_case, transactions, _, gateway = _build(
        gateway_results=[not_sent, not_sent, not_sent],
        max_authorization_attempts=3,
    )
    transactions.update_result.return_value = _tx(status=TransactionStatus.FAILED)

    result = use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="k1",
        product="GARRAFA_10",
        amount="2",
        card_number="4111111111111111",
    )

    assert gateway.authorize.call_count == 3
    assert use_case._sleep.call_args_list == [call(0.1), call(0.2)]
    assert transactions.start_authorization_retry.call_count == 2
    assert result.transaction.status == TransactionStatus.FAILED
    final = transactions.update_result.call_args.kwargs
    assert final["authorization_outcome"] == AuthorizationOutcome.NOT_SENT


def test_sync_budget_prevents_retry_when_delay_does_not_fit() -> None:
    clock = MagicMock(side_effect=[0.0, 0.95])
    use_case, transactions, _, gateway = _build(
        gateway_result=AuthorizeResult(outcome=AuthorizationGatewayOutcome.NOT_SENT),
        max_authorization_attempts=3,
        processing_timeout_seconds=1,
        monotonic=clock,
    )

    use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="k1",
        product="GARRAFA_10",
        amount="2",
        card_number="4111111111111111",
    )

    gateway.authorize.assert_called_once()
    transactions.start_authorization_retry.assert_not_called()
    use_case._sleep.assert_not_called()


def test_gateway_declined() -> None:
    use_case, transactions, _, _ = _build(
        gateway_result=AuthorizeResult(
            outcome=AuthorizationGatewayOutcome.DECLINED,
            response_code="51",
        ),
    )
    transactions.update_result.return_value = _tx(status=TransactionStatus.DECLINED)
    result = use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="k1",
        product="GARRAFA_10",
        amount="2",
        card_number="4111111111111111",
        cvv="123",
        expiration_date="2912",
    )
    assert result.transaction.status == TransactionStatus.DECLINED
    kwargs = transactions.update_result.call_args.kwargs
    assert kwargs["authorization_outcome"] == AuthorizationOutcome.DECLINED


def test_pending_recovery_data_is_committed_before_gateway_call() -> None:
    use_case, transactions, _, gateway = _build()

    def authorize_after_commit(request: object) -> AuthorizeResult:
        use_case._session.commit.assert_called_once()
        create_kwargs = transactions.create_pending.call_args.kwargs
        assert create_kwargs["card_number"] == "6063007014007403"
        assert create_kwargs["expiration_date"] == "2912"
        assert "cvv" not in create_kwargs
        return AuthorizeResult(
            outcome=AuthorizationGatewayOutcome.APPROVED,
            response_code="00",
        )

    gateway.authorize.side_effect = authorize_after_commit
    use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="k1",
        product="GARRAFA_10",
        amount="2",
        card_number="6063007014007403",
        cvv="123",
        expiration_date="2912",
    )


def test_fingerprint_uses_full_normalized_pan_not_only_last4() -> None:
    from application.payments.create_transaction import _fingerprint

    first = _fingerprint(
        product=Product.GARRAFA_10,
        amount_minor=200,
        card_number="4111111111111111",
        expiration_date="3012",
    )
    second = _fingerprint(
        product=Product.GARRAFA_10,
        amount_minor=200,
        card_number="5555555555551111",
        expiration_date="3012",
    )

    assert first != second


def test_invalid_cvv() -> None:
    from domain.exceptions import InvalidCvv

    use_case, *_ = _build()
    with pytest.raises(InvalidCvv):
        use_case.execute(
            user_id=1,
            installation_id="inst-1",
            idempotency_key="k1",
            product="GARRAFA_10",
            amount="2",
            card_number="4111111111111111",
            cvv="12",
        )


def test_allows_empty_cvv_for_card_capture() -> None:
    """El CVV es opcional porque no se usa en el flujo legacy."""
    use_case, transactions, _, gateway = _build()
    result = use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="k1",
        product="GARRAFA_10",
        amount="2",
        card_number="6063007014007403",
        cvv="",
        expiration_date="2912",
    )
    assert result.http_status == CreateTransactionHttpStatus.CREATED
    assert result.transaction.status == TransactionStatus.APPROVED
    gateway.authorize.assert_called_once()
    auth_req = gateway.authorize.call_args.args[0]
    assert auth_req.card_number == "6063007014007403"
    assert auth_req.expiration_date == "2912"
    transactions.create_pending.assert_called_once()
    transactions.update_result.assert_called_once()


def test_empty_terminal_string() -> None:
    use_case, *_ = _build(installation_code="   ")
    with pytest.raises(MissingTerminalId):
        use_case.execute(
            user_id=1,
            installation_id="inst-1",
            idempotency_key="k1",
            product="GARRAFA_10",
            amount="2",
            card_number="4111111111111111",
            cvv="123",
        )


def test_integrity_error_replays_existing() -> None:
    from sqlalchemy.exc import IntegrityError

    from application.payments.create_transaction import _fingerprint

    fp = _fingerprint(
        product=Product.GARRAFA_10,
        amount_minor=200,
        card_number="4111111111111111",
        expiration_date=None,
    )
    existing = _tx(status=TransactionStatus.APPROVED, request_fingerprint=fp)
    use_case, transactions, _, gateway = _build()
    transactions.create_pending.side_effect = IntegrityError("x", {}, None)
    transactions.get_by_idempotency.side_effect = [None, existing]
    result = use_case.execute(
        user_id=existing.user_id,
        installation_id="inst-1",
        idempotency_key="key-1",
        product="GARRAFA_10",
        amount="2",
        card_number="4111111111111111",
        cvv="123",
    )
    assert result.transaction.status == TransactionStatus.APPROVED
    gateway.authorize.assert_not_called()


def test_fractional_quantity_rejected_for_unit_product() -> None:
    use_case, _, _, gateway = _build()
    with pytest.raises(InvalidAmount, match="número entero"):
        use_case.execute(
            user_id=1,
            installation_id="inst-1",
            idempotency_key="k1",
            product="GARRAFA_10",
            amount="3.50",
            card_number="4111111111111111",
            cvv="123",
        )
    gateway.authorize.assert_not_called()


def test_fractional_quantity_allowed_for_bulk() -> None:
    use_case, _, _, gateway = _build()
    result = use_case.execute(
        user_id=1,
        installation_id="inst-1",
        idempotency_key="k1",
        product="GRANEL",
        amount="2.50",
        card_number="4111111111111111",
        cvv="123",
    )
    assert result.http_status == CreateTransactionHttpStatus.CREATED
    gateway.authorize.assert_called_once()
