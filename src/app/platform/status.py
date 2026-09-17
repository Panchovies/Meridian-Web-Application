# Copyright (c) 2026 Meridian Capital Markets
"""Combined platform status endpoint."""
import os

import boto3
from botocore.exceptions import BotoCoreError, ClientError
from flask import jsonify

from app.constants import HTTP_STATUS_INTERNAL_SERVER_ERROR, HTTP_STATUS_OK

from . import platform_bp
from .pipelines import fetch_pipelines


def _eks_status() -> dict:
    try:
        cluster_name = os.getenv("EKS_CLUSTER_NAME")
        if not cluster_name:
            return {
                "status": "unknown",
                "message": "EKS_CLUSTER_NAME is not configured",
            }

        aws_region = os.getenv("AWS_REGION")
        if not aws_region:
            return {
                "status": "unknown",
                "message": "AWS_REGION is not configured",
            }

        client = boto3.client("eks", region_name=aws_region)
        cluster = client.describe_cluster(name=cluster_name)["cluster"]

        return {
            "status": cluster.get("status", "unknown"),
            "name": cluster.get("name"),
            "version": cluster.get("version"),
        }
    except (BotoCoreError, ClientError) as exc:
        return {"status": "error", "message": str(exc)}


def _cloudwatch_alarms() -> list | dict:
    try:
        aws_region = os.getenv("AWS_REGION")
        if not aws_region:
            return {
                "status": "unknown",
                "message": "AWS_REGION is not configured",
            }

        client = boto3.client("cloudwatch", region_name=aws_region)
        response = client.describe_alarms(StateValue="ALARM")

        return [
            {
                "name": alarm["AlarmName"],
                "reason": alarm.get("StateReason"),
            }
            for alarm in response.get("MetricAlarms", [])
        ]
    except (BotoCoreError, ClientError) as exc:
        return {"status": "error", "message": str(exc)}


@platform_bp.get("/platform/status")
def platform_status() -> tuple:
    """Return the status of the application."""
    pipelines, pipeline_error = fetch_pipelines()
    eks = _eks_status()
    cloudwatch_alarms = _cloudwatch_alarms()

    has_active_alarms = bool(cloudwatch_alarms) if isinstance(cloudwatch_alarms,
                                                              list) else True
    has_error = (
        eks.get("status") != "ACTIVE"
        or (isinstance(cloudwatch_alarms, dict) and
            cloudwatch_alarms.get("status") in {"unknown", "error"})
        or has_active_alarms
        or pipeline_error is not None
    )

    return jsonify(
        {
            "timestamp": __import__("datetime").datetime.now(
                __import__("datetime").UTC,
            ).isoformat(),
            "platform_api": {
                "status": "error" if has_error else "ok",
            },
            "eks": eks,
            "flask_application": {
                "status": "ok",
            },
            "pipelines": (
                pipelines
                if pipeline_error is None
                else {
                    "status": "error",
                    "message": pipeline_error,
                }
            ),
            "cloudwatch_alarms": cloudwatch_alarms,
        },
    ), (
        HTTP_STATUS_INTERNAL_SERVER_ERROR
        if has_error
        else HTTP_STATUS_OK
    )
