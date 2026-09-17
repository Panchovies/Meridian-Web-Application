# Copyright (c) 2026 Meridian Capital Markets
"""Tests for the combined platform status endpoint."""

from unittest.mock import Mock, patch

from botocore.exceptions import ClientError
from src.app.app import app
from src.app.constants import (
    HTTP_STATUS_INTERNAL_SERVER_ERROR,
    HTTP_STATUS_OK,
)


def test_platform_status_success() -> None:
    """Test combined platform status retrieval."""
    mock_eks_client = Mock()

    mock_eks_client.describe_cluster.return_value = {
        "cluster": {
            "name": "meridian-cluster",
            "status": "ACTIVE",
            "version": "1.34",
        },
    }

    mock_cloudwatch_client = Mock()

    mock_cloudwatch_client.describe_alarms.return_value = {
        "MetricAlarms": [],
    }

    mock_pipelines = [
        {
            "id": 100,
            "status": "success",
            "duration_seconds": 300,
        },
    ]

    with patch(
        "src.app.platform.status.boto3.client",
        side_effect=[
            mock_eks_client,
            mock_cloudwatch_client,
        ],
    ), patch(
        "src.app.platform.status.fetch_pipelines",
        return_value=(mock_pipelines, None),
    ), patch.dict(
        "os.environ",
        {
            "EKS_CLUSTER_NAME": "meridian-cluster",
            "AWS_REGION": "us-east-1",
        },
    ):
        client = app.test_client()

        response = client.get("/platform/status")

        assert response.status_code == HTTP_STATUS_OK

        data = response.get_json()

        assert data["platform_api"]["status"] == "ok"
        assert data["eks"]["status"] == "ACTIVE"
        assert data["eks"]["name"] == "meridian-cluster"
        assert data["eks"]["version"] == "1.34"
        assert data["flask_application"]["status"] == "ok"

        # id is a test constant, does not need a variable
        assert data["pipelines"][0]["id"] == 100  # noqa: PLR2004
        assert data["pipelines"][0]["status"] == "success"

        assert data["cloudwatch_alarms"] == []

        mock_eks_client.describe_cluster.assert_called_once_with(
            name="meridian-cluster",
        )

        mock_cloudwatch_client.describe_alarms.assert_called_once_with(
            StateValue="ALARM",
        )


def test_platform_status_unhealthy() -> None:
    """Test unhealthy platform status."""
    mock_eks_client = Mock()

    mock_eks_client.describe_cluster.return_value = {
        "cluster": {
            "name": "meridian-cluster",
            "status": "FAILED",
            "version": "1.34",
        },
    }

    mock_cloudwatch_client = Mock()

    mock_cloudwatch_client.describe_alarms.return_value = {
        "MetricAlarms": [
            {
                "AlarmName": "meridian-HighPodCpuOverLimit",
                "StateReason": "Threshold crossed",
            },
        ],
    }

    mock_pipelines = [
        {
            "id": 100,
            "status": "failed",
            "duration_seconds": 300,
        },
    ]

    with patch(
        "src.app.platform.status.boto3.client",
        side_effect=[
            mock_eks_client,
            mock_cloudwatch_client,
        ],
    ), patch(
        "src.app.platform.status.fetch_pipelines",
        return_value=(mock_pipelines, None),
    ), patch.dict(
        "os.environ",
        {
            "EKS_CLUSTER_NAME": "meridian-cluster",
            "AWS_REGION": "us-east-1",
        },
    ):
        client = app.test_client()

        response = client.get("/platform/status")

        assert response.status_code == HTTP_STATUS_INTERNAL_SERVER_ERROR

        data = response.get_json()

        assert data["platform_api"]["status"] == "error"
        assert data["eks"]["status"] == "FAILED"
        assert len(data["cloudwatch_alarms"]) == 1
        assert data["pipelines"][0]["status"] == "failed"



def test_platform_status_missing_eks_environment_variable() -> None:
    """Test missing EKS cluster configuration."""
    with patch.dict(
        "os.environ",
        {
            "AWS_REGION": "us-east-1",
        },
        clear=True,
    ), patch(
        "src.app.platform.status.fetch_pipelines",
        return_value=([], None),
    ), patch(
        "src.app.platform.status.boto3.client",
    ) as mock_client:

        client = app.test_client()

        response = client.get("/platform/status")

        assert response.status_code == HTTP_STATUS_INTERNAL_SERVER_ERROR

        data = response.get_json()

        assert data["platform_api"]["status"] == "error"
        assert data["eks"]["status"] == "unknown"
        assert data["eks"]["message"] == (
            "EKS_CLUSTER_NAME is not configured"
        )

        mock_client.assert_called_once_with(
            "cloudwatch",
            region_name="us-east-1",
        )


def test_platform_status_eks_client_error() -> None:
    """Test EKS API client error failure."""
    mock_eks_client = Mock()

    mock_eks_client.describe_cluster.side_effect = ClientError(
        {
            "Error": {
                "Code": "ServiceUnavailable",
                "Message": "EKS unavailable",
            },
        },
        "DescribeCluster",
    )

    mock_cloudwatch_client = Mock()

    mock_cloudwatch_client.describe_alarms.return_value = {
        "MetricAlarms": [],
    }

    with patch(
        "src.app.platform.status.boto3.client",
        side_effect=[
            mock_eks_client,
            mock_cloudwatch_client,
        ],
    ), patch(
        "src.app.platform.status.fetch_pipelines",
        return_value=([], None),
    ), patch.dict(
        "os.environ",
        {
            "EKS_CLUSTER_NAME": "meridian-cluster",
            "AWS_REGION": "us-east-1",
        },
    ):
        client = app.test_client()

        response = client.get("/platform/status")

        assert response.status_code == HTTP_STATUS_INTERNAL_SERVER_ERROR

        data = response.get_json()

        assert data["platform_api"]["status"] == "error"
        assert data["eks"]["status"] == "error"
        assert data["eks"]["message"] == "ServiceUnavailable"


def test_platform_status_cloudwatch_client_error() -> None:
    """Test CloudWatch API client error failure."""
    mock_eks_client = Mock()

    mock_eks_client.describe_cluster.return_value = {
        "cluster": {
            "name": "meridian-cluster",
            "status": "ACTIVE",
            "version": "1.34",
        },
    }

    mock_cloudwatch_client = Mock()

    mock_cloudwatch_client.describe_alarms.side_effect = ClientError(
        {
            "Error": {
                "Code": "ServiceUnavailable",
                "Message": "CloudWatch unavailable",
            },
        },
        "DescribeAlarms",
    )

    with patch(
        "src.app.platform.status.boto3.client",
        side_effect=[
            mock_eks_client,
            mock_cloudwatch_client,
        ],
    ), patch(
        "src.app.platform.status.fetch_pipelines",
        return_value=([], None),
    ), patch.dict(
        "os.environ",
        {
            "EKS_CLUSTER_NAME": "meridian-cluster",
            "AWS_REGION": "us-east-1",
        },
    ):
        client = app.test_client()

        response = client.get("/platform/status")

        assert response.status_code == HTTP_STATUS_INTERNAL_SERVER_ERROR

        data = response.get_json()

        assert data["platform_api"]["status"] == "error"
        assert data["cloudwatch_alarms"]["status"] == "error"
        assert data["cloudwatch_alarms"]["message"] == "ServiceUnavailable"
