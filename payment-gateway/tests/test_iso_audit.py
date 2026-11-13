import logging
from unittest.mock import MagicMock, patch

import pytest

from config.settings import Settings
from domain.authorization import AuthorizeCommand
from domain.exceptions import IsoPackError, ProcessorUnavailable, ProcessorUnreachable
from infrastructure.iso.audit_log import card_last4, log_iso_exchange
from infrastructure.iso.mock_processor import MockIsoProcessor
from infrastructure.iso.packer import IsoMessage, pack_iso, set_present
from infrastructure.iso.tcp_processor import TcpIsoProcessor

PAN = "4111111111111111"
EXPIRY = "2912"
TRACK2 = "4111111111111111=29121234567890"
TRACK1 = "B4111111111111111^TEST/CARD^2912"
CVV = "7391"


def _command() -> AuthorizeCommand:
    return AuthorizeCommand(
        product_code="993",
        amount_minor=100,
        card_number=PAN,
        terminal_id="TERM0001",
        merchant_code="012502",
        stan="000001",
        ticket_number="00000001",
        expiration_date=EXPIRY,
    )


def _approved_frame() -> bytes:
    iso = IsoMessage(
        tpdu="6000030000",
        mtype="0210",
        respcode_39="00",
        authid_38="AUTH01",
        retrefnum_37="123456789012",
        systracenum_11="000001",
    )
    set_present(iso, 11, 37, 38, 39)
    return pack_iso(iso)


def _exchange_record(caplog: pytest.LogCaptureFixture) -> logging.LogRecord:
    records = [record for record in caplog.records if record.message == "iso_exchange"]
    assert len(records) == 1
    return records[0]


def _assert_secrets_absent(caplog: pytest.LogCaptureFixture) -> None:
    rendered = [caplog.text]
    for record in caplog.records:
        rendered.extend(str(value) for value in record.__dict__.values())
    text = "\n".join(rendered)
    assert PAN not in text
    assert EXPIRY not in text
    assert TRACK2 not in text
    assert TRACK1 not in text
    assert CVV not in text


def test_card_last4_rejects_a_short_number() -> None:
    assert card_last4("411111") is None
    assert card_last4(PAN) == "1111"


def test_log_keeps_operational_fields_and_drops_card_secrets(
    caplog: pytest.LogCaptureFixture,
) -> None:
    request = IsoMessage(
        mtype="0200",
        pan_2=PAN,
        amount_4="000000000100",
        systracenum_11="000001",
        dateexpire_14=EXPIRY,
        track2_35=TRACK2,
        termid_41="TERM0001",
        merchid_42=PAN,
        track1_45=TRACK1,
        cvv_55=CVV,
    )

    with caplog.at_level(logging.INFO):
        log_iso_exchange(
            operation="authorize",
            transport="tcp",
            request=request,
            outcome="sent",
            response_mti="0210",
            response_code="00",
            auth_id="AUTH01",
            retrieval_reference="123456789012",
        )

    record = _exchange_record(caplog)
    assert record.event_name == "iso_exchange"
    assert record.operation == "authorize"
    assert record.transport == "tcp"
    assert record.mti == "0200"
    assert record.amount == "000000000100"
    assert record.stan == "000001"
    assert record.terminal_id == "TERM0001"
    assert record.merchant_code == "************1111"
    assert record.card_last4 == "1111"
    assert record.outcome == "sent"
    assert record.response_mti == "0210"
    assert record.response_code == "00"
    assert record.auth_id == "AUTH01"
    assert record.retrieval_reference == "123456789012"
    _assert_secrets_absent(caplog)
    assert not hasattr(record, "pan_2")
    assert not hasattr(record, "dateexpire_14")
    assert not hasattr(record, "track2_35")
    assert not hasattr(record, "cvv_55")


