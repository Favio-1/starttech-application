#!/usr/bin/env bash
#
# deploy-backend.sh
# Builds, tags, pushes the backend image to ECR, then applies k8s manifests
# and waits for the rollout.
#
# Usage:
#   ./scripts/deploy-backend.sh <ecr-repository-url> <eks-cluster-name>
#
set -euo pipefail

ECR_REPO_URL="${1:?Usage: $0 <ecr-repository-url> <eks-cluster-name>}"
CLUSTER_NAME="${2:?Usage: $0 <ecr-repository-url> <eks-cluster-name>}"
AWS_REGION="${AWS_REGION:-us-east-1}"

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_TAG="$(git -C "$APP_ROOT" rev-parse --short HEAD)"

echo ">> Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REPO_URL"

echo ">> Building image $ECR_REPO_URL:$IMAGE_TAG ..."
docker build -t "$ECR_REPO_URL:$IMAGE_TAG" "$APP_ROOT/backend"

echo ">> Pushing image..."
docker push "$ECR_REPO_URL:$IMAGE_TAG"

echo ">> Updating deployment manifest with new image tag..."
sed -i.bak "s|<ECR_REPOSITORY_URL>:.*|$ECR_REPO_URL:$IMAGE_TAG|" "$APP_ROOT/k8s/deployment.yaml"
rm -f "$APP_ROOT/k8s/deployment.yaml.bak"

echo ">> Updating kubeconfig for cluster $CLUSTER_NAME ..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

echo ">> Applying manifests..."
kubectl apply -f "$APP_ROOT/k8s/"

echo ">> Waiting for rollout..."
kubectl rollout status deployment/backend-api --timeout=180s

echo ">> Backend deployed: $ECR_REPO_URL:$IMAGE_TAG"
