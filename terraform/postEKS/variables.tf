variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "application_service_name" {
  description = "Kubernetes Service name for the application"
  type        = string
}

variable "ALB_name" {
  description = "Name of the ALB"
  type        = string
}

variable "secrets_manager_name" {
  description = "Name of the AWS Secrets Manager"
  type        = string
}
