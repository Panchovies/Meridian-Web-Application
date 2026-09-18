#!/usr/bin/env bash
set -e

TF_DIR="terraform"
AWS_REGION="us-east-1"
ECR_REPO_NAME="terraform-meridian-web-application"
DEPLOYMENT_NAME="meridian-web-application"
CLUSTER_NAME="meridian-cluster"
ROLLOUT_TIMEOUT="180s"

terraform -chdir="$TF_DIR" init

# --- 1. Terraform: EKS cluster first, then the rest ---
terraform -chdir="$TF_DIR" apply -target=aws_eks_cluster.main

terraform -chdir="$TF_DIR" apply

# --- 2. Build the image for EKS (linux/amd64) ---
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
# This image tag uses the commit SHA to tag along with the date in seconds
# If not in a repository, uses :local instead of the SHA 
IMAGE_TAG="$(git rev-parse --short HEAD 2>/dev/null || echo local)-$(date +%s)"
MERIDIAN_IMAGE="${ECR_REGISTRY}/${ECR_REPO_NAME}:${IMAGE_TAG}"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Use buildx so this builds amd64
# EKS worker nodes here are amd64, so we force that platform.
docker buildx build \
  --platform linux/amd64 \
  -t "$MERIDIAN_IMAGE" \
  --push \
  .

export MERIDIAN_IMAGE

# --- 3. Apply the k8s manifests with the new image substituted in ---
# Manifests should reference the image as ${MERIDIAN_IMAGE};
# envsubst fills in the variable
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

kubectl apply -f k8s/app/configmap.yaml -f k8s/app/service.yaml -f k8s/app/hpa.yaml
envsubst < k8s/app/deployment.yaml | kubectl apply -f -


# --- 4. Wait for the workload to come up ---
kubectl rollout status "deployment/${DEPLOYMENT_NAME}" --timeout="$ROLLOUT_TIMEOUT"
