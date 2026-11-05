"""Merchant data is loaded from the authenticated account on every request."""

from collections.abc import Iterator

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from main import app
from presentation.dependencies import CurrentUser, get_current_user, get_db


def test_current_merchant_reflects_updates_and_is_scoped_to_account() -> None:
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    with engine.begin() as conn:
        conn.execute(
            text(
                "CREATE TABLE merchants (id INTEGER PRIMARY KEY, code TEXT, "
                "name TEXT, address TEXT, city TEXT, tax_id TEXT, "
                "created_at TEXT DEFAULT CURRENT_TIMESTAMP, "
                "updated_at TEXT DEFAULT CURRENT_TIMESTAMP)"
            )
        )
        conn.execute(
            text("CREATE TABLE users (id INTEGER PRIMARY KEY, merchant_id INTEGER)")
        )
        conn.execute(
            text(
                "INSERT INTO merchants (id, code, name, address, city, tax_id) VALUES "
                "(1, '014114', 'GAS', 'Alem', 'Ushuaia', '30-1'), "
                "(2, '002', 'OTRO', 'Otra', 'Tolhuin', '30-2')"
            )
        )
        conn.execute(text("INSERT INTO users VALUES (1, 1), (2, 2), (3, NULL)"))
    current = [1]

    def db() -> Iterator[Session]:
        with Session(engine) as session:
            yield session

    app.dependency_overrides[get_db] = db
    app.dependency_overrides[get_current_user] = lambda: CurrentUser(
        user_id=current[0], email="a@b.c", installation_id="1"
    )
    try:
        client = TestClient(app)
        first = client.get("/v1/me/merchant")
        assert first.json()["merchant"]["code"] == "014114"
        with engine.begin() as conn:
            conn.execute(
                text("UPDATE merchants SET name = 'GAS NUEVO' WHERE id = 1")
            )
        assert (
            client.get("/v1/me/merchant").json()["merchant"]["name"] == "GAS NUEVO"
        )
        current[0] = 2
        assert client.get("/v1/me/merchant").json()["merchant"]["name"] == "OTRO"
        current[0] = 3
        assert client.get("/v1/me/merchant").status_code == 403
    finally:
        app.dependency_overrides.clear()
        engine.dispose()


def test_current_merchant_requires_authentication() -> None:
    response = TestClient(app).get("/v1/me/merchant")
    assert response.status_code == 401
