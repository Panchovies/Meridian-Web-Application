resource "aws_s3_bucket" "trade_data" {
  bucket = "${var.trade_data_bucket_name}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "trade_data" {
  bucket = aws_s3_bucket.trade_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "${var.pipeline_artifacts_bucket_name}-${data.aws_caller_identity.current.account_id}"
}
