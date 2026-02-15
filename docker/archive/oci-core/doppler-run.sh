#!/bin/bash
# Doppler injection wrapper for docker-compose
# Usage: ./doppler-run.sh [docker-compose-args]

set -e

# Check if Doppler token is available
if [ -z "$DOPPLER_TOKEN" ]; then
    echo "❌ Error: DOPPLER_TOKEN environment variable is not set"
    echo "Please set it with: export DOPPLER_TOKEN=dp.st.prd.xxxx"
    exit 1
fi

# Download secrets from Doppler to a temp file
echo "📥 Fetching secrets from Doppler..."
TMP_ENV=$(mktemp)
trap 'rm -f "$TMP_ENV"' EXIT

if ! doppler secrets download --project infrastructure --config prd --format env --out-file "$TMP_ENV" 2>/dev/null; then
    echo "❌ Failed to fetch secrets from Doppler"
    exit 1
fi

echo "✅ Secrets fetched successfully"

# Run docker-compose with the env file
echo "🚀 Starting docker-compose..."
docker compose --env-file "$TMP_ENV" "$@"
