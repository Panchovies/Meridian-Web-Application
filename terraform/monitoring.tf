### Adds Cloudwatch Observability Add-on ###
resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "amazon-cloudwatch-observability"

  # Pass the JSON configuration 
  configuration_values = jsonencode({
    containerInsights = {
      enabled = false
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


### High Pod CPU Utilization ###
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

### High Container Restarts ###
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

### High Target 5XX Error Rate ###
resource "aws_cloudwatch_metric_alarm" "target_5xx_error_rate" {
  alarm_name          = "${var.project_name}-HighTarget5xxErrorRate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_description   = "FlaskAPI Target 5XX error rate exceeds 1% of total requests over 5 minutes."

  metric_query {
    id          = "e1"
    expression  = "IF(m_req > 0, (m_5xx / m_req) * 100, 0)"
    label       = "Target 5XX Error Rate (%)"
    return_data = true
  }

  metric_query {
    id = "m_5xx"
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = aws_lb.meridian.arn_suffix
        TargetGroup  = aws_lb_target_group.meridian.arn_suffix
      }
    }
  }

  metric_query {
    id = "m_req"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = aws_lb.meridian.arn_suffix
      }
    }
  }
}

### High ELB 5XX Error Rate ###
resource "aws_cloudwatch_metric_alarm" "elb_5xx_error_rate" {
  alarm_name          = "${var.project_name}-HighELB5xxErrorRate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_description   = "ALB-generated 5XX errors (e.g. 502/504) exceed 1% of total requests over 5 minutes."

  metric_query {
    id          = "e2"
    expression  = "IF(m_req > 0, (m_elb_5xx / m_req) * 100, 0)"
    label       = "ELB 5XX Error Rate (%)"
    return_data = true
  }

  metric_query {
    id = "m_elb_5xx"
    metric {
      metric_name = "HTTPCode_ELB_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = aws_lb.meridian.arn_suffix
      }
    }
  }

  metric_query {
    id = "m_req"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = aws_lb.meridian.arn_suffix
      }
    }
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
