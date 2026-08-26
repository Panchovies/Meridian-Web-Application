#!/bin/bash
set -euo pipefail

export AWS_PAGER=""

echo "Creating cluster..."

eksctl create cluster --name meridian-cluster --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.small \
  --nodes 4 \
  --nodes-min 3 \
  --nodes-max 5 \
  --managed

echo "Cluster created! Updating kubeconfig..."

aws eks update-kubeconfig \
  --region us-east-1 \
  --name meridian-cluster

echo "kubeconfig updated! Installing EKS Pod Identity Agent..."

aws eks create-addon \
  --cluster-name meridian-cluster \
  --addon-name eks-pod-identity-agent \
  --region us-east-1

echo "Waiting for Pod Identity Agent install..."

aws eks wait addon-active \
  --cluster-name meridian-cluster \
  --addon-name eks-pod-identity-agent \
  --region us-east-1

echo "Pod Identity Agent active! Setting up AWS Load Balancer Controller..."

kubectl create serviceaccount aws-load-balancer-controller -n kube-system

aws eks create-pod-identity-association \
  --cluster-name meridian-cluster \
  --namespace kube-system \
  --service-account aws-load-balancer-controller \
  --role-arn arn:aws:iam::<YOUR_AWS_ID>:role/AWSLoadBalancerControllerRole \
  --region us-east-1

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=meridian-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

echo "ALB Controller installed! Adding API key..."

kubectl create secret generic meridian-api-keys \
  --from-literal=NEWS_API_KEY=<YOUR_API_KEY>

echo "API key added! Applying manifests..."

kubectl apply -f k8s/app/

echo "Manifests applied! Adding CloudWatch Add-ons..."

echo "Configuring Pod Identity to CloudWatch..."

aws eks create-pod-identity-association --cluster-name meridian-cluster \
    --namespace amazon-cloudwatch \
    --service-account cloudwatch-agent \
    --role-arn arn:aws:iam::<YOUR_AWS_ID>:role/CloudWatchObservabilityRole-meridian \
    --region us-east-1

echo "CloudWatch..."

aws eks create-addon --cluster-name meridian-cluster --addon-name amazon-cloudwatch-observability --region us-east-1

echo "Waiting for CloudWatch install..."

aws eks wait addon-active --cluster-name meridian-cluster --addon-name amazon-cloudwatch-observability --region us-east-1

echo "Updating CloudWatch..."

aws eks update-addon \
  --cluster-name meridian-cluster \
  --addon-name amazon-cloudwatch-observability \
  --configuration-values '{"containerInsights":{"enabled":true},"otelContainerInsights":{"enabled":true}}'

echo "Cluster is set up with the ALB Controller and CloudWatch! Wait approx 5 minutes for insights to show on AWS"