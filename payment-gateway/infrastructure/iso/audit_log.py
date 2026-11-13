"""Sanitized ISO exchange log.

The event is support evidence of what the gateway sent and what came back.
PAN, expiry, track, CVV and the raw frame are never included.
"""

import logging

from domain.authorization import AuthorizationResult
from domain.balance import BalanceResult
from domain.reversal import ReversalResult
from infrastructure.iso.packer import IsoMessage

logger = logging.getLogger(__name__)

ProcessorResult = AuthorizationResult | BalanceResult | ReversalResult


def card_last4(card_number: str) -> str | None:
    digits = "".join(character for character in card_number if character.isdigit())
    if not 13 <= len(digits) <= 19:
        return None
    return digits[-4:]


def log_iso_exchange(
    *,
    operation: str,
    transport: str,
    request: IsoMessage,
    outcome: str,
    response_mti: str | None = None,
    response_code: str | None = None,
    auth_id: str | None = None,
    retrieval_reference: str | None = None,
) -> None:
    """Emit one ``iso_exchange`` event from an allowlist of ISO fields."""
    pan_digits = "".join(
        character for character in request.pan_2 if character.isdigit()
    )
    fields = {
        "event_name": "iso_exchange",
        "operation": operation,
        "transport": transport,
        "mti": _blank(request.mtype),
        "amount": _blank(request.amount_4),
        "stan": _blank(request.systracenum_11),
        "terminal_id": _blank(request.termid_41),
        "merchant_code": _blank(request.merchid_42),
        "card_last4": card_last4(request.pan_2),
        "outcome": outcome,
        "response_mti": _blank(response_mti),
        "response_code": _blank(response_code),
        "auth_id": _blank(auth_id),
        "retrieval_reference": _blank(retrieval_reference),
    }
    logger.info(
        "iso_exchange",
        extra={key: _scrub(value, pan_digits) for key, value in fields.items()},
    )


def result_auth_id(result: ProcessorResult) -> str | None:
    if isinstance(result, AuthorizationResult):
        return result.auth_id
    return None


def result_retrieval_reference(result: ProcessorResult) -> str | None:
    if isinstance(result, AuthorizationResult):
        return result.retrieval_reference
    return None


def _blank(value: str | None) -> str | None:
    if value is None:
        return None
    stripped = value.strip()
    return stripped or None


def _scrub(value: str | None, pan_digits: str) -> str | None:
    if value is None or len(pan_digits) < 13 or pan_digits not in value:
        return value
    masked = f"{'*' * (len(pan_digits) - 4)}{pan_digits[-4:]}"
    return value.replace(pan_digits, masked)
