import json
from pathlib import Path
from typing import Any

from infrastructure.iso.codec import bitmap_get
from infrastructure.iso.packer import unpack_iso

_FIXTURE_PATH = Path(__file__).parent / "fixtures" / "legacy_reversal_contract.json"


def _fixture() -> dict[str, Any]:
    return json.loads(_FIXTURE_PATH.read_text(encoding="utf-8"))


def _captures() -> dict[str, dict[str, Any]]:
    return {capture["name"]: capture for capture in _fixture()["captures"]}


def test_recorded_reversal_frames_match_the_legacy_wire_contract() -> None:
    fixture = _fixture()
    recorded_bits = fixture["recorded_request_bits"]
    reversals = [
        capture
        for capture in fixture["captures"]
        if capture["name"].startswith("reversal_")
    ]

    assert len(reversals) == 4
    for capture in reversals:
        request = unpack_iso(bytes.fromhex(capture["request_hex"]))
        response = unpack_iso(bytes.fromhex(capture["response_hex"]))

        assert request.mtype == "0400"
        assert all(bitmap_get(request.bitmap, bit) for bit in recorded_bits)
        assert request.procode_3 == "000000"
        assert response.mtype == "0410"
        assert response.respcode_39 == capture["response_code"] == "00"


def test_response_00_is_accepted_for_existing_and_missing_original() -> None:
    captures = _captures()

    existing = captures["reversal_existing_sale"]
    missing = captures["reversal_missing_sale"]

    assert existing["response_code"] == missing["response_code"] == "00"
    assert existing["database_rows_after"] == {"0400": 2}
    assert missing["database_rows_after"] == {"0400": 1}
    assert (
        existing["safe_outcome"]
        == missing["safe_outcome"]
        == "REVERSED_CONFIRMED"
    )


def test_repeated_reversal_is_not_persistence_idempotent() -> None:
    captures = _captures()
    first = captures["reversal_existing_sale"]
    duplicate = captures["reversal_duplicate"]

    assert first["request_hex"] == duplicate["request_hex"]
    assert first["response_code"] == duplicate["response_code"] == "00"
    assert first["database_rows_after"] == {"0400": 2}
    assert duplicate["database_rows_after"] == {"0400": 3}
    assert duplicate["safe_outcome"] == "REVERSED_CONFIRMED"


def test_early_reversal_does_not_neutralize_a_later_sale() -> None:
    captures = _captures()
    reversal = captures["reversal_before_sale"]
    later_sale = captures["sale_after_early_reversal"]

    assert reversal["response_code"] == "00"
    assert reversal["safe_outcome"] == "OUT_OF_CONTRACT"
    assert later_sale["response_code"] == "00"
    assert later_sale["database_rows_after"] == {"0200": 1, "0400": 1}
