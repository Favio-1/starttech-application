#!/usr/bin/env bash
#
# rollback.sh
# Rolls the backend-api deployment back to its previous revision.
#
# Usage:
#   ./scripts/rollback.sh <eks-cluster-name>
#
set -euo pipefail

CLUSTER_NAME="${1:?Usage: $0 <eks-cluster-name>}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo ">> Updating kubeconfig for cluster $CLUSTER_NAME ..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

echo ">> Current rollout history:"
kubectl rollout history deployment/backend-api

echo ">> Rolling back to the previous revision..."
kubectl rollout undo deployment/backend-api

echo ">> Waiting for rollback to complete..."
kubectl rollout status deployment/backend-api --timeout=180s

echo ">> Rollback complete."
