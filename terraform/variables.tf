variable "trade_data_bucket_name" {
  description = "Base name for the trade data S3 bucket (account ID is appended for uniqueness)"
  type        = string
  default     = "meridian-trade-data"
}

variable "pipeline_artifacts_bucket_name" {
  description = "Base name for the pipeline artifacts S3 bucket (account ID is appended for uniqueness)"
  type        = string
  default     = "meridian-pipeline-artifacts"
}
