from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_list_products() -> None:
    response = client.get("/v1/products")
    assert response.status_code == 200
    data = response.json()
    assert data == [
        {"code": "GARRAFA_10", "label": "Garrafa 10 kg"},
        {"code": "GARRAFA_15", "label": "Garrafa 15 kg"},
        {"code": "GARRAFA_30", "label": "Garrafa 30 kg"},
        {"code": "TUBO_45", "label": "Tubo 45 kg"},
        {"code": "GRANEL", "label": "Granel"},
    ]
