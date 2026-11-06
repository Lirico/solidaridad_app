"""Test DE42 against a disposable local processor with the demo seed.

Run only against an isolated database: this creates sales and reversals.
The demo terminal 05000001 must have marca='VeriFone' and merchant 012502.
"""

import secrets

from config.settings import Settings
from domain.authorization import AuthorizeCommand, VoidCommand
from domain.balance import BalanceCommand
from domain.reversal import ReverseCommand
from infrastructure.iso.tcp_processor import TcpIsoProcessor

number = secrets.randbelow(100_000) * 10


def ticket(offset: int) -> str:
    return f"{number + offset:06d}"


processor = TcpIsoProcessor(
    Settings(iso_host="127.0.0.1", iso_port=14452, iso_read_timeout_seconds=5)
)
base = dict(
    product_code="993",
    card_number="6063007014007403",
    terminal_id="05000001",
    merchant_code="012502",
    expiration_date="1229",
)
sale = processor.authorize(
    AuthorizeCommand(**base, amount_minor=100, stan=ticket(1), ticket_number=ticket(1))
)
print("sale:", sale.status.value, sale.response_code)
assert sale.status.value == "APPROVED"
wrong = processor.authorize(
    AuthorizeCommand(
        **(base | {"merchant_code": "999999"}),
        amount_minor=100,
        stan=ticket(2),
        ticket_number=ticket(2),
    )
)
print("wrong merchant:", wrong.status.value, wrong.response_code)
assert wrong.status.value == "DECLINED" and wrong.response_code == "89"
balance = processor.balance(BalanceCommand(**base, stan=ticket(3)))
print("balance:", balance.status.value, balance.response_code)
assert balance.status.value == "APPROVED"
void = processor.void(
    VoidCommand(
        **base,
        amount_minor=100,
        stan=ticket(4),
        original_ticket=ticket(1),
        void_ticket=ticket(4),
    )
)
print("void:", void.status.value, void.response_code)
assert void.status.value == "APPROVED"
sale2 = processor.authorize(
    AuthorizeCommand(**base, amount_minor=100, stan=ticket(5), ticket_number=ticket(5))
)
print("sale for reversal:", sale2.status.value, sale2.response_code)
assert sale2.status.value == "APPROVED"
reverse = processor.reverse(
    ReverseCommand(
        **base,
        amount_minor=100,
        original_stan=ticket(5),
        original_ticket=ticket(5),
        reversal_stan=ticket(6),
    )
)
print("reversal:", reverse.status.value, reverse.response_code)
assert reverse.status.value == "REVERSED_CONFIRMED"
