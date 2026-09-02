### Adds Cloudwatch Observability Add-on ###
resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "amazon-cloudwatch-observability"

  # Pass the JSON configuration 
  configuration_values = jsonencode({
    containerInsights = {
      enabled = true
    }
    otelContainerInsights = {
      enabled = true
    }
  })

  depends_on = [
    aws_eks_node_group.main,
    aws_eks_pod_identity_association.cloudwatch_observability,
  ]
}

### CreatesCloudwatch Alarms for EKS Cluster ###

resource "aws_cloudwatch_metric_alarm" "high_pod_cpu" {
  alarm_name          = "${var.project_name}-HighPodCpuOverLimit"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "pod_cpu_utilization_over_pod_limit"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Maximum"
  threshold           = 80
  treat_missing_data  = "notBreaching"
  alarm_description   = "Container Insights pod_cpu_utilization_over_pod_limit exceeds 80%."

  # Why: Terraform dynamically references the cluster name created in eks.tf
  dimensions = {
    ClusterName = aws_eks_cluster.main.name
    Namespace   = "default"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_container_restarts" {
  alarm_name          = "${var.project_name}-HighContainerRestarts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "pod_number_of_container_restarts"
  namespace           = "ContainerInsights"
  period              = 600
  statistic           = "Maximum"
  threshold           = 3
  treat_missing_data  = "ignore"
  alarm_description   = "Container Insights pod_number_of_container_restarts exceeds 3."

  dimensions = {
    ClusterName = aws_eks_cluster.main.name
    Namespace   = "default"
  }
}

### Adds Metrics Server Add-on for HPA ###
resource "aws_eks_addon" "metrics_server" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "metrics-server"

  depends_on = [
    aws_eks_node_group.main,
  ]
}
