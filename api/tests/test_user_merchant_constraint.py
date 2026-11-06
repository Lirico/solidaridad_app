"""Database constraints for the account-to-merchant relationship."""

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.exc import IntegrityError

from persistence.models.merchant import Merchant
from persistence.models.user import User


def test_database_requires_an_existing_merchant_for_every_user() -> None:
    engine = create_engine("sqlite://")
    with engine.begin() as connection:
        connection.execute(text("PRAGMA foreign_keys=ON"))
        Merchant.__table__.create(connection)
        User.__table__.create(connection)
        connection.execute(
            Merchant.__table__.insert().values(
                id=1,
                code="012502",
                name="Comercio",
                address="Calle",
                city="Ciudad",
                tax_id="30-1",
            )
        )
        user = {
            "id": 1,
            "name": "Operador",
            "email": "operador@example.com",
            "password_hash": "hash",
        }
        with pytest.raises(IntegrityError):
            connection.execute(User.__table__.insert().values(**user))
        with pytest.raises(IntegrityError):
            connection.execute(User.__table__.insert().values(**user, merchant_id=999))
        connection.execute(User.__table__.insert().values(**user, merchant_id=1))
        with pytest.raises(IntegrityError):
            connection.execute(
                User.__table__.update().where(User.id == 1).values(merchant_id=None)
            )
        with pytest.raises(IntegrityError):
            connection.execute(Merchant.__table__.delete().where(Merchant.id == 1))
    engine.dispose()
