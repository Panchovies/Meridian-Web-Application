#!/bin/bash

# Directory of the script must have a .deploy_var file with the following variables:
# AWS_KEY_PATH: Path to the AWS EC2 private key file (e.g., /path/to/key.pem)
# AWS_PUBLIC_IP: Public IP address of the AWS EC2 instance
# AWS_REGION: AWS region where the ECR repository is located (e.g., us-east-1)
# AWS_ACCOUNT_ID: AWS account ID (e.g., 123456789012)
# ECR_URI: URI of the ECR repository (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-repo)
# IMAGE_TAG: Tag of the Docker image to deploy (e.g., latest)
# CONTAINER_NAME: Name of the Docker container to run (e.g., my-container)
# HOST_PORT: Port on the host machine to map to the container (e.g., 8080)
# CONTAINER_PORT: Port inside the container to expose (e.g., 80)

# The EC2 instance must be running before executing this script
# The EC2 instance must be closed manually after the script is executed
set -euo pipefail

source .deploy_var


ssh -i "$AWS_KEY_PATH" "ec2-user@${AWS_PUBLIC_IP}" << EOF

echo "Logging in to AWS ECR..." 
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "Pulling Docker image from ECR..." 
docker pull "${ECR_URI}:${IMAGE_TAG}" 

echo "Stopping and removing existing container (if any)..."
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true
 
echo "Running new container..."
docker run -d \
  --name "$CONTAINER_NAME" \
  -p "${HOST_PORT}:${CONTAINER_PORT}" \
  --restart unless-stopped \
  "${ECR_URI}:${IMAGE_TAG}"
 
echo "Deployment completed. Container is running."
docker ps --filter "name=${CONTAINER_NAME}"

EOF