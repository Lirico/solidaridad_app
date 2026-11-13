"""PAN and expiry are encrypted before they reach the database."""

import base64
from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import Session, sessionmaker

from config.settings import LAB_PAN_ENCRYPTION_KEY, decode_pan_encryption_key
from persistence.card_cipher import CardCipher, CardCipherError
from persistence.models.transaction import Transaction as TransactionModel
from persistence.reencrypt_card_data import reencrypt_stored_cards
from persistence.repositories.transaction_repository import TransactionRepository

PAN = "4111111111111111"
EXPIRY = "3012"


def _cipher() -> CardCipher:
    return CardCipher(decode_pan_encryption_key(LAB_PAN_ENCRYPTION_KEY))


def test_roundtrip_and_distinct_ciphertext() -> None:
    cipher = _cipher()

    first = cipher.encrypt(PAN)
    second = cipher.encrypt(PAN)

    assert first.startswith("v1.")
    assert second.startswith("v1.")
    assert first != second
    assert PAN not in first
    assert cipher.decrypt(first) == PAN
    assert cipher.decrypt(second) == PAN
    assert cipher.decrypt(EXPIRY) == EXPIRY


def test_decrypt_rejects_a_tampered_payload_without_echoing_the_pan() -> None:
    cipher = _cipher()
    stored = cipher.encrypt(PAN)
    raw = bytearray(base64.b64decode(stored.removeprefix("v1.")))
    raw[-1] ^= 0x01
    tampered = "v1." + base64.b64encode(raw).decode("ascii")

    with pytest.raises(CardCipherError, match="No se pudo descifrar") as caught:
        cipher.decrypt(tampered)

    assert PAN not in str(caught.value)


def test_decrypt_rejects_a_truncated_payload() -> None:
    cipher = _cipher()
    stored = "v1." + base64.b64encode(b"short").decode("ascii")

    with pytest.raises(CardCipherError, match="irreconocible"):
        cipher.decrypt(stored)


def test_cipher_rejects_a_key_that_is_not_32_bytes() -> None:
    with pytest.raises(CardCipherError, match="32 bytes"):
        CardCipher(b"short")


def test_decrypt_rejects_unknown_payload_without_echoing_it() -> None:
    cipher = _cipher()

    with pytest.raises(CardCipherError, match="irreconocible") as caught:
        cipher.decrypt("no-es-un-pan")

    assert "no-es-un-pan" not in str(caught.value)


def _row(**overrides: object) -> TransactionModel:
    now = datetime.now(UTC)
    values: dict[str, object] = {
        "id": 1,
        "transaction_number": "OP-261112-00000001",
        "user_id": 1,
        "installation_id": 1,
        "terminal_id": "05000001",
        "product": "GARRAFA_10",
        "processor_product_code": "993",
        "amount_minor": 100,
        "status": "PENDING",
        "card_last4": "1111",
        "card_number": PAN,
        "expiration_date": EXPIRY,
        "authorization_outcome": "PENDING",
        "authorization_attempt_count": 1,
        "authorization_last_attempt_at": now,
        "idempotency_key": "legacy-key",
        "request_fingerprint": "a" * 64,
        "created_at": now,
        "updated_at": now,
    }
    values.update(overrides)
    return TransactionModel(**values)  # type: ignore[arg-type]


def _sqlite_session() -> Session:
    engine = create_engine("sqlite://")
    TransactionModel.__table__.create(engine)
    return sessionmaker(bind=engine)()


def test_reading_a_legacy_row_rewrites_it() -> None:
    session = _sqlite_session()
    session.add(_row())
    session.commit()

    loaded = TransactionRepository(session).get_by_idempotency(
        user_id=1,
        idempotency_key="legacy-key",
    )

    assert loaded is not None
    assert loaded.card_number == PAN
    assert loaded.expiration_date == EXPIRY
    stored = session.scalars(select(TransactionModel)).one()
    assert stored.card_number is not None
    assert stored.expiration_date is not None
    assert stored.card_number.startswith("v1.")
    assert stored.expiration_date.startswith("v1.")
    assert PAN not in stored.card_number
    assert EXPIRY not in stored.expiration_date
    sealed_pan = stored.card_number
    TransactionRepository(session).get_by_id(transaction_id=stored.id)
    assert stored.card_number == sealed_pan
    session.close()


def test_startup_rewrites_plaintext_rows() -> None:
    engine = create_engine("sqlite://")
    TransactionModel.__table__.create(engine)
    factory = sessionmaker(bind=engine)
    with factory() as session:
        session.add(_row(idempotency_key="startup-key"))
        session.commit()

    assert reencrypt_stored_cards(session_factory=factory) == 1
    assert reencrypt_stored_cards(session_factory=factory) == 0

    with factory() as session:
        stored = session.scalars(select(TransactionModel)).one()
        assert stored.card_number is not None
        assert stored.card_number.startswith("v1.")
        assert PAN not in stored.card_number
        assert stored.expiration_date is not None
        assert stored.expiration_date.startswith("v1.")
        revealed = TransactionRepository(session).get_by_id(transaction_id=stored.id)
        assert revealed is not None
        assert revealed.card_number == PAN
        assert revealed.expiration_date == EXPIRY


def test_startup_takes_the_postgres_advisory_lock() -> None:
    session = MagicMock()
    session.get_bind.return_value.dialect.name = "postgresql"
    session.scalars.return_value.all.return_value = []
    session.__enter__.return_value = session

    assert reencrypt_stored_cards(session_factory=lambda: session) == 0

    lock_sql = str(session.execute.call_args.args[0])
    assert "pg_advisory_xact_lock" in lock_sql
    session.commit.assert_called_once()


def test_postgres_reencrypt_locks_matching_rows() -> None:
    session = MagicMock()
    session.get_bind.return_value.dialect.name = "postgresql"
    session.scalars.return_value.all.return_value = []

    assert TransactionRepository(session).reencrypt_plaintext_cards() == 0

    statement = session.scalars.call_args.args[0]
    sql = str(
        statement.compile(
            dialect=postgresql.dialect(),
            compile_kwargs={"literal_binds": True},
        )
    )
    assert "FOR UPDATE" in sql
    assert "card_number ~" in sql
    assert "expiration_date ~" in sql
