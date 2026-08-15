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

    # Banda magnética: DE35 (track2) en lugar de DE2 (PAN) + DE14 (expiry).
    # Manual: DE2 + DE14 como antes. DE22 refleja el modo de entrada.
    if command.track2:
        iso = IsoMessage(
            tpdu=settings.iso_tpdu,
            mtype="0200",
            procode_3=_pad_digits(settings.iso_processing_code, 6),
            amount_4=f"{command.amount_minor:012d}",
            systracenum_11=_pad_digits(command.stan, 6),
            timetrx_12=moment.strftime("%H%M%S"),
            datetrx_13=moment.strftime("%m%d"),
            posentrymode_22=_pad_digits(command.entry_mode, 4),
            nii_24=_pad_digits(settings.iso_nii, 4),
            poscondcode_25=_pad_digits(settings.iso_pos_condition_code, 2),
            track2_35=command.track2,
            termid_41=command.terminal_id[:8].ljust(8),
            currcode_49=product_code_de49(command.product_code),
            field_62=_numeric_ticket(command.ticket_number),
        )
        bits = [3, 4, 11, 12, 13, 22, 24, 25, 35, 41, 49, 62]
    else:
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
