provider "aws" {
  region = "us-east-1" # change if your Strategio sim environment uses a different region
}

data "aws_caller_identity" "current" {}
