import os
import tempfile
import pytest
from app import app, init_db


@pytest.fixture
def client():
    db_fd, db_path = tempfile.mkstemp()
    os.environ["DB_PATH"] = db_path

    app.config["TESTING"] = True

    with app.test_client() as client:
        init_db()
        yield client

    os.close(db_fd)
    os.unlink(db_path)


def test_home(client):
    response = client.get("/")
    assert response.status_code == 200
    assert response.get_json()["status"] == "running"


def test_create_drug(client):
    payload = {
        "drug_name": "Paracetamol",
        "category": "Analgesic",
        "lot_number": "LOT001",
        "quantity": 50,
        "min_stock": 10,
        "expiry_date": "2026-12-31"
    }

    response = client.post("/drugs", json=payload)
    assert response.status_code == 201


def test_get_drugs(client):
    response = client.get("/drugs")
    assert response.status_code == 200
    assert "data" in response.get_json()


def test_metrics(client):
    response = client.get("/metrics")
    assert response.status_code == 200