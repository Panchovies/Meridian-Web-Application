#!/usr/bin/env bash
set -e

TF_DIR="terraform"
cd "$TF_DIR"

terraform destroy
