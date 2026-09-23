from datetime import datetime

from config.settings import Settings
from domain.authorization import AuthorizationStatus
from domain.balance import BalanceCommand
from infrastructure.iso.codec import bitmap_get
from infrastructure.iso.message_builder import build_balance_request
from infrastructure.iso.packer import IsoMessage, pack_iso, unpack_iso
from infrastructure.iso.response_mapper import map_balance_response


def test_build_balance_request_sets_fields() -> None:
    settings = Settings()
    cmd = BalanceCommand(
        product_code="993",
        card_number="6063007014007403",
        terminal_id="TERM0001",
        stan="000001",
        expiration_date="1228",
        entry_mode="012",
    )
    iso = build_balance_request(
        cmd,
        settings,
        now=datetime(2026, 7, 16, 12, 15, 30),
    )
    assert iso.mtype == "0100"
    assert iso.procode_3 == "310000"
    assert iso.pan_2 == "6063007014007403"
    assert iso.currcode_49 == "993"
    assert iso.dateexpire_14 == "1228"
    assert iso.posentrymode_22 == "0012"
    assert iso.nii_24 == "0003"
    assert iso.termid_41 == "TERM0001"
    assert bitmap_get(iso.bitmap, 2)
    assert bitmap_get(iso.bitmap, 3)
    assert bitmap_get(iso.bitmap, 14)
    assert bitmap_get(iso.bitmap, 24)
    assert bitmap_get(iso.bitmap, 41)
    assert bitmap_get(iso.bitmap, 49)
    assert not bitmap_get(iso.bitmap, 4)
    assert not bitmap_get(iso.bitmap, 35)

    parsed = unpack_iso(pack_iso(iso))
    assert parsed.mtype == "0100"
    assert parsed.currcode_49 == "993"


def test_build_balance_request_with_track2() -> None:
    settings = Settings()
    cmd = BalanceCommand(
        product_code="993",
        card_number="6063007014007403",
        terminal_id="TERM0001",
        stan="000001",
        entry_mode="022",
        track2=";6063007014007403=1228?101",
    )
    iso = build_balance_request(
        cmd,
        settings,
        now=datetime(2026, 7, 16, 12, 15, 30),
    )
    assert iso.track2_35 == "6063007014007403=1228"
    assert iso.posentrymode_22 == "0022"
    assert bitmap_get(iso.bitmap, 35)


def test_map_balance_response_approved() -> None:
    iso = IsoMessage(
        respcode_39="00",
        amount_4="000000010000",
        field_63="Tipo de asignacion: Garrafa 10 kg",
    )
    result = map_balance_response(iso)
    assert result.status == AuthorizationStatus.APPROVED
    assert result.response_code == "00"
    assert result.available_balance_minor == 10000
    assert result.assigned_products == "Tipo de asignacion: Garrafa 10 kg"


def test_map_balance_response_declined_without_amount() -> None:
    iso = IsoMessage(respcode_39="06")
    result = map_balance_response(iso)
    assert result.status == AuthorizationStatus.DECLINED
    assert result.response_code == "06"
    assert result.available_balance_minor is None
    assert result.assigned_products is None
