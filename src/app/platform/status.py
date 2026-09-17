# Copyright (c) 2026 Meridian Capital Markets
"""Combined platform status endpoint."""
import logging
import os
from datetime import UTC, datetime

import boto3
from botocore.exceptions import BotoCoreError, ClientError
from flask import current_app, jsonify

from app.constants import (
    HTTP_STATUS_INTERNAL_SERVER_ERROR,
    HTTP_STATUS_OK,
)

from . import platform_bp
from .pipelines import fetch_pipelines

logger = logging.getLogger(__name__)


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
    except ClientError as exc:
        logger.exception("Failed to fetch EKS cluster status")
        return {"status": "error", "message": exc.response["Error"]["Code"]}
    except BotoCoreError:
        logger.exception("Failed to fetch EKS cluster status")
        return {"status": "error", "message": "BotoCoreError"}


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
    except ClientError as exc:
        logger.exception("Failed to fetch CloudWatch alarms")
        return {"status": "error", "message": exc.response["Error"]["Code"]}
    except BotoCoreError:
        logger.exception("Failed to fetch CloudWatch alarms")
        return {"status": "error", "message": "BotoCoreError"}

@platform_bp.get("/platform/status")
def platform_status() -> tuple:
    """Return the status of the application."""
    pipelines, pipeline_error = fetch_pipelines()
    eks = _eks_status()
    cloudwatch_alarms = _cloudwatch_alarms()
    health_response = current_app.test_client().get("/health")
    health_data = health_response.get_json() or {}

    has_fetch_error = (
        eks["status"] in {"unknown", "error"}
        or (
            isinstance(cloudwatch_alarms, dict)
            and cloudwatch_alarms["status"] in {"unknown", "error"}
        )
        or pipeline_error is not None
    )

    eks_unhealthy = eks.get("status") != "ACTIVE"

    alarms_firing = (
        isinstance(cloudwatch_alarms, list)
        and len(cloudwatch_alarms) > 0
    )

    pipeline_unhealthy = (
        pipeline_error is None
        and (
            not pipelines
            or pipelines[0].get("status") != "success"
        )
    )

    has_error = has_fetch_error or (
        eks_unhealthy
        or alarms_firing
        or pipeline_unhealthy
    )

    return jsonify(
        {
            "timestamp": datetime.now(UTC).isoformat(),
            "platform_api": {
                "status": "error" if has_error else "ok",
            },
            "eks": eks,
            "flask_application": {
                "status": health_data.get("status", "error"),
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
