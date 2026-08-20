import importlib
import sys
from pathlib import Path

import pytest


PROJECT_ROOT = Path(__file__).resolve().parents[2]
WORKER_DIRECTORY = PROJECT_ROOT / "docker" / "worker"

sys.path.insert(0, str(WORKER_DIRECTORY))

worker_app = importlib.import_module("worker")


@pytest.fixture()
def client():
    worker_app.app.config.update(TESTING=True)

    with worker_app.app.test_client() as test_client:
        yield test_client


def test_home_endpoint(client):
    response = client.get("/")

    assert response.status_code == 200
    assert response.get_data(as_text=True) == "Worker service is running"


def test_health_endpoint(client):
    response = client.get("/health")

    assert response.status_code == 200
    assert response.get_json() == {
        "status": "healthy",
        "service": "worker",
    }


def test_process_endpoint(client):
    response = client.get("/process")

    assert response.status_code == 200
    assert response.get_json() == {
        "status": "processed",
    }
