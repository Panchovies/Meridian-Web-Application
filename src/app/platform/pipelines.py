# Copyright (c) 2026 Meridian Capital Markets
"""GitLab pipeline endpoint."""
import os
from datetime import datetime

import requests
from flask import jsonify

from app.constants import (
    HTTP_STATUS_INTERNAL_SERVER_ERROR,
    HTTP_STATUS_OK,
)

from . import platform_bp


def _duration(started_at: str, finished_at: str) -> float | None:
    if not started_at or not finished_at:
        return None
    try:
        start = datetime.fromisoformat(started_at)
        end = datetime.fromisoformat(finished_at)
        return round((end - start).total_seconds(), 2)
    except ValueError:
        return None


def fetch_pipelines() -> tuple:
    """Fetch the last n pipelines."""
    url = os.getenv("GITLAB_API_URL", "https://gitlab.com/api/v4")
    project_id = os.getenv("GITLAB_PROJECT_ID")
    token = os.getenv("GITLAB_TOKEN")
    if not project_id or not token:
        return None, "GITLAB_PROJECT_ID and GITLAB_TOKEN are required"

    params: dict[str, str | int] = {
        "order_by": "id",
        "sort": "desc",
        "per_page": 10,
    }

    response = requests.get(
        f"{url}/projects/{project_id}/pipelines",
        headers={"PRIVATE-TOKEN": token},
        params=params,
        timeout=5,
    )
    response.raise_for_status()
    pipelines = []
    for pipeline in response.json():
        detail = requests.get(
            f"{url}/projects/{project_id}/pipelines/{pipeline['id']}",
            headers={"PRIVATE-TOKEN": token}, timeout=5,
        )
        detail.raise_for_status()
        item = detail.json()
        pipelines.append({
            "id": item.get("id"),
            "status": item.get("status"),
            "ref": item.get("ref"),
            "web_url": item.get("web_url"),
            "created_at": item.get("created_at"),
            "started_at": item.get("started_at"),
            "finished_at": item.get("finished_at"),
            "duration_seconds": item.get("duration") or
            _duration(item.get("started_at"), item.get("finished_at")),
        })
    return pipelines, None


@platform_bp.get("/platform/pipelines")
def platform_pipelines() -> tuple:
    """Attempt to fetch pipelines."""
    try:
        pipelines, error = fetch_pipelines()
        if error:
            return (jsonify({"status": "error", "message": error}),
                    HTTP_STATUS_INTERNAL_SERVER_ERROR)
        return (jsonify({"count": len(pipelines), "pipelines": pipelines}),
                HTTP_STATUS_OK)
    except requests.RequestException:
        return (jsonify({"status": "error", "message":
                         "GitLab request failed."}),
                         HTTP_STATUS_INTERNAL_SERVER_ERROR)
