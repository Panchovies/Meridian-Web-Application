# Copyright (c) 2026 Meridian Capital Markets
"""Tests for the GitLab pipelines endpoint."""

from unittest.mock import Mock, patch

import requests
from src.app.app import app
from src.app.constants import (
    HTTP_STATUS_INTERNAL_SERVER_ERROR,
    HTTP_STATUS_OK,
)


def test_platform_pipelines_success() -> None:
    """Test successful GitLab pipeline retrieval."""
    mock_response = Mock()

    mock_response.json.return_value = [
        {
            "id": 100,
            "status": "success",
            "ref": "main",
            "web_url": "https://gitlab.com/pipeline/100",
        },
    ]

    mock_response.raise_for_status.return_value = None

    detail_response = Mock()

    detail_response.json.return_value = {
        "id": 100,
        "status": "success",
        "ref": "main",
        "web_url": "https://gitlab.com/pipeline/100",
        "created_at": "2026-09-16T12:00:00Z",
        "started_at": "2026-09-16T12:00:00Z",
        "finished_at": "2026-09-16T12:05:00Z",
        "duration": 300,
    }

    detail_response.raise_for_status.return_value = None

    with patch(
        "src.app.platform.pipelines.requests.get",
        side_effect=[
            mock_response,
            detail_response,
        ],
    ) as mock_get, patch.dict(
        "os.environ",
        {
            "GITLAB_API_URL": "https://gitlab.com/api/v4",
            "GITLAB_TOKEN": "test-token",
        },
    ):

        client = app.test_client()

        response = client.get("/platform/pipelines")

        assert response.status_code == HTTP_STATUS_OK

        data = response.get_json()

        # id and duration are just test constants, no reason to make a variable
        assert data["count"] == 1
        assert data["pipelines"][0]["id"] == 100  # noqa: PLR2004
        assert data["pipelines"][0]["status"] == "success"
        assert data["pipelines"][0]["duration_seconds"] == 300  # noqa: PLR2004

        assert mock_get.call_count == 2  # noqa: PLR2004


def test_platform_pipelines_missing_environment_variables() -> None:
    """Test missing GitLab configuration."""
    with patch.dict(
        "os.environ",
        {},
        clear=True,
    ):

        client = app.test_client()

        response = client.get("/platform/pipelines")

        assert response.status_code == HTTP_STATUS_INTERNAL_SERVER_ERROR

        data = response.get_json()

        assert data["status"] == "error"


def test_platform_pipelines_gitlab_error() -> None:
    """Test GitLab API failure."""
    with patch.dict(
        "os.environ",
        {
            "GITLAB_API_URL": "https://gitlab.com/api/v4",
            "GITLAB_TOKEN": "test-token",
        },
    ), patch(
        "src.app.platform.pipelines.requests.get",
        side_effect=requests.RequestException(
            "GitLab unavailable",
        ),
    ):

        client = app.test_client()

        response = client.get("/platform/pipelines")

        assert response.status_code == HTTP_STATUS_INTERNAL_SERVER_ERROR

        data = response.get_json()

        assert data["status"] == "error"
        assert "GitLab request failed" in data["message"]
