#!/bin/bash

echo "Can kubectl connect to the cluster?"

RESULT=$(kubectl config current-context)

if [ "$RESULT" = "arn:aws:eks:us-east-1:163558211438:cluster/meridian-cluster" ]; then
    echo "Kubectl is connected to meridian-cluster."
else
    echo "Kubectl is not connected to meridian-cluster"
    exit 1
fi

echo "Are pods running?"

RESULT=$(kubectl get pods --no-headers | grep -c "Running")

if [ "$RESULT" -gt 0 ]; then
    echo "Expected pods ($RESULT) running"
else
    echo "No pods running"
    exit 1
fi

echo "Load Balancer returns 200?"

INGRESS_URL=$(kubectl get ingress meridian-web-application-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 10 \
    "http://$INGRESS_URL/health")

if [ "$RESULT" -eq 200 ]; then
    echo "Load Balancer returned 200"
else
    echo "Load Balancer returned $RESULT"
    exit 1
fi

echo "CloudWatch in alarm?"

RESULT=$(aws cloudwatch describe-alarms \
    --query 'MetricAlarms[?StateValue==`ALARM`].AlarmName' \
    --output text)

if [ -n "$RESULT" ]; then
    echo "CloudWatch alarms currently in ALARM:"
    echo "$RESULT"
    exit 1
else
    echo "No CloudWatch alarms are currently in ALARM"
fi
