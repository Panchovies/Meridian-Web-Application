# --- EKS cluster ---

output "eks_cluster_endpoint" {
  description = "API server endpoint for the EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA cert, needed to build a kubeconfig"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

# --- Load Balancer ---

output "load_balancer_dns_name" {
  description = "DNS name of the ALB fronting Meridian"
  value       = aws_lb.meridian.dns_name
}

# --- ECR ---

output "ecr_repository_url" {
  description = "URL of the ECR repository for the Meridian Flask image"
  value       = aws_ecr_repository.ecr.repository_url
}

# --- S3 ---

output "s3_trade_data_bucket_name" {
  description = "Name of the versioned S3 bucket storing trade data"
  value       = aws_s3_bucket.trade_data.id
}

output "s3_pipeline_artifacts_bucket_name" {
  description = "Name of the S3 bucket storing pipeline artifacts"
  value       = aws_s3_bucket.pipeline_artifacts.id
}