def test_tcp_authorize_logs_the_exchange_without_card_secrets(
    caplog: pytest.LogCaptureFixture,
) -> None:
    processor = TcpIsoProcessor(Settings(iso_transport="tcp"))
    frame = _approved_frame()

    with (
        caplog.at_level(logging.INFO),
        patch("infrastructure.iso.tcp_processor.socket.create_connection") as conn,
    ):
        sock = MagicMock()
        conn.return_value.__enter__.return_value = sock
        sock.recv.side_effect = [frame[:2], frame[2:]]
        processor.authorize(_command())

    record = _exchange_record(caplog)
    assert record.transport == "tcp"
    assert record.outcome == "sent"
    assert record.mti == "0200"
    assert record.stan == "000001"
    assert record.terminal_id == "TERM0001"
    assert record.merchant_code == "012502"
    assert record.response_code == "00"
    assert record.auth_id == "AUTH01"
    assert record.card_last4 == "1111"
    _assert_secrets_absent(caplog)


def test_tcp_authorize_logs_not_sent_when_connect_fails(
    caplog: pytest.LogCaptureFixture,
) -> None:
    processor = TcpIsoProcessor(Settings(iso_transport="tcp"))
    with (
        caplog.at_level(logging.INFO),
        patch(
            "infrastructure.iso.tcp_processor.socket.create_connection",
            side_effect=TimeoutError(),
        ),
        pytest.raises(ProcessorUnreachable),
    ):
        processor.authorize(_command())

    record = _exchange_record(caplog)
    assert record.outcome == "not_sent"
    assert record.stan == "000001"
    assert record.terminal_id == "TERM0001"
    assert record.card_last4 == "1111"
    _assert_secrets_absent(caplog)


def test_tcp_authorize_logs_indeterminate_on_read_timeout(
    caplog: pytest.LogCaptureFixture,
) -> None:
    processor = TcpIsoProcessor(Settings(iso_transport="tcp"))
    sock = MagicMock()
    sock.recv.side_effect = TimeoutError()
    with (
        caplog.at_level(logging.INFO),
        patch("infrastructure.iso.tcp_processor.socket.create_connection") as conn,
        pytest.raises(ProcessorUnavailable) as exc_info,
    ):
        conn.return_value.__enter__.return_value = sock
        processor.authorize(_command())

    assert not isinstance(exc_info.value, ProcessorUnreachable)
    record = _exchange_record(caplog)
    assert record.outcome == "indeterminate"
    assert record.stan == "000001"
    assert record.terminal_id == "TERM0001"
    _assert_secrets_absent(caplog)


def test_tcp_authorize_logs_invalid_response(
    caplog: pytest.LogCaptureFixture,
) -> None:
    processor = TcpIsoProcessor(Settings(iso_transport="tcp"))
    with (
        caplog.at_level(logging.INFO),
        patch("infrastructure.iso.tcp_processor.socket.create_connection") as conn,
    ):
        sock = MagicMock()
        conn.return_value.__enter__.return_value = sock
        sock.recv.side_effect = [b"\x00\x02", b"\xff\xff"]
        processor.authorize(_command())

    record = _exchange_record(caplog)
    assert record.outcome == "invalid_response"
    assert record.response_code == "96"
    _assert_secrets_absent(caplog)


def test_tcp_authorize_logs_not_sent_when_packing_fails(
    caplog: pytest.LogCaptureFixture,
) -> None:
    processor = TcpIsoProcessor(Settings(iso_transport="tcp"))
    with (
        caplog.at_level(logging.INFO),
        patch(
            "infrastructure.iso.tcp_processor.pack_iso",
            side_effect=ValueError("boom"),
        ),
        pytest.raises(IsoPackError),
    ):
        processor.authorize(_command())

    record = _exchange_record(caplog)
    assert record.outcome == "not_sent"
    assert PAN not in caplog.text
    assert "boom" not in caplog.text


def test_mock_authorize_logs_the_same_event(
    caplog: pytest.LogCaptureFixture,
) -> None:
    with caplog.at_level(logging.INFO):
        MockIsoProcessor().authorize(_command())

    record = _exchange_record(caplog)
    assert record.transport == "mock"
    assert record.operation == "authorize"
    assert record.mti == "0200"
    assert record.response_mti == "0210"
    assert record.outcome == "sent"
    assert record.response_code == "00"
    assert record.auth_id == "MOCK01"
    assert record.card_last4 == "1111"
    _assert_secrets_absent(caplog)
