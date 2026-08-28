#!/bin/bash
# Identifies any pods not in Running state and deletes them,
# letting Kubernetes replace them. Logs what it did and when.

RESULT=$(kubectl get pods --no-headers -o custom-columns=":metadata.name,:status.phase")

while read -r POD STATUS; do
    if [ "$STATUS" != "Running" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Pod $POD is $STATUS. Deleting..."
        kubectl delete pod "$POD"
    fi
done <<< "$RESULT"