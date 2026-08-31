resource "aws_s3_bucket" "trade_data" {
  bucket = "meridian-trade-data-${data.aws_caller_identity.current.account_id}"
}
