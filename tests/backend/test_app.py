import importlib
import os
import sys
from pathlib import Path
from unittest.mock import Mock, patch

import pytest


PROJECT_ROOT = Path(__file__).resolve().parents[2]
BACKEND_DIRECTORY = PROJECT_ROOT / "docker" / "backend"

os.environ["AWS_EC2_METADATA_DISABLED"] = "true"
os.environ["AWS_DEFAULT_REGION"] = "us-east-1"
os.environ["AWS_REGION"] = "us-east-1"

sys.path.insert(0, str(BACKEND_DIRECTORY))

backend_app = importlib.import_module("app")


@pytest.fixture()
def client():
    backend_app.app.config.update(TESTING=True)

    with backend_app.app.test_client() as test_client:
        yield test_client


def test_home_endpoint(client):
    response = client.get("/")

    assert response.status_code == 200
    assert response.get_data(as_text=True) == (
        "Backend API is running with RDS, S3 and SNS"
    )


def test_health_endpoint(client):
    response = client.get("/health")

    assert response.status_code == 200
    assert response.get_json() == {
        "status": "healthy",
        "service": "backend",
    }


@patch.object(backend_app.requests, "get")
def test_worker_endpoint(mock_get, client):
    worker_response = Mock()
    worker_response.json.return_value = {
        "status": "healthy",
        "service": "worker",
    }
    mock_get.return_value = worker_response

    response = client.get("/worker")

    assert response.status_code == 200
    assert response.get_json() == {
        "status": "healthy",
        "service": "worker",
    }

    mock_get.assert_called_once_with(
        f"{backend_app.WORKER_URL}/health",
        timeout=5,
    )


@patch.object(backend_app, "get_connection")
def test_provision_endpoint(mock_get_connection, client):
    connection = Mock()
    cursor = Mock()

    connection.cursor.return_value = cursor
    mock_get_connection.return_value = connection

    payload = {
        "name": "ci-test-vm",
        "os": "ubuntu-22.04-lts",
        "cpu": 2,
        "ram_gb": 4,
    }

    response = client.post("/provision", json=payload)

    assert response.status_code == 200
    assert response.get_json() == {"status": "added"}

    cursor.execute.assert_called_once_with(
        "INSERT INTO items (name, os, cpu, ram_gb) VALUES (%s, %s, %s, %s)",
        ("ci-test-vm", "ubuntu-22.04-lts", 2, 4),
    )
    connection.commit.assert_called_once()
    cursor.close.assert_called_once()
    connection.close.assert_called_once()


@patch.object(backend_app, "get_connection")
def test_machines_endpoint(mock_get_connection, client):
    connection = Mock()
    cursor = Mock()

    cursor.fetchall.return_value = [
        (1, "test-vm", "ubuntu-22.04-lts", 2, 4)
    ]
    connection.cursor.return_value = cursor
    mock_get_connection.return_value = connection

    response = client.get("/machines")

    assert response.status_code == 200
    assert response.get_json() == {
        "items": [
            {
                "id": 1,
                "name": "test-vm",
                "os": "ubuntu-22.04-lts",
                "cpu": 2,
                "ram_gb": 4,
            }
        ]
    }

    cursor.execute.assert_called_once_with(
        "SELECT id, name, os, cpu, ram_gb FROM items ORDER BY id"
    )
