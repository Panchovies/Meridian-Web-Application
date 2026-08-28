#!/usr/bin/env python3
# Copyright (c) 2026 Meridian Capital Markets
"""Print a formatted deployment status report for the EKS cluster.

The report includes the cluster name, node count and status, deployment name
and replica count, current image tag, and the timestamp of the most recent
deployment.
"""

import sys
from datetime import UTC, datetime

from kubernetes import client, config

NAMESPACE = "default"
DEPLOYMENT_NAME = "meridian-web-application"


def get_cluster_name() -> str:
    """Return the Kubernetes cluster name from the active kubeconfig context."""
    _, active_context = config.list_kube_config_contexts()
    return active_context["context"]["cluster"]


def get_node_status(node: client.V1Node) -> str:
    """Return the readiness status for a Kubernetes node."""
    for condition in node.status.conditions or []:
        if condition.type == "Ready":
            return "Ready" if condition.status == "True" else "NotReady"
    return "Unknown"


def get_image_tag(image: str) -> str:
    """Extract the tag from a container image."""
    image_name = image.split("@", maxsplit=1)[0]

    if ":" in image_name.rsplit("/", 1)[-1]:
        return image_name.rsplit(":", 1)[-1]

    return "latest"


def format_timestamp(timestamp: datetime | None) -> str:
    """Format a Kubernetes timestamp for the report."""
    if timestamp is None:
        return "Unknown"

    if timestamp.tzinfo is None:
        timestamp = timestamp.replace(tzinfo=UTC)

    return timestamp.strftime("%Y-%m-%d %H:%M:%S UTC")


def main() -> None:
    """Query the cluster and print the deployment status report."""
    config.load_kube_config()

    core_api = client.CoreV1Api()
    apps_api = client.AppsV1Api()

    cluster_name = get_cluster_name()
    nodes = core_api.list_node().items

    deployment = apps_api.read_namespaced_deployment(
        name=DEPLOYMENT_NAME,
        namespace=NAMESPACE,
    )

    desired_replicas = deployment.spec.replicas or 0
    current_replicas = deployment.status.replicas or 0
    ready_replicas = deployment.status.ready_replicas or 0

    container = deployment.spec.template.spec.containers[0]
    image = container.image
    image_tag = get_image_tag(image)

    last_deployment_time = None

    for condition in deployment.status.conditions or []:
        if condition.type == "Progressing" and condition.status == "True":
            last_deployment_time = condition.last_update_time
            break

    report = f"""
============================================================
           EKS CLUSTER STATUS REPORT
============================================================

CLUSTER
  Name:       {cluster_name}

NODES
  Total:      {len(nodes)}
"""

    for node in nodes:
        report += f"  {node.metadata.name}: {get_node_status(node)}\n"

    report += f"""
DEPLOYMENT
  Name:       {DEPLOYMENT_NAME}
  Namespace:  {NAMESPACE}
  Replicas:   {ready_replicas} ready /
              {current_replicas} current /
              {desired_replicas} desired

CONTAINER
  Name:       {container.name}
  Image:      {image}
  Tag:        {image_tag}

LAST DEPLOYMENT
  Timestamp:  {format_timestamp(last_deployment_time)}

============================================================
"""

    sys.stdout.write(report)


if __name__ == "__main__":
    main()
