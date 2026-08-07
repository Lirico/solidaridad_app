from fastapi.testclient import TestClient

from main import app
from presentation.dependencies import CurrentUser, get_current_user

client = TestClient(app)

_EXPECTED_PRODUCTS = [
    {
        "code": "GARRAFA_10",
        "label": "Garrafa 10 kg",
        "unit": {"singular": "unidad", "plural": "unidades"},
    },
    {
        "code": "GARRAFA_15",
        "label": "Garrafa 15 kg",
        "unit": {"singular": "unidad", "plural": "unidades"},
    },
    {
        "code": "GARRAFA_30",
        "label": "Garrafa 30 kg",
        "unit": {"singular": "unidad", "plural": "unidades"},
    },
    {
        "code": "TUBO_45",
        "label": "Tubo 45 kg",
        "unit": {"singular": "unidad", "plural": "unidades"},
    },
    {
        "code": "GRANEL",
        "label": "Granel",
        "unit": {"singular": "m3", "plural": "m3"},
    },
]


def _override_auth() -> None:
    app.dependency_overrides[get_current_user] = lambda: CurrentUser(
        user_id=1,
        email="demo@solidaridad.local",
        installation_id="inst-1",
    )


def _clear() -> None:
    app.dependency_overrides.clear()


def test_list_products() -> None:
    _override_auth()
    try:
        response = client.get(
            "/v1/products",
            headers={"Authorization": "Bearer unused-because-overridden"},
        )
        assert response.status_code == 200
        assert response.json() == _EXPECTED_PRODUCTS
    finally:
        _clear()


def test_list_products_requires_auth() -> None:
    response = client.get("/v1/products")
    assert response.status_code == 401
