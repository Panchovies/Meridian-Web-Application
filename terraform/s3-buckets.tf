### KMS key for Meridian S3 encryption ###
### Shared by both buckets ###
resource "aws_kms_key" "s3" {
  description             = "KMS key for Meridian S3 bucket encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.s3_kms.json

  tags = {
    Name = "${var.project_name}-s3-kms"
  }
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.project_name}-s3"
  target_key_id = aws_kms_key.s3.key_id
}

### Trade Data Bucket ###
resource "aws_s3_bucket" "trade_data" {
  bucket = "${var.trade_data_bucket_name}-${data.aws_caller_identity.current.account_id}"
}

### S3 bucket policy for trade data bucket ###
resource "aws_s3_bucket_policy" "trade_data" {
  bucket = aws_s3_bucket.trade_data.id
  policy = data.aws_iam_policy_document.trade_data.json
}

resource "aws_s3_bucket_versioning" "trade_data" {
  bucket = aws_s3_bucket.trade_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

### Server-side encryption ###
resource "aws_s3_bucket_server_side_encryption_configuration" "trade_data" {
  bucket = aws_s3_bucket.trade_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

### Block public access to the bucket ###
resource "aws_s3_bucket_public_access_block" "trade_data" {
  bucket = aws_s3_bucket.trade_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

### Pipeline Artifacts Bucket ###
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "${var.pipeline_artifacts_bucket_name}-${data.aws_caller_identity.current.account_id}"
}

### S3 bucket policy for pipeline artifacts bucket ###
resource "aws_s3_bucket_policy" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  policy = data.aws_iam_policy_document.pipeline_artifacts.json
}

### Server-side encryption ###
resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

### Block public access to the bucket ###
resource "aws_s3_bucket_public_access_block" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
