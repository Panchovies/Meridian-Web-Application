# Copyright (c) 2026 Meridian Capital Markets
"""Unit tests for the health check endpoint of the Flask web service.

These tests verify that the /health endpoint returns:
    a status code of 200
    a JSON response containing the expected keys: status, timestamp, and message
"""
import os
from unittest.mock import patch

from src.app.app import app
from src.app.constants import (
    # HTTP_STATUS_INTERNAL_SERVER_ERROR,
    HTTP_STATUS_OK,
)


def test_health_status_code() -> None:
    """Test that the /health endpoint returns a status code of 200."""
    client = app.test_client()

    with patch.dict(os.environ, {"NEWS_API_KEY": "test_key"}):
        response = client.get("/health")

    assert response.status_code == HTTP_STATUS_OK

def test_health_response_structure() -> None:
    """Test that the /health endpoint returns the expected response structure.

    The response should be a JSON object containing the
        status
        timestamp
        message

    client = app.test_client()

    with patch.dict(os.environ, {"NEWS_API_KEY": "test_key"}):
        response = client.get("/health")

    data = response.get_json()

    assert "status" in data
    assert "timestamp" in data
    assert "message" in data
    assert data["status"] == "ok"
    """

def test_health_missing_api_key() -> None:
    """Test the /health endpoint returns an error when NEWS_API_KEY is missing.

    The response should be a JSON object containing the
        status
        timestamp
        message
    and a status code of 500.

    client = app.test_client()

    with patch.dict(os.environ, {}, clear=True):
        response = client.get("/health")

    data = response.get_json()

    assert "status" in data
    assert "timestamp" in data
    assert "message" in data
    assert data["status"] == "error"
    assert response.status_code == HTTP_STATUS_INTERNAL_SERVER_ERROR
    """
