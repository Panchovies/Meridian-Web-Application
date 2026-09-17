# Copyright (c) 2026 Meridian Capital Markets
"""Tests for the platform alerts endpoint."""

from unittest.mock import mock_open, patch

from src.app.app import app
from src.app.constants import (
    HTTP_STATUS_BAD_REQUEST,
    HTTP_STATUS_INTERNAL_SERVER_ERROR,
    HTTP_STATUS_OK,
)


def test_platform_alerts_success() -> None:
    """Test successful alert intake and logging."""
    alert = {
        "severity": "critical",
        "message": "High CPU usage detected",
        "source": "cloudwatch",
    }

    mock_file = mock_open()

    with patch(
        "src.app.platform.alerts.Path.open",
        mock_file,
    ), patch(
        "src.app.platform.alerts.Path.mkdir",
    ):

        client = app.test_client()

        response = client.post(
            "/platform/alerts",
            json=alert,
        )

        assert response.status_code == HTTP_STATUS_OK

        data = response.get_json()

        assert data["status"] == "accepted"
        assert data["alert"]["severity"] == "critical"
        assert data["alert"]["message"] == (
            "High CPU usage detected"
        )
        assert data["alert"]["source"] == "cloudwatch"

        mock_file().write.assert_called_once()


def test_platform_alerts_missing_fields() -> None:
    """Test alert validation with missing fields."""
    client = app.test_client()

    response = client.post(
        "/platform/alerts",
        json={
            "severity": "critical",
            "message": "Test alert",
        },
    )

    assert response.status_code == HTTP_STATUS_BAD_REQUEST

    data = response.get_json()

    assert data["status"] == "error"
    assert "source" in data["message"]


def test_platform_alerts_invalid_severity() -> None:
    """Test alert validation with invalid severity."""
    client = app.test_client()

    response = client.post(
        "/platform/alerts",
        json={
            "severity": "invalid",
            "message": "Test alert",
            "source": "test",
        },
    )

    assert response.status_code == HTTP_STATUS_BAD_REQUEST
    data = response.get_json()

    assert data["status"] == "error"


def test_platform_alerts_invalid_json() -> None:
    """Test alert validation with invalid JSON."""
    client = app.test_client()

    response = client.post(
        "/platform/alerts",
        data="not-json",
        content_type="application/json",
    )

    assert response.status_code == HTTP_STATUS_BAD_REQUEST

    data = response.get_json()

    assert data["status"] == "error"
    assert data["message"] == "Request body must be JSON"


def test_platform_alerts_empty_strings() -> None:
    """Test alert validation with empty strings."""
    client = app.test_client()

    response = client.post(
        "/platform/alerts",
        json={
            "severity": "",
            "message": "",
            "source": "",
        },
    )

    assert response.status_code == HTTP_STATUS_BAD_REQUEST

    data = response.get_json()

    assert data["status"] == "error"

def test_platform_alerts_message_too_long() -> None:
    """Test alert validation with an oversized message."""
    client = app.test_client()

    response = client.post(
        "/platform/alerts",
        json={
            "severity": "critical",
            "message": "x" * 4097,
            "source": "cloudwatch",
        },
    )

    assert response.status_code == HTTP_STATUS_BAD_REQUEST

    data = response.get_json()

    assert data["status"] == "error"
    assert data["message"] == "message must not exceed 4096 characters"


def test_platform_alerts_source_too_long() -> None:
    """Test alert validation with an oversized source."""
    client = app.test_client()

    response = client.post(
        "/platform/alerts",
        json={
            "severity": "critical",
            "message": "Test alert",
            "source": "x" * 257,
        },
    )

    assert response.status_code == HTTP_STATUS_BAD_REQUEST

    data = response.get_json()

    assert data["status"] == "error"
    assert data["message"] == "source must not exceed 256 characters"


def test_platform_alerts_request_body_too_large() -> None:
    """Test alert endpoint rejects an oversized request body."""
    client = app.test_client()

    response = client.post(
        "/platform/alerts",
        data="x" * (8 * 1024 + 1),
        content_type="application/json",
    )

    assert response.status_code == 413  # noqa: PLR2004 # Default status from Flask

def test_platform_alerts_unable_to_write_log() -> None:
    """Test alert endpoint when log writing fails."""
    alert = {
        "severity": "critical",
        "message": "High CPU usage detected",
        "source": "cloudwatch",
    }

    with patch(
        "src.app.platform.alerts.Path.open",
        side_effect=OSError("Permission denied"),
    ), patch(
        "src.app.platform.alerts.Path.mkdir",
    ):

        client = app.test_client()

        response = client.post(
            "/platform/alerts",
            json=alert,
        )

        assert response.status_code == HTTP_STATUS_INTERNAL_SERVER_ERROR

        data = response.get_json()

        assert data["status"] == "error"
        assert data["message"] == "Unable to write alert log"
