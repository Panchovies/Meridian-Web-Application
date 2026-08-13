# Copyright (c) 2026 Meridian Capital Markets
"""Unit tests for the metrics endpoint of the Flask web service.

These tests verify that the /metrics endpoint returns:
    a status code of 200
    Prometheus-format output containing the expected metrics
"""
import os
from unittest.mock import patch

from src.app.app import app
from src.app.constants import (
    HTTP_STATUS_OK,
)


def test_metrics_endpoint_exposed() -> None:
    """/metrics should expose Prometheus-format output, not touch /health."""
    client = app.test_client()
    with patch.dict(os.environ, {"NEWS_API_KEY": "test_key"}):
        response = client.get("/health") # Ensure /health is called first
    response = client.get("/metrics")

    assert response.status_code == HTTP_STATUS_OK
    assert "flask_http_request_total" in response.text
