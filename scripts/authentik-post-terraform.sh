#!/usr/bin/env bash
# =============================================================================
# Authentik post-Terraform configuration (API)
# =============================================================================
# Runs after terraform/authentik apply to automate steps that Terraform cannot
# do (or that require the API). Can be run locally or in CI.
#
# Usage:
#   ./scripts/authentik-post-terraform.sh <AUTHENTIK_URL> <AUTHENTIK_TOKEN> [admin_user_email]
#
# If admin_user_email is provided, that user is added to the "admin" group.
# Requires: curl, jq
#
# CI: Set AUTHENTIK_URL, AUTHENTIK_TOKEN (and optionally ADMIN_USER_EMAIL) as
#     secrets or vars, then call this script after terraform apply.
# =============================================================================

set -euo pipefail

AUTHENTIK_URL="${1:-${AUTHENTIK_URL:-}}"
AUTHENTIK_TOKEN="${2:-${AUTHENTIK_TOKEN:-}}"
ADMIN_USER_EMAIL="${3:-${ADMIN_USER_EMAIL:-}}"

if [[ -z "$AUTHENTIK_URL" || -z "$AUTHENTIK_TOKEN" ]]; then
  echo "Usage: $0 <AUTHENTIK_URL> <AUTHENTIK_TOKEN> [admin_user_email]"
  echo "   or set AUTHENTIK_URL, AUTHENTIK_TOKEN (and optionally ADMIN_USER_EMAIL)"
  exit 1
fi

AUTHENTIK_URL="${AUTHENTIK_URL%/}"
API="$AUTHENTIK_URL/api/v3"
AUTH_HEADER="Authorization: Bearer $AUTHENTIK_TOKEN"

echo "=== Authentik post-Terraform configuration ==="
echo "URL: $AUTHENTIK_URL"
echo ""

# -----------------------------------------------------------------------------
# 1. Link recovery flow to default authentication flow
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$SCRIPT_DIR/link-recovery-flow.sh" ]]; then
  echo "1️⃣ Linking recovery flow to login flow..."
  if "$SCRIPT_DIR/link-recovery-flow.sh" "$AUTHENTIK_URL" "$AUTHENTIK_TOKEN"; then
    echo "   ✅ Recovery flow linked."
  else
    echo "   ⚠️  Link recovery flow failed (may already be linked)."
  fi
else
  echo "1️⃣ Skipping recovery flow link (link-recovery-flow.sh not executable)."
fi
echo ""

# -----------------------------------------------------------------------------
# 2. Bind admin group to Omni application
# -----------------------------------------------------------------------------
# Terraform already binds the "admin-group-only" policy to Omni, so access is
# already restricted. This step adds the group binding so Omni appears for
# admin users in "My applications" and matches UI expectations.
echo "2️⃣ Binding admin group to Omni application..."

OMNI_APP=$(curl -s -X GET -H "$AUTH_HEADER" -H "Content-Type: application/json" \
  "$API/core/applications/?slug=omni" | jq -r '.results[0] // empty')
if [[ -z "$OMNI_APP" || "$OMNI_APP" == "null" ]]; then
  OMNI_APP=$(curl -s -X GET -H "$AUTH_HEADER" -H "Content-Type: application/json" \
    "$API/applications/all/" | jq -r '[.results[]? | select(.slug == "omni")][0] // empty')
fi

ADMIN_GROUP=$(curl -s -X GET -H "$AUTH_HEADER" -H "Content-Type: application/json" \
  "$API/core/groups/?name=admin" | jq -r '.results[0] // empty')

