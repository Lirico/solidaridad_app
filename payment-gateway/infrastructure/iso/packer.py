"""ISO8583 message pack/unpack for the KIG dialect (iso_common.c)."""

from dataclasses import dataclass, field

from domain.exceptions import IsoPackError
from infrastructure.iso.codec import (
    asc_to_bcd,
    bcd_to_asc,
    bitmap_get,
    bitmap_set,
    int_to_longitude_bcd,
    int_to_longitude_hex,
    longitude_to_int_bcd,
    longitude_to_int_hex,
)


@dataclass
class IsoMessage:
    tpdu: str = ""
    mtype: str = ""
    bitmap: bytearray = field(default_factory=lambda: bytearray(8))
    pan_2: str = ""
    procode_3: str = ""
    amount_4: str = ""
    systracenum_11: str = ""
    timetrx_12: str = ""
    datetrx_13: str = ""
    dateexpire_14: str = ""
    datesettle_15: str = ""
    posentrymode_22: str = ""
    nii_24: str = ""
    poscondcode_25: str = ""
    track2_35: str = ""
    retrefnum_37: str = ""
    authid_38: str = ""
    respcode_39: str = ""
    termid_41: str = ""
    merchid_42: str = ""
    track1_45: str = ""
    currcode_49: str = ""
    settcurrcode_50: str = ""
    addamount_54: str = ""
    cvv_55: str = ""
    field_59: str = ""
    field_60: str = ""
    field_61: str = ""
    field_62: str = ""
    field_63: str = ""


def pack_iso(iso: IsoMessage) -> bytes:
    """Pack message including 2-byte hex length prefix (full wire frame)."""
    body = bytearray()
    body.extend(asc_to_bcd(iso.tpdu))
    body.extend(asc_to_bcd(iso.mtype))
    body.extend(iso.bitmap)

    if bitmap_get(iso.bitmap, 2):
        body.extend(int_to_longitude_bcd(len(iso.pan_2))[1:2])
        body.extend(asc_to_bcd(iso.pan_2))
    if bitmap_get(iso.bitmap, 3):
        body.extend(asc_to_bcd(iso.procode_3))
    if bitmap_get(iso.bitmap, 4):
        body.extend(asc_to_bcd(iso.amount_4))
    if bitmap_get(iso.bitmap, 11):
        body.extend(asc_to_bcd(iso.systracenum_11))
    if bitmap_get(iso.bitmap, 12):
        body.extend(asc_to_bcd(iso.timetrx_12))
    if bitmap_get(iso.bitmap, 13):
        body.extend(asc_to_bcd(iso.datetrx_13))
    if bitmap_get(iso.bitmap, 14):
        body.extend(asc_to_bcd(iso.dateexpire_14))
    if bitmap_get(iso.bitmap, 15):
        body.extend(asc_to_bcd(iso.datesettle_15))
    if bitmap_get(iso.bitmap, 22):
        body.extend(asc_to_bcd(iso.posentrymode_22))
    if bitmap_get(iso.bitmap, 24):
        body.extend(asc_to_bcd(iso.nii_24))
    if bitmap_get(iso.bitmap, 25):
        body.extend(asc_to_bcd(iso.poscondcode_25))
    if bitmap_get(iso.bitmap, 35):
        body.extend(int_to_longitude_bcd(len(iso.track2_35))[1:2])
        body.extend(asc_to_bcd(iso.track2_35))
    if bitmap_get(iso.bitmap, 37):
        body.extend(iso.retrefnum_37.encode("ascii"))
    if bitmap_get(iso.bitmap, 38):
        body.extend(iso.authid_38.encode("ascii"))
    if bitmap_get(iso.bitmap, 39):
        body.extend(iso.respcode_39.encode("ascii"))
    if bitmap_get(iso.bitmap, 41):
        body.extend(iso.termid_41.encode("ascii"))
    if bitmap_get(iso.bitmap, 42):
        body.extend(iso.merchid_42.encode("ascii"))
    if bitmap_get(iso.bitmap, 45):
        body.extend(int_to_longitude_bcd(len(iso.track1_45))[1:2])
        body.extend(iso.track1_45.encode("ascii"))
    if bitmap_get(iso.bitmap, 49):
        body.extend(iso.currcode_49.encode("ascii"))
    if bitmap_get(iso.bitmap, 50):
        body.extend(iso.settcurrcode_50.encode("ascii"))
    if bitmap_get(iso.bitmap, 54):
        body.extend(int_to_longitude_bcd(len(iso.addamount_54)))
        body.extend(iso.addamount_54.encode("ascii"))
    if bitmap_get(iso.bitmap, 55):
        body.extend(int_to_longitude_bcd(len(iso.cvv_55)))
        body.extend(iso.cvv_55.encode("ascii"))
    if bitmap_get(iso.bitmap, 59):
        body.extend(int_to_longitude_bcd(len(iso.field_59)))
        body.extend(iso.field_59.encode("ascii"))
    if bitmap_get(iso.bitmap, 60):
        body.extend(int_to_longitude_bcd(len(iso.field_60)))
        body.extend(iso.field_60.encode("ascii"))
    if bitmap_get(iso.bitmap, 61):
        body.extend(int_to_longitude_bcd(len(iso.field_61)))
        body.extend(iso.field_61.encode("ascii"))
    if bitmap_get(iso.bitmap, 62):
        body.extend(int_to_longitude_bcd(len(iso.field_62)))
        body.extend(iso.field_62.encode("ascii"))
    if bitmap_get(iso.bitmap, 63):
        body.extend(int_to_longitude_bcd(len(iso.field_63)))
        body.extend(iso.field_63.encode("ascii"))

    return int_to_longitude_hex(len(body)) + bytes(body)


