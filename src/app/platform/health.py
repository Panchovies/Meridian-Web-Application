# Copyright (c) 2026 Meridian Capital Markets
"""Platform API health endpoint."""

import os
from datetime import UTC, datetime

from flask import jsonify

from app.constants import (
    HTTP_STATUS_INTERNAL_SERVER_ERROR,
    HTTP_STATUS_OK,
)

from . import platform_bp


@platform_bp.get("/platform/health")
def platform_health() -> tuple:
    """Return the health of the API. Fails if GitLab token is not present."""
    gitlab_token = os.getenv("GITLAB_TOKEN")

    if not gitlab_token:
        return jsonify({
            "status": "unhealthy",
            "message": "GITLAB_TOKEN is missing",
        }), HTTP_STATUS_INTERNAL_SERVER_ERROR

    return jsonify({
        "status": "ok",
        "timestamp": datetime.now(UTC).isoformat(),
        "service": "platform-api",
    }), HTTP_STATUS_OK
