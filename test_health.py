# Copyright (c) 2026 Francisco Zenklusen. All rights reserved.
"""Unit tests for the health check endpoint of the Flask web service.

These tests verify that the /health endpoint returns:
    a status code of 200
    a JSON response containing the expected keys: status, timestamp, and message
"""
from app import app

# HTTP status codes
HTTP_OK = 200


def test_health_status_code() -> None:
    """Test that the /health endpoint returns a status code of 200."""
    client = app.test_client()
    response = client.get("/health")
    if response.status_code != HTTP_OK:
        error = f"Expected status code {HTTP_OK}, got {response.status_code}"
        raise ValueError(error)

def test_health_response_structure() -> None:
    """Test that the /health endpoint returns the expected response structure.

    The response should be a JSON object containing the
        status
        timestamp
        message
    """
    client = app.test_client()
    response = client.get("/health")
    data = response.get_json()

    if "status" not in data:
        error = "Response JSON does not contain 'status' key"
        raise ValueError(error)
    if "timestamp" not in data:
        error = "Response JSON does not contain 'timestamp' key"
        raise ValueError(error)
    if "message" not in data:
        error = "Response JSON does not contain 'message' key"
        raise ValueError(error)
    if data["status"] != "ok":
        error = f"Expected status 'ok', got {data['status']}"
        raise ValueError(error)
