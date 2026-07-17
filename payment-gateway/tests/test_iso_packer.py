from datetime import datetime

import pytest

from config.settings import Settings
from domain.authorization import AuthorizationStatus, AuthorizeCommand
from domain.exceptions import IsoPackError
from infrastructure.iso.codec import (
    asc_to_bcd,
    bcd_to_asc,
    bitmap_get,
    int_to_longitude_bcd,
    int_to_longitude_hex,
    longitude_to_int_bcd,
    longitude_to_int_hex,
)
from infrastructure.iso.message_builder import build_purchase_request
from infrastructure.iso.packer import IsoMessage, pack_iso, set_present, unpack_iso
from infrastructure.iso.response_mapper import map_iso_response


def test_bcd_roundtrip_even() -> None:
    raw = asc_to_bcd("123456")
    assert bcd_to_asc(6, raw) == "123456"


def test_bcd_odd_pads_f() -> None:
    raw = asc_to_bcd("123")
    assert raw == bytes([0x12, 0x3F])
    assert bcd_to_asc(3, raw) == "123"


def test_bcd_hex_letters() -> None:
    raw = asc_to_bcd("AB")
    assert bcd_to_asc(2, raw) == "AB"


def test_hex_length_roundtrip() -> None:
    encoded = int_to_longitude_hex(300)
    assert longitude_to_int_hex(encoded[0], encoded[1]) == 300


def test_bcd_length_roundtrip() -> None:
    encoded = int_to_longitude_bcd(42)
    assert longitude_to_int_bcd(encoded[0], encoded[1]) == 42


def test_int_to_longitude_hex_rejects_out_of_range() -> None:
    with pytest.raises(ValueError):
        int_to_longitude_hex(-1)
    with pytest.raises(ValueError):
        int_to_longitude_bcd(10000)


def test_pack_unpack_purchase_fields() -> None:
    iso = IsoMessage(
        tpdu="6000030000",
        mtype="0200",
        pan_2="4111111111111111",
        procode_3="000000",
        amount_4="000000150050",
        systracenum_11="123456",
        timetrx_12="121530",
        datetrx_13="0716",
        posentrymode_22="0120",
        nii_24="0003",
        poscondcode_25="00",
        termid_41="TERM0001",
        currcode_49="032",
    )
    set_present(iso, 2, 3, 4, 11, 12, 13, 22, 24, 25, 41, 49)
    frame = pack_iso(iso)
    assert len(frame) >= 2
    parsed = unpack_iso(frame)
    assert parsed.mtype == "0200"
    assert parsed.pan_2 == "4111111111111111"
    assert parsed.amount_4 == "000000150050"
    assert parsed.systracenum_11 == "123456"
    assert parsed.termid_41 == "TERM0001"
    assert parsed.currcode_49 == "032"
    assert bitmap_get(parsed.bitmap, 2)
    assert bitmap_get(parsed.bitmap, 4)


def test_pack_unpack_optional_fields() -> None:
    iso = IsoMessage(
        tpdu="6000030000",
        mtype="0210",
        dateexpire_14="2912",
        datesettle_15="0716",
        track2_35="4111111111111111D2912",
        retrefnum_37="123456789012",
        authid_38="AUTH01",
        respcode_39="00",
        track1_45="B4111111111111111^TEST",
        settcurrcode_50="032",
        addamount_54="EXTRA",
        cvv_55="123",
        field_59="F59",
        field_60="F60",
        field_61="F61",
        field_62="F62",
        field_63="OK",
    )
    set_present(
        iso,
        14,
        15,
        35,
        37,
        38,
        39,
        45,
        50,
        54,
        55,
        59,
        60,
        61,
        62,
        63,
    )
    frame = pack_iso(iso)
    parsed = unpack_iso(frame)
    assert parsed.dateexpire_14 == "2912"
    assert parsed.datesettle_15 == "0716"
    assert parsed.track2_35 == "4111111111111111D2912"
    assert parsed.retrefnum_37 == "123456789012"
    assert parsed.authid_38 == "AUTH01"
    assert parsed.respcode_39 == "00"
    assert parsed.track1_45 == "B4111111111111111^TEST"
    assert parsed.settcurrcode_50 == "032"
    assert parsed.addamount_54 == "EXTRA"
    assert parsed.cvv_55 == "123"
    assert parsed.field_59 == "F59"
    assert parsed.field_60 == "F60"
    assert parsed.field_61 == "F61"
    assert parsed.field_62 == "F62"
    assert parsed.field_63 == "OK"


def test_unpack_rejects_short_and_incomplete() -> None:
    with pytest.raises(IsoPackError):
        unpack_iso(b"\x00")
    with pytest.raises(IsoPackError):
        unpack_iso(b"\x00\x10" + b"\x00" * 5)


def test_build_purchase_request_sets_fields() -> None:
    settings = Settings()
    cmd = AuthorizeCommand(
        product_code="993",
        amount_minor=150050,
        card_number="4111111111111111",
        terminal_id="TERM0001",
        stan="000001",
        expiration_date="2912",
    )
    iso = build_purchase_request(
        cmd,
        settings,
        now=datetime(2026, 7, 16, 12, 15, 30),
    )
    assert iso.mtype == "0200"
    assert iso.amount_4 == "000000150050"
    assert iso.timetrx_12 == "121530"
    assert iso.datetrx_13 == "0716"
    assert iso.dateexpire_14 == "2912"
    assert iso.currcode_49 == "993"
    assert iso.termid_41 == "TERM0001"
    assert not bitmap_get(iso.bitmap, 42)


def test_map_iso_response_approved() -> None:
    iso = IsoMessage(respcode_39="00", authid_38="ABC123", retrefnum_37="123456789012")
    result = map_iso_response(iso)
    assert result.status == AuthorizationStatus.APPROVED
    assert result.auth_id == "ABC123"


def test_map_iso_response_declined() -> None:
    iso = IsoMessage(respcode_39="05")
    result = map_iso_response(iso)
    assert result.status == AuthorizationStatus.DECLINED
