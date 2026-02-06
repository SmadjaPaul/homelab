#!/bin/bash
# Script to link recovery flow to default authentication flow in Authentik
# This updates the identification stage in the default-authentication-flow
# to use our recovery flow, making the "Forgot password?" link appear on the login page.
#
# Usage:
#   ./scripts/link-recovery-flow.sh <AUTHENTIK_URL> <AUTHENTIK_TOKEN>
#
# Example:
#   ./scripts/link-recovery-flow.sh https://auth.smadja.dev $(cat ~/.authentik-token)

set -euo pipefail

AUTHENTIK_URL="${1:-}"
AUTHENTIK_TOKEN="${2:-}"

if [[ -z "$AUTHENTIK_URL" || -z "$AUTHENTIK_TOKEN" ]]; then
  echo "Usage: $0 <AUTHENTIK_URL> <AUTHENTIK_TOKEN>"
  echo "Example: $0 https://auth.smadja.dev \$(cat ~/.authentik-token)"
  exit 1
fi

# Remove trailing slash from URL
AUTHENTIK_URL="${AUTHENTIK_URL%/}"

echo "🔗 Linking recovery flow to default authentication flow..."
echo "Authentik URL: $AUTHENTIK_URL"

# Get the default authentication flow
echo "1️⃣ Finding default authentication flow..."
AUTH_FLOW_RESPONSE=$(curl -s -X GET \
  -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
  -H "Content-Type: application/json" \
  "$AUTHENTIK_URL/api/v3/flows/flows/?slug=default-authentication-flow")

AUTH_FLOW_ID=$(echo "$AUTH_FLOW_RESPONSE" | jq -r '.results[0].pk // empty')

if [[ -z "$AUTH_FLOW_ID" || "$AUTH_FLOW_ID" == "null" ]]; then
  echo "❌ Error: Could not find default-authentication-flow"
  exit 1
fi

echo "   Found flow ID: $AUTH_FLOW_ID"

# Get the identification stage with recovery flow
echo "2️⃣ Finding identification stage with recovery flow..."
IDENT_STAGE_RESPONSE=$(curl -s -X GET \
  -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
  -H "Content-Type: application/json" \
  "$AUTHENTIK_URL/api/v3/stages/identification/?name=default-authentication-identification-with-recovery")

IDENT_STAGE_ID=$(echo "$IDENT_STAGE_RESPONSE" | jq -r '.results[0].pk // empty')

if [[ -z "$IDENT_STAGE_ID" || "$IDENT_STAGE_ID" == "null" ]]; then
  echo "❌ Error: Could not find identification stage 'default-authentication-identification-with-recovery'"
  echo "   Make sure you've applied the Terraform configuration first:"
  echo "   cd terraform/authentik && terraform apply"
  exit 1
fi

echo "   Found stage ID: $IDENT_STAGE_ID"

# Get the flow stage bindings for the authentication flow
echo "3️⃣ Finding identification stage binding in authentication flow..."
BINDINGS_RESPONSE=$(curl -s -X GET \
  -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
  -H "Content-Type: application/json" \
  "$AUTHENTIK_URL/api/v3/flows/bindings/?target=$AUTH_FLOW_ID")

# Find the binding that uses an identification stage
# We'll look for bindings where the stage is an identification stage
IDENT_BINDING_ID=$(echo "$BINDINGS_RESPONSE" | jq -r '.results[] | select(.stage__type == "authentik.stages.identification.StageIdentification") | .pk' | head -1)

if [[ -z "$IDENT_BINDING_ID" || "$IDENT_BINDING_ID" == "null" ]]; then
  echo "❌ Error: Could not find identification stage binding in authentication flow"
  exit 1
fi

echo "   Found binding ID: $IDENT_BINDING_ID"

# Update the binding to use our new identification stage
echo "4️⃣ Updating binding to use identification stage with recovery flow..."
UPDATE_RESPONSE=$(curl -s -X PATCH \
  -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"stage\": $IDENT_STAGE_ID}" \
  "$AUTHENTIK_URL/api/v3/flows/bindings/$IDENT_BINDING_ID/")

if echo "$UPDATE_RESPONSE" | jq -e '.pk' > /dev/null 2>&1; then
  echo "✅ Successfully linked recovery flow to authentication flow!"
  echo ""
  echo "The 'Forgot username or password?' link should now appear on the login page."
else
  echo "❌ Error updating binding:"
  echo "$UPDATE_RESPONSE" | jq '.'
  exit 1
fi
