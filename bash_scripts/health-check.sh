#!/usr/bin/env bash
set -uo pipefail

DEPLOYMENT="meridian-web-application"
NAMESPACE="default"
AWS_REGION="us-east-1"
ALB_NAME="meridian-web-application-alb"
FAILURES=0

pass() { echo "PASS: $1"; }
fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

# Check Kubernetes API reachability.
# /version requires authentication but no namespace permissions.
if kubectl get --raw /version >/dev/null 2>&1; then
  pass "kubectl can reach the cluster"
else
  fail "kubectl cannot reach the cluster"
fi

# Check application pods.
POD_LINES=$(kubectl get pods \
  -l "app=$DEPLOYMENT" \
  -n "$NAMESPACE" \
  --no-headers 2>/dev/null)

if [ -z "$POD_LINES" ]; then
  fail "no pods found for app=$DEPLOYMENT in namespace $NAMESPACE"
else
  NOT_READY=$(echo "$POD_LINES" | awk '
    {
      split($2, r, "/")
    }
    $3 != "Running" || r[1] != r[2] {
      print
    }
  ')

  if [ -z "$NOT_READY" ]; then
    POD_COUNT=$(echo "$POD_LINES" | wc -l | tr -d ' ')
    pass "all $POD_COUNT pod(s) are Running and Ready"
  else
    fail "pods not Running/Ready:"$'\n'"$NOT_READY"
  fi
fi

# Retrieve the ALB hostname using AWS CLI.
# The AWS Load Balancer Controller provisions the ALB.
ALB_DNS_NAME=$(aws elbv2 describe-load-balancers \
  --region "$AWS_REGION" \
  --query "LoadBalancers[?LoadBalancerName=='$ALB_NAME'].DNSName | [0]" \
  --output text 2>/dev/null)

if [ -z "$ALB_DNS_NAME" ] || [ "$ALB_DNS_NAME" = "None" ]; then
  fail "could not find ALB $ALB_NAME"
else
  pass "ALB hostname found: $ALB_DNS_NAME"

  # Check application health through the ALB.
  STATUS=$(curl -s -o /dev/null -w '%{http_code}' \
    --max-time 10 \
    "http://$ALB_DNS_NAME/health")

  if [ "$STATUS" = "200" ]; then
    pass "/health returned 200"
  else
    fail "/health returned $STATUS"
  fi
fi

# Check CloudWatch alarms.
ALARMS_IN_ALARM=$(aws cloudwatch describe-alarms \
  --region "$AWS_REGION" \
  --state-value ALARM \
  --query 'MetricAlarms[].AlarmName' \
  --output text 2>/dev/null)

if [ $? -ne 0 ]; then
  fail "could not query CloudWatch alarm state"
elif [ -z "$ALARMS_IN_ALARM" ] || [ "$ALARMS_IN_ALARM" = "None" ]; then
  pass "no CloudWatch alarms in ALARM state"
else
  fail "alarms in ALARM state: $ALARMS_IN_ALARM"
fi

echo

if [ "$FAILURES" -eq 0 ]; then
  echo "health check passed"
  exit 0
else
  echo "health check failed: $FAILURES check(s) failed"
  exit 1
fi
