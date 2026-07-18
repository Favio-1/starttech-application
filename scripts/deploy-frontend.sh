#!/usr/bin/env bash
#
# deploy-frontend.sh
# Builds the React app and uploads it to S3, then invalidates CloudFront.
# Requires: AWS CLI configured, node/npm installed.
#
# Usage:
#   ./scripts/deploy-frontend.sh <s3-bucket-name> <cloudfront-distribution-id>
#
set -euo pipefail

BUCKET_NAME="${1:?Usage: $0 <s3-bucket-name> <cloudfront-distribution-id>}"
DISTRIBUTION_ID="${2:?Usage: $0 <s3-bucket-name> <cloudfront-distribution-id>}"

FRONTEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../frontend" && pwd)"
cd "$FRONTEND_DIR"

echo ">> Installing dependencies..."
npm ci

echo ">> Building..."
npm run build

echo ">> Syncing build/ to s3://$BUCKET_NAME ..."
aws s3 sync build/ "s3://$BUCKET_NAME" --delete

echo ">> Invalidating CloudFront distribution $DISTRIBUTION_ID ..."
aws cloudfront create-invalidation \
  --distribution-id "$DISTRIBUTION_ID" \
  --paths "/*"

echo ">> Frontend deployed."
