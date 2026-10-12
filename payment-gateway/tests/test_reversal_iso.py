import json
from datetime import datetime
from pathlib import Path
from unittest.mock import MagicMock, patch

from config.settings import Settings
from domain.reversal import ReversalStatus, ReverseCommand
from infrastructure.iso.codec import bitmap_get
from infrastructure.iso.message_builder import (
    build_reversal_request,
    build_void_request,
)
from infrastructure.iso.mock_processor import MockIsoProcessor
from infrastructure.iso.packer import IsoMessage, pack_iso, set_present, unpack_iso
from infrastructure.iso.response_mapper import map_reversal_response
from infrastructure.iso.tcp_processor import TcpIsoProcessor

_FIXTURE_PATH = Path(__file__).parent / "fixtures" / "legacy_reversal_contract.json"
_EXPECTED_BITS = {2, 3, 4, 11, 12, 13, 14, 22, 24, 25, 41, 49, 62}


def _command(**overrides: object) -> ReverseCommand:
    values: dict[str, object] = {
        "product_code": "993",
        "amount_minor": 10_000,
        "card_number": "6063007014007403",
        "expiration_date": "1228",
        "terminal_id": "05000001",
        "original_stan": "890001",
        "original_ticket": "890001",
        "reversal_stan": "654321",
    }
    values.update(overrides)
    return ReverseCommand(**values)  # type: ignore[arg-type]


def _response_frame(*, code: str = "00", mtype: str = "0410") -> bytes:
    response = IsoMessage(
        tpdu="6000000003",
        mtype=mtype,
        respcode_39=code,
        systracenum_11="890001",
    )
    set_present(response, 11, 39)
    return pack_iso(response)


def test_build_reversal_matches_ra00_binary_vector() -> None:
    fixture = json.loads(_FIXTURE_PATH.read_text(encoding="utf-8"))
    expected = next(
        capture["request_hex"]
        for capture in fixture["captures"]
        if capture["name"] == "reversal_existing_sale"
    )

    message = build_reversal_request(
        _command(),
        Settings(),
        now=datetime(2026, 10, 12, 12, 0, 0),
    )

    assert pack_iso(message).hex() == expected


def test_build_reversal_contains_only_characterized_fields() -> None:
    message = build_reversal_request(
        _command(),
        Settings(),
        now=datetime(2026, 10, 12, 12, 0, 0),
    )

    present_bits = {bit for bit in range(1, 65) if bitmap_get(message.bitmap, bit)}
    assert present_bits == _EXPECTED_BITS
    assert message.mtype == "0400"
    assert message.procode_3 == "000000"
    assert message.systracenum_11 == "890001"
    assert message.field_62 == "890001"
    assert message.retrefnum_37 == ""
    assert message.field_60 == ""
    assert message.field_63 == ""


def test_build_reversal_normalizes_original_identifiers() -> None:
    message = build_reversal_request(
        _command(
            expiration_date="12/28",
            terminal_id="0500000199",
            original_stan="89-0001",
            original_ticket="ticket-890001",
        ),
        Settings(),
        now=datetime(2026, 10, 12, 12, 0, 0),
    )

    assert message.dateexpire_14 == "1228"
    assert message.termid_41 == "05000001"
    assert message.systracenum_11 == "890001"
    assert message.field_62 == "890001"


def test_reversal_stan_does_not_replace_original_wire_identifiers() -> None:
    first = build_reversal_request(
        _command(reversal_stan="000001"),
        Settings(),
        now=datetime(2026, 10, 12, 12, 0, 0),
    )
    repeated = build_reversal_request(
        _command(reversal_stan="000001"),
        Settings(),
        now=datetime(2026, 10, 12, 12, 0, 0),
    )

    assert first.systracenum_11 == "890001"
    assert pack_iso(first) == pack_iso(repeated)


def test_reversal_builder_is_distinct_from_void_builder() -> None:
    reverse = build_reversal_request(
        _command(),
        Settings(),
        now=datetime(2026, 10, 12, 12, 0, 0),
    )

    # A reverse is never represented by the void-only processing code/fields.
    assert reverse.mtype == "0400"
    assert reverse.procode_3 == "000000"
    assert not bitmap_get(reverse.bitmap, 37)
    assert not bitmap_get(reverse.bitmap, 60)
    assert build_void_request is not build_reversal_request


def test_map_reversal_00_is_indeterminate() -> None:
    result = map_reversal_response(unpack_iso(_response_frame()))

    assert result.status == ReversalStatus.INDETERMINATE
    assert result.response_code == "00"


def test_map_reversal_nonzero_is_processor_declined() -> None:
    result = map_reversal_response(unpack_iso(_response_frame(code="05")))

    assert result.status == ReversalStatus.PROCESSOR_DECLINED
    assert result.response_code == "05"


def test_map_reversal_rejects_unexpected_response_mti() -> None:
    result = map_reversal_response(unpack_iso(_response_frame(mtype="0210")))

    assert result.status == ReversalStatus.INDETERMINATE
    assert result.response_code == "96"


def test_tcp_reverse_sends_one_characterized_request() -> None:
    processor = TcpIsoProcessor(Settings(iso_transport="tcp"))
    response = _response_frame()

    with patch("infrastructure.iso.tcp_processor.socket.create_connection") as conn:
        sock = MagicMock()
        conn.return_value.__enter__.return_value = sock
        sock.recv.side_effect = [response[:2], response[2:]]
        result = processor.reverse(_command())

    assert result.status == ReversalStatus.INDETERMINATE
    sock.sendall.assert_called_once()
    sent = unpack_iso(sock.sendall.call_args.args[0])
    assert sent.mtype == "0400"
    assert sent.systracenum_11 == "890001"


def test_tcp_reverse_invalid_response_is_indeterminate() -> None:
    processor = TcpIsoProcessor(Settings(iso_transport="tcp"))

    with patch("infrastructure.iso.tcp_processor.socket.create_connection") as conn:
        sock = MagicMock()
        conn.return_value.__enter__.return_value = sock
        sock.recv.side_effect = [b"\x00\x02", b"\xff\xff"]
        result = processor.reverse(_command())

    assert result.status == ReversalStatus.INDETERMINATE
    assert result.response_code == "96"
    sock.sendall.assert_called_once()


def test_mock_reverse_preserves_safe_legacy_classification() -> None:
    processor = MockIsoProcessor()

    result = processor.reverse(_command())
    declined = processor.reverse(_command(card_number=processor.DECLINE_PAN))

    assert result.status == ReversalStatus.INDETERMINATE
    assert declined.status == ReversalStatus.PROCESSOR_DECLINED
