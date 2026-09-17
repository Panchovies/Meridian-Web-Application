# Copyright (c) 2026 Meridian Capital Markets
"""Alert intake endpoint."""
import json
import os
from datetime import UTC, datetime
from pathlib import Path
from threading import Lock

from flask import jsonify, request

from app.constants import (
    HTTP_STATUS_BAD_REQUEST,
    HTTP_STATUS_INTERNAL_SERVER_ERROR,
    HTTP_STATUS_OK,
)

from . import platform_bp

_LOG_LOCK = Lock()
_REQUIRED_FIELDS = {"severity", "message", "source"}
_ALLOWED_SEVERITIES = {"info", "warning", "critical"}
_MAX_MESSAGE_LENGTH = 4096
_MAX_SOURCE_LENGTH = 256


def _alert_log_path() -> Path:
    return Path(os.getenv("PLATFORM_ALERT_LOG", "logs/platform-alerts.jsonl"))


@platform_bp.post("/platform/alerts")
def platform_alerts() -> tuple:  # noqa: PLR0911 # This amount of returns are necessary
    """Accept an alert from a platform component.

    Request and field lengths are bounded to prevent excessive
    resource consumption from this public write endpoint.

    Alerts are currently written to pod-local files. With multiple
    replicas,
    each pod has its own file and the file is lost when the pod is
    replaced. Writing alerts to standard out would allow Kubernetes logging
    and Container Insights to collect them from every replica.
    """
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return (jsonify({"status": "error",
                        "message": "Request body must be JSON"}),
                HTTP_STATUS_BAD_REQUEST)

    missing = _REQUIRED_FIELDS - body.keys()
    if missing:
        return (jsonify({"status": "error", "message":
                        f"Missing fields: {sorted(missing)}"}),
                HTTP_STATUS_BAD_REQUEST)

    if body["severity"] not in _ALLOWED_SEVERITIES:
        return (jsonify({"status": "error", "message":
                        "severity must be info, warning, or critical"}),
                HTTP_STATUS_BAD_REQUEST)

    if not all(isinstance(body[field], str) and
               body[field].strip() for field in _REQUIRED_FIELDS):
        return (jsonify({"status": "error", "message":
                        "severity, message, and source "
                        "must be non-empty strings"}),
                HTTP_STATUS_BAD_REQUEST)

    if len(body["message"]) > _MAX_MESSAGE_LENGTH:
        return (jsonify({"status": "error", "message":
                        "message must not exceed 4096 characters"}),
                HTTP_STATUS_BAD_REQUEST)

    if len(body["source"]) > _MAX_SOURCE_LENGTH:
        return (jsonify({"status": "error", "message":
                        "source must not exceed 256 characters"}),
                HTTP_STATUS_BAD_REQUEST)

    alert = {
        "timestamp": datetime.now(UTC).isoformat(),
        "severity": body["severity"],
        "message": body["message"],
        "source": body["source"],
    }

    path = _alert_log_path()
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with _LOG_LOCK, path.open("a", encoding="utf-8") as log_file:
            log_file.write(json.dumps(alert) + "\n")
    except OSError:
        return (jsonify({"status": "error", "message":
                        "Unable to write alert log"}),
                HTTP_STATUS_INTERNAL_SERVER_ERROR)

    return jsonify({"status": "accepted", "alert": alert}), HTTP_STATUS_OK
