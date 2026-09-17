# Copyright (c) 2026 Meridian Capital Markets
"""Tests for the platform health endpoint."""

import os
from unittest.mock import patch

from src.app.app import app
from src.app.constants import (
    HTTP_STATUS_INTERNAL_SERVER_ERROR,
    HTTP_STATUS_OK,
)


def test_platform_health() -> None:
    """Test that the platform health endpoint returns 200."""
    with patch.dict(os.environ, {"GITLAB_TOKEN": "test-token"}):
        client = app.test_client()

        response = client.get("/platform/health")

        assert response.status_code == HTTP_STATUS_OK

        data = response.get_json()

        assert data["status"] == "ok"
        assert data["service"] == "platform-api"
        assert "timestamp" in data

def test_health_without_gitlab_token() -> None:
    """Test health endpoint when GitLab token is missing."""
    with patch.dict(os.environ, {}, clear=True):
        client = app.test_client()
        response = client.get("/platform/health")

        assert response.status_code == HTTP_STATUS_INTERNAL_SERVER_ERROR

        data = response.get_json()
        assert data["status"] == "unhealthy"
        assert data["message"] == "GITLAB_TOKEN is missing"