if [[ -n "$OMNI_APP" && "$OMNI_APP" != "null" && -n "$ADMIN_GROUP" && "$ADMIN_GROUP" != "null" ]]; then
  OMNI_PK=$(echo "$OMNI_APP" | jq -r '.pk')
  ADMIN_GROUP_PK=$(echo "$ADMIN_GROUP" | jq -r '.pk')

  # Try: policy/bindings with target=application, group=admin (group binding to app)
  EXISTING=$(curl -s -X GET -H "$AUTH_HEADER" -H "Content-Type: application/json" \
    "$API/policy/bindings/?target=$OMNI_PK" | jq -r ".results[]? | select(.group == $ADMIN_GROUP_PK) | .pk" | head -1)
  if [[ -z "$EXISTING" || "$EXISTING" == "null" ]]; then
    BIND_RESP=$(curl -s -w "\n%{http_code}" -X POST -H "$AUTH_HEADER" -H "Content-Type: application/json" \
      -d "{\"target\": \"$OMNI_PK\", \"group\": $ADMIN_GROUP_PK, \"order\": 0, \"enabled\": true}" \
      "$API/policy/bindings/")
    HTTP_CODE=$(echo "$BIND_RESP" | tail -1)
    if [[ "$HTTP_CODE" == "201" || "$HTTP_CODE" == "200" ]]; then
      echo "   ✅ Admin group bound to Omni."
    else
      echo "   ⚠️  Group binding failed (HTTP $HTTP_CODE). Access is already restricted by Terraform policy; bind group in UI if needed: Applications → Omni → Policy/Group/User Bindings → Add group 'admin'."
    fi
  else
    echo "   ✅ Admin group already bound to Omni."
  fi
else
  echo "   ⚠️  Omni app or admin group not found. Run Terraform apply first. Access to Omni is still restricted by Terraform (admin-only policy)."
fi
echo ""

# -----------------------------------------------------------------------------
# 3. Add user to admin group (if email provided)
# -----------------------------------------------------------------------------
if [[ -n "$ADMIN_USER_EMAIL" ]]; then
  echo "3️⃣ Adding user $ADMIN_USER_EMAIL to admin group..."

  USER_JSON=$(curl -s -X GET -H "$AUTH_HEADER" -H "Content-Type: application/json" \
    "$API/core/users/?email=$ADMIN_USER_EMAIL" | jq -r '.results[0] // empty')
  if [[ -n "$USER_JSON" && "$USER_JSON" != "null" ]]; then
    USER_PK=$(echo "$USER_JSON" | jq -r '.pk')
    ADMIN_GROUP_PK=$(echo "$ADMIN_GROUP" | jq -r '.pk')
    ADD_RESP=$(curl -s -w "\n%{http_code}" -X POST -H "$AUTH_HEADER" -H "Content-Type: application/json" \
      -d "{\"pk\": $USER_PK}" \
      "$API/core/groups/$ADMIN_GROUP_PK/add_user/")
    HTTP_CODE=$(echo "$ADD_RESP" | tail -1)
    if [[ "$HTTP_CODE" == "204" || "$HTTP_CODE" == "200" ]]; then
      echo "   ✅ User added to admin group."
    else
      echo "   ⚠️  Add user failed (HTTP $HTTP_CODE). User may already be in group."
    fi
  else
    echo "   ⚠️  User with email $ADMIN_USER_EMAIL not found."
  fi
else
  echo "3️⃣ Skipping add user to admin (no ADMIN_USER_EMAIL)."
fi
echo ""

# -----------------------------------------------------------------------------
# 4. Disable enrollment flow (allow_user_to_start = false)
# -----------------------------------------------------------------------------
echo "4️⃣ Disabling public self-registration (enrollment flow)..."

ENROLLMENT=$(curl -s -X GET -H "$AUTH_HEADER" -H "Content-Type: application/json" \
  "$API/flows/flows/?slug=default-enrollment-flow" | jq -r '.results[0] // empty')
if [[ -n "$ENROLLMENT" && "$ENROLLMENT" != "null" ]]; then
  FLOW_PK=$(echo "$ENROLLMENT" | jq -r '.pk')
  PATCH_RESP=$(curl -s -w "\n%{http_code}" -X PATCH -H "$AUTH_HEADER" -H "Content-Type: application/json" \
    -d '{"allow_user_to_start": false}' \
    "$API/flows/flows/$FLOW_PK/")
  HTTP_CODE=$(echo "$PATCH_RESP" | tail -1)
  if [[ "$HTTP_CODE" == "200" ]]; then
    echo "   ✅ Enrollment flow: public start disabled."
  else
    echo "   ⚠️  Failed to disable (HTTP $HTTP_CODE). Disable manually: Flows → default-enrollment-flow → Settings → Uncheck 'Allow user to start this flow'."
  fi
else
  echo "   ⚠️  default-enrollment-flow not found."
fi
echo ""

echo "=== Post-Terraform configuration done ==="
