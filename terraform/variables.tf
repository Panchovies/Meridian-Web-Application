variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "project_name" {
  description = "Short name used to prefix/tag resources"
  type        = string
}

variable "application_service_name" {
  description = "Kubernetes Service name for the application"
  type        = string
}

variable "trade_data_bucket_name" {
  description = "Base name for the trade data S3 bucket (account ID is appended for uniqueness)"
  type        = string
}

variable "pipeline_artifacts_bucket_name" {
  description = "Base name for the pipeline artifacts S3 bucket (account ID is appended for uniqueness)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

# Two AZs — EKS requires worker subnets in at least two.
variable "availability_zones" {
  description = "AZs to spread subnets across"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets, one per AZ"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private (worker node) subnets, one per AZ"
  type        = list(string)
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
}

variable "node_instance_types" {
  description = "Instance types for the managed node group"
  type        = list(string)
}

variable "node_desired_size" {
  type    = number
}

variable "node_min_size" {
  type    = number
}

variable "node_max_size" {
  type    = number
}
