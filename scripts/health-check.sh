#!/usr/bin/env bash
#
# health-check.sh
# Hits the backend health endpoint (directly, or through CloudFront) and
# reports success/failure. Useful right after a deploy, or as a CI gate.
#
# Usage:
#   ./scripts/health-check.sh https://<cloudfront-domain>   # checks /api/health (CloudFront strips /api)
#   ./scripts/health-check.sh http://<alb-dns-name>          # checks /health directly (no /api prefix)
#
set -euo pipefail

BASE_URL="${1:?Usage: $0 <base-url>}"
HEALTH_PATH="${4:-/health}"
ENDPOINT="${BASE_URL%/}${HEALTH_PATH}"
MAX_ATTEMPTS="${2:-5}"
SLEEP_SECONDS="${3:-10}"

echo ">> Checking $ENDPOINT ..."

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$ENDPOINT" || echo "000")

  if [ "$STATUS" = "200" ]; then
    echo ">> Healthy (attempt $attempt/$MAX_ATTEMPTS) — HTTP $STATUS"
    exit 0
  fi

  echo ">> Attempt $attempt/$MAX_ATTEMPTS failed — HTTP $STATUS. Retrying in ${SLEEP_SECONDS}s..."
  sleep "$SLEEP_SECONDS"
done

echo "!! Health check failed after $MAX_ATTEMPTS attempts."
exit 1
