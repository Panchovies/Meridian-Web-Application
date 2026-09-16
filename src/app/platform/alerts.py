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


def _alert_log_path() -> Path:
    return Path(os.getenv("PLATFORM_ALERT_LOG", "logs/platform-alerts.jsonl"))


@platform_bp.post("/platform/alerts")
def platform_alerts() -> tuple:
    """Accept an alert from a platform component."""
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
                        "must be non-empty strings"}), HTTP_STATUS_BAD_REQUEST)

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
