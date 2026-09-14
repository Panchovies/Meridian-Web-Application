#!/usr/bin/env bash
set -e

TF_DIR="terraform"

terraform -chdir="$TF_DIR" apply -target=aws_eks_cluster.main

terraform -chdir="$TF_DIR" apply
