#!/usr/bin/env bash
set -e

TF_DIR="terraform"
FILES=(
    "load-balancer-controller.tf"
    "post_eks_providers.tf"
    "secrets.tf"
    "rbac.tf"
)

cd "$TF_DIR"

for f in "${FILES[@]}"; do
    mv "$f" "$f.bak"
done

if ! terraform apply -auto-approve; then
    echo "First apply failed, restoring files..."
    for f in "${FILES[@]}"; do
        mv "$f.bak" "$f"
    done
    exit 1
fi

for f in "${FILES[@]}"; do
    mv "$f.bak" "$f"
done

terraform apply -auto-approve
