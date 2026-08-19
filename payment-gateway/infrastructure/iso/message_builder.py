"""Build purchase / void (0200) ISO messages from authorize commands."""

from datetime import datetime

from config.settings import Settings
from domain.authorization import AuthorizeCommand, VoidCommand
from domain.product import product_code_de49
from infrastructure.iso.packer import IsoMessage, set_present

_VOID_PROCESSING_CODE = "020000"


def build_purchase_request(
    command: AuthorizeCommand,
    settings: Settings,
    *,
    now: datetime | None = None,
) -> IsoMessage:
    moment = now or datetime.now()

    # Siempre se envía DE2 (PAN) + DE14 (vencimiento). Si viene track2 (DE35),
    # se envía ADEMÁS (no en lugar de DE2): el autorizador prefiere el PAN
    # explícito (DE2) cuando está presente, y el track2 de algunas tarjetas de
    # prueba trae un PAN que no coincide con el registrado. Enviar DE2 siempre
    # garantiza que el PAN correcto llegue al autorizador sin importar si la
    # app manda track2 o no.
    iso = IsoMessage(
        tpdu=settings.iso_tpdu,
        mtype="0200",
        pan_2=command.card_number,
        procode_3=_pad_digits(settings.iso_processing_code, 6),
        amount_4=f"{command.amount_minor:012d}",
        systracenum_11=_pad_digits(command.stan, 6),
        timetrx_12=moment.strftime("%H%M%S"),
        datetrx_13=moment.strftime("%m%d"),
        posentrymode_22=_pad_digits(command.entry_mode, 4),
        nii_24=_pad_digits(settings.iso_nii, 4),
        poscondcode_25=_pad_digits(settings.iso_pos_condition_code, 2),
        termid_41=command.terminal_id[:8].ljust(8),
        currcode_49=product_code_de49(command.product_code),
        field_62=_numeric_ticket(command.ticket_number),
    )
    bits = [2, 3, 4, 11, 12, 13, 22, 24, 25, 41, 49, 62]
    if command.expiration_date:
        iso.dateexpire_14 = _pad_digits(command.expiration_date, 4)
        bits.append(14)
    if command.track2:
        iso.track2_35 = _normalize_track2(command.track2)
        bits.append(35)
    set_present(iso, *bits)
    return iso


def build_void_request(
    command: VoidCommand,
    settings: Settings,
    *,
    now: datetime | None = None,
) -> IsoMessage:
    """Anulación: MTI 0200 + DE3 020000 (ruta Verifone: original ticket en DE37).

    El autorizador lee el importe de anulación desde DE60 (no DE4).
    """
    moment = now or datetime.now()
    amount = f"{command.amount_minor:012d}"
    original_ticket = _numeric_ticket(command.original_ticket)

    iso = IsoMessage(
        tpdu=settings.iso_tpdu,
        mtype="0200",
        pan_2=command.card_number,
        procode_3=_VOID_PROCESSING_CODE,
        amount_4=amount,
        systracenum_11=_pad_digits(command.stan, 6),
        timetrx_12=moment.strftime("%H%M%S"),
        datetrx_13=moment.strftime("%m%d"),
        posentrymode_22=_pad_digits(settings.iso_pos_entry_mode, 4),
        nii_24=_pad_digits(settings.iso_nii, 4),
        poscondcode_25=_pad_digits(settings.iso_pos_condition_code, 2),
        retrefnum_37=original_ticket.zfill(12),
        termid_41=command.terminal_id[:8].ljust(8),
        currcode_49=product_code_de49(command.product_code),
        field_60=amount,
        field_62=_numeric_ticket(command.void_ticket),
    )
    bits = [2, 3, 4, 11, 12, 13, 22, 24, 25, 37, 41, 49, 60, 62]
    if command.expiration_date:
        iso.dateexpire_14 = _pad_digits(command.expiration_date, 4)
        bits.append(14)
    set_present(iso, *bits)
    return iso


def _pad_digits(value: str, width: int) -> str:
    digits = "".join(c for c in value if c.isalnum())
    return digits.zfill(width)[-width:]


def _numeric_ticket(value: str) -> str:
    digits = "".join(c for c in value if c.isdigit())
    return digits or "0"


def _normalize_track2(track2: str) -> str:
    """Normaliza el track2 (DE35) al layout que espera el autorizador C.

    La terminal puede entregar el track2 con sentinels y separadores de
    servicio (p. ej. ";PAN=EXPIRY?SERVICE" o "PAN=EXPIRY"). El autorizador
    (iso_common.c / auth_mycli.c) espera el layout "PAN=EXPIRY":
      - PAN en las primeras 16 posiciones,
      - "=" como separador (posición 16),
      - vencimiento en las posiciones 17-20.

    Esta función:
      - elimina los sentinels de inicio/fin (";" y "?"),
      - reemplaza el separador alternativo "D" por "=",
      - recorta cualquier dato de servicio posterior al vencimiento.
    """
    cleaned = track2.strip()
    if cleaned.startswith(";"):
        cleaned = cleaned[1:]
    if cleaned.endswith("?"):
        cleaned = cleaned[:-1]
    cleaned = cleaned.replace("D", "=")
    # Quedarse solo con PAN=EXPIRY (hasta el vencimiento, 4 dígitos tras "=").
    if "=" in cleaned:
        pan, _, rest = cleaned.partition("=")
        expiry = "".join(c for c in rest if c.isdigit())[:4]
        return f"{pan}={expiry}"
    return cleaned