def unpack_iso(frame: bytes) -> IsoMessage:
    """Unpack wire frame (2-byte length + body)."""
    if len(frame) < 2:
        raise IsoPackError("Trama ISO demasiado corta")
    declared = longitude_to_int_hex(frame[0], frame[1])
    if len(frame) < 2 + declared:
        raise IsoPackError("Trama ISO incompleta")
    msg = frame[: 2 + declared]
    iso = IsoMessage()
    j = 2

    iso.tpdu = bcd_to_asc(10, msg[j : j + 5])
    j += 5
    iso.mtype = bcd_to_asc(4, msg[j : j + 2])
    j += 2
    iso.bitmap = bytearray(msg[j : j + 8])
    j += 8

    try:
        if bitmap_get(iso.bitmap, 2):
            length = longitude_to_int_bcd(0x00, msg[j])
            length = min(length, 19)
            j += 1
            nbytes = (length // 2) + (length % 2)
            iso.pan_2 = bcd_to_asc(length, msg[j : j + nbytes])
            j += nbytes
        if bitmap_get(iso.bitmap, 3):
            iso.procode_3 = bcd_to_asc(6, msg[j : j + 3])
            j += 3
        if bitmap_get(iso.bitmap, 4):
            iso.amount_4 = bcd_to_asc(12, msg[j : j + 6])
            j += 6
        if bitmap_get(iso.bitmap, 11):
            iso.systracenum_11 = bcd_to_asc(6, msg[j : j + 3])
            j += 3
        if bitmap_get(iso.bitmap, 12):
            iso.timetrx_12 = bcd_to_asc(6, msg[j : j + 3])
            j += 3
        if bitmap_get(iso.bitmap, 13):
            iso.datetrx_13 = bcd_to_asc(4, msg[j : j + 2])
            j += 2
        if bitmap_get(iso.bitmap, 14):
            iso.dateexpire_14 = bcd_to_asc(4, msg[j : j + 2])
            j += 2
        if bitmap_get(iso.bitmap, 15):
            iso.datesettle_15 = bcd_to_asc(4, msg[j : j + 2])
            j += 2
        if bitmap_get(iso.bitmap, 22):
            iso.posentrymode_22 = bcd_to_asc(4, msg[j : j + 2])
            j += 2
        if bitmap_get(iso.bitmap, 24):
            iso.nii_24 = bcd_to_asc(4, msg[j : j + 2])
            j += 2
        if bitmap_get(iso.bitmap, 25):
            iso.poscondcode_25 = bcd_to_asc(2, msg[j : j + 1])
            j += 1
        if bitmap_get(iso.bitmap, 35):
            length = longitude_to_int_bcd(0x00, msg[j])
            length = min(length, 37)
            j += 1
            nbytes = (length // 2) + (length % 2)
            iso.track2_35 = bcd_to_asc(length, msg[j : j + nbytes])
            j += nbytes
        if bitmap_get(iso.bitmap, 37):
            iso.retrefnum_37 = msg[j : j + 12].decode("ascii")
            j += 12
        if bitmap_get(iso.bitmap, 38):
            iso.authid_38 = msg[j : j + 6].decode("ascii")
            j += 6
        if bitmap_get(iso.bitmap, 39):
            iso.respcode_39 = msg[j : j + 2].decode("ascii")
            j += 2
        if bitmap_get(iso.bitmap, 41):
            iso.termid_41 = msg[j : j + 8].decode("ascii")
            j += 8
        if bitmap_get(iso.bitmap, 42):
            iso.merchid_42 = msg[j : j + 15].decode("ascii")
            j += 15
        if bitmap_get(iso.bitmap, 45):
            length = longitude_to_int_bcd(0x00, msg[j])
            length = min(length, 76)
            j += 1
            iso.track1_45 = msg[j : j + length].decode("ascii")
            j += length
        if bitmap_get(iso.bitmap, 49):
            iso.currcode_49 = msg[j : j + 3].decode("ascii")
            j += 3
        if bitmap_get(iso.bitmap, 50):
            iso.settcurrcode_50 = msg[j : j + 3].decode("ascii")
            j += 3
        if bitmap_get(iso.bitmap, 54):
            length = longitude_to_int_bcd(msg[j], msg[j + 1])
            length = min(length, 99)
            j += 2
            iso.addamount_54 = msg[j : j + length].decode("ascii")
            j += length
        if bitmap_get(iso.bitmap, 55):
            length = longitude_to_int_bcd(msg[j], msg[j + 1])
            length = min(length, 99)
            j += 2
            iso.cvv_55 = msg[j : j + length].decode("ascii")
            j += length
        if bitmap_get(iso.bitmap, 59):
            length = longitude_to_int_bcd(msg[j], msg[j + 1])
            length = min(length, 99)
            j += 2
            iso.field_59 = msg[j : j + length].decode("ascii")
            j += length
        if bitmap_get(iso.bitmap, 60):
            length = longitude_to_int_bcd(msg[j], msg[j + 1])
            length = min(length, 99)
            j += 2
            iso.field_60 = msg[j : j + length].decode("ascii")
            j += length
        if bitmap_get(iso.bitmap, 61):
            length = longitude_to_int_bcd(msg[j], msg[j + 1])
            length = min(length, 99)
            j += 2
            iso.field_61 = msg[j : j + length].decode("ascii")
            j += length
        if bitmap_get(iso.bitmap, 62):
            length = longitude_to_int_bcd(msg[j], msg[j + 1])
            length = min(length, 99)
            j += 2
            iso.field_62 = msg[j : j + length].decode("ascii")
            j += length
        if bitmap_get(iso.bitmap, 63):
            length = longitude_to_int_bcd(msg[j], msg[j + 1])
            length = min(length, 99)
            j += 2
            iso.field_63 = msg[j : j + length].decode("ascii")
            j += length
    except (IndexError, UnicodeDecodeError) as exc:
        raise IsoPackError("Error al parsear campos ISO") from exc

    if j - 2 != declared:
        raise IsoPackError("Longitud ISO inconsistente")
    return iso


def set_present(iso: IsoMessage, *bits: int) -> None:
    for bit in bits:
        bitmap_set(iso.bitmap, bit)
