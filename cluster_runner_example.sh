#!/bin/bash

export AWS_PAGER=""

echo "Creating cluster..."

eksctl create cluster --name meridian-cluster --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.small \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --managed

echo "Cluster created! Updating kubeconfig..."

aws eks update-kubeconfig \
  --region us-east-1 \
  --name meridian-cluster

echo "kubeconfig updated! Adding API key..."

kubectl create secret generic meridian-api-keys \
  --from-literal=NEWS_API_KEY=<YOUR_API_KEY>

echo "API key added! Applying manifests..."

kubectl apply -f k8s/app/

echo "Manifests applied! Adding Add-ons..."

echo "Pod Identity..."

aws eks create-addon --cluster-name meridian-cluster --addon-name eks-pod-identity-agent --region us-east-1

echo "Waiting for Pod Identity install..."

aws eks wait addon-active --cluster-name meridian-cluster --addon-name eks-pod-identity-agent --region us-east-1

echo "Configuring Pod Identity to CloudWatch..."

aws eks create-pod-identity-association --cluster-name meridian-cluster \
    --namespace amazon-cloudwatch \
    --service-account cloudwatch-agent \
    --role-arn arn:aws:iam::<YOUR_AWS_ID>:role/CloudWatchObservabilityRole-meridian  \
    --region us-east-1

echo "CloudWatch..."

aws eks create-addon --cluster-name meridian-cluster --addon-name amazon-cloudwatch-observability  --region us-east-1

echo "Waiting for CloudWatch install..."

aws eks wait addon-active --cluster-name meridian-cluster --addon-name amazon-cloudwatch-observability --region us-east-1

echo "Updating CloudWatch..."

aws eks update-addon \
  --cluster-name meridian-cluster \
  --addon-name amazon-cloudwatch-observability \
  --configuration-values '{"containerInsights":{"enabled":true},"otelContainerInsights":{"enabled":true}}'

echo "Cluster is set up with CloudWatch! Wait approx 5 minutes for insights to show on AWS"