"""Rewrite PAN and expiry values that are still stored in the clear."""

from collections.abc import Callable

from sqlalchemy import text
from sqlalchemy.orm import Session

from persistence.repositories.transaction_repository import TransactionRepository

_ADVISORY_LOCK_KEY = 15150015


def reencrypt_stored_cards(
    session_factory: Callable[[], Session] | None = None,
) -> int:
    """Encrypt leftover plaintext before the API serves traffic.

    On PostgreSQL a transaction advisory lock makes one process finish the
    scan while the others wait, then find nothing left in the clear.
    """
    if session_factory is None:
        from persistence.database import SessionLocal

        session_factory = SessionLocal
    total = 0
    with session_factory() as session:
        if session.get_bind().dialect.name == "postgresql":
            session.execute(
                text("SELECT pg_advisory_xact_lock(:key)"),
                {"key": _ADVISORY_LOCK_KEY},
            )
        repository = TransactionRepository(session)
        while True:
            changed = repository.reencrypt_plaintext_cards()
            if changed == 0:
                break
            total += changed
        session.commit()
    return total
