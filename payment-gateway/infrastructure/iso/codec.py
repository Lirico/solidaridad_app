"""BCD / length helpers matching payment_processor iso_common.c."""


def asc_to_bcd(asc: str) -> bytes:
    """Convert ASCII hex/digits to BCD; odd length pads low nibble with 0xF."""
    length = len(asc)
    nbytes = (length // 2) + (length % 2)
    out = bytearray(nbytes)
    j = 0
    for i in range(nbytes):
        high = _nibble(asc[j])
        out[i] = high << 4
        if j + 1 < length:
            out[i] |= _nibble(asc[j + 1])
        j += 2
    if length % 2 > 0:
        out[nbytes - 1] |= 0x0F
    return bytes(out)


def bcd_to_asc(digit_count: int, bcd: bytes) -> str:
    """Convert BCD to ASCII hex digits; result length is digit_count."""
    nbytes = (digit_count // 2) + (digit_count % 2)
    chars: list[str] = []
    for i in range(nbytes):
        byte = bcd[i] if i < len(bcd) else 0
        chars.append(_nibble_to_char((byte & 0xF0) >> 4))
        chars.append(_nibble_to_char(byte & 0x0F))
    return "".join(chars)[:digit_count]


def int_to_longitude_hex(length: int) -> bytes:
    """2-byte big-endian length (type 'h' in C)."""
    if length < 0 or length > 0xFFFF:
        raise ValueError(f"length out of range: {length}")
    return bytes([(length >> 8) & 0xFF, length & 0xFF])


def longitude_to_int_hex(high: int, low: int) -> int:
    return (high & 0xFF) * 256 + (low & 0xFF)


def int_to_longitude_bcd(length: int) -> bytes:
    """Encode integer length as 2 BCD bytes (type 'b' in C)."""
    if length < 0 or length > 9999:
        raise ValueError(f"BCD length out of range: {length}")
    digits = f"{length:04d}"
    return asc_to_bcd(digits)


def longitude_to_int_bcd(high: int, low: int) -> int:
    a = high & 0xFF
    b = low & 0xFF
    value = 100 * ((10 * ((a & 0xF0) // 16)) + (a & 0x0F))
    value += (10 * ((b & 0xF0) // 16)) + (b & 0x0F)
    return value


def bitmap_get(bitmap: bytes | bytearray, bit: int) -> bool:
    """ISO bit 1..64 (MSB of byte 0 is bit 1)."""
    bit0 = bit - 1
    nbyte = bit0 // 8
    nbit = bit0 - (nbyte * 8)
    mask = 0x80 >> nbit
    return bool(bitmap[nbyte] & mask)


def bitmap_set(bitmap: bytearray, bit: int) -> None:
    bit0 = bit - 1
    nbyte = bit0 // 8
    nbit = bit0 - (nbyte * 8)
    mask = 0x80 >> nbit
    bitmap[nbyte] |= mask


def _nibble(ch: str) -> int:
    code = ord(ch.upper())
    if code < 0x3A:
        return code - 0x30
    return code - 0x37


def _nibble_to_char(n: int) -> str:
    if n < 0x0A:
        return chr(n + 0x30)
    return chr(n + 0x37)
