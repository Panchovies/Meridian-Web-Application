#!/usr/bin/env python3
# Copyright (c) 2026 Meridian Capital Markets
"""Print the status of the five most recent GitLab pipelines.

The report includes pipeline status, duration, and the stage that failed,
if a pipeline failed.
"""

import sys
from pathlib import Path

import gitlab

TOKEN_FILE = Path(".gitlab-token")
GITLAB_URL = "https://gitlab.com"
PROJECT_ID = "85075367"
PIPELINE_LIMIT = 5


def get_gitlab_token() -> str:
    """Read the GitLab API token from the .token file."""
    return TOKEN_FILE.read_text(encoding="utf-8").strip()


def format_duration(duration: float | None) -> str:
    """Format a pipeline duration in seconds."""
    if duration is None:
        return "Unknown"

    minutes, seconds = divmod(int(duration), 60)
    return f"{minutes}m {seconds}s"


def get_failed_stage(pipeline: object) -> str:
    """Return the stage containing a failed job."""
    jobs = pipeline.jobs.list(get_all=True)

    for job in jobs:
        if job.status == "failed":
            return str(job.stage)

    return "None"


def main() -> None:
    """Fetch recent pipelines and print their deployment status."""
    token = get_gitlab_token()

    gl = gitlab.Gitlab(
        GITLAB_URL,
        private_token=token,
    )

    project = gl.projects.get(PROJECT_ID)

    pipelines = project.pipelines.list(
        order_by="updated_at",
        sort="desc",
        per_page=PIPELINE_LIMIT,
    )

    report = """
============================================================
              RECENT GITLAB PIPELINE STATUS
============================================================
"""

    for pipeline_summary in pipelines:
        pipeline = project.pipelines.get(pipeline_summary.id)

        duration = format_duration(pipeline.duration)
        failed_stage = "N/A"

        if pipeline.status == "failed":
            failed_stage = get_failed_stage(pipeline)

        report += (
            f"\nPipeline:     #{pipeline.id}\n"
            f"Status:       {pipeline.status}\n"
            f"Duration:     {duration}\n"
            f"Started:      {pipeline.created_at}\n"
            f"Last Updated: {pipeline.updated_at}\n"
            f"Failed Stage: {failed_stage}\n"
            "------------------------------------------------------------\n"
        )

    report += (
        "\nSUMMARY\n"
        "The five most recent pipeline runs are listed above.\n"
        "============================================================\n"
    )

    sys.stdout.write(report)


if __name__ == "__main__":
    main()
