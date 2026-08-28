#!/bin/bash

# Grab the ALB ARN BEFORE deleting the Ingress
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'meridian')].LoadBalancerArn" \
  --output text)

kubectl delete ingress meridian-web-application-ingress -n default

if [ -n "$ALB_ARN" ]; then
  echo "Waiting for ALB to be deprovisioned..."
  aws elbv2 wait load-balancers-deleted --load-balancer-arns "$ALB_ARN"
fi

kubectl delete svc meridian-web-application -n default
  
eksctl delete cluster meridian-cluster