"""Build purchase (0200) ISO messages from authorize commands."""

from datetime import datetime

from config.settings import Settings
from domain.authorization import AuthorizeCommand
from domain.product import product_code_de49
from infrastructure.iso.packer import IsoMessage, set_present


def build_purchase_request(
    command: AuthorizeCommand,
    settings: Settings,
    *,
    now: datetime | None = None,
) -> IsoMessage:
    moment = now or datetime.now()

    iso = IsoMessage(
        tpdu=settings.iso_tpdu,
        mtype="0200",
        pan_2=command.card_number,
        procode_3=_pad_digits(settings.iso_processing_code, 6),
        amount_4=f"{command.amount_minor:012d}",
        systracenum_11=command.stan,
        timetrx_12=moment.strftime("%H%M%S"),
        datetrx_13=moment.strftime("%m%d"),
        posentrymode_22=_pad_digits(settings.iso_pos_entry_mode, 4),
        nii_24=_pad_digits(settings.iso_nii, 4),
        poscondcode_25=_pad_digits(settings.iso_pos_condition_code, 2),
        termid_41=command.terminal_id[:8].ljust(8),
        currcode_49=product_code_de49(command.product_code),
        field_62=_transaction_number(command.transaction_number),
    )

    bits = [2, 3, 4, 11, 12, 13, 22, 24, 25, 41, 49, 62]
    if command.expiration_date:
        iso.dateexpire_14 = _pad_digits(command.expiration_date, 4)
        bits.append(14)
    set_present(iso, *bits)
    return iso



def _transaction_number(transaction_id: str) -> str:
    """Extract the numeric part of a transaction id (OP-YYMMDD-NNNN -> NNNN)."""
    return transaction_id.rsplit("-", 1)[-1]


def _pad_digits(value: str, width: int) -> str:
    digits = "".join(c for c in value if c.isalnum())
    return digits.zfill(width)[-width:]


