resource "aws_s3_bucket" "trade_data" {
  bucket = "meridian-trade-data-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "meridian-pipeline-artifacts-${data.aws_caller_identity.current.account_id}"
}