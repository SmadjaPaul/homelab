#!/usr/bin/env bash
# List Cloudflare Zero Trust Access applications and optionally run terraform import + apply.
# Requires: TF_VAR_cloudflare_api_token (or CLOUDFLARE_API_TOKEN), jq
# Usage: export TF_VAR_cloudflare_api_token=xxx && ./scripts/list-import-access-apps.sh [--import] [--apply]
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ZONE_ID="${ZONE_ID:-bda8e2196f6b4f1684c6c9c06d996109}"
TOKEN="${TF_VAR_cloudflare_api_token:-$CLOUDFLARE_API_TOKEN}"
DO_IMPORT=false
DO_APPLY=false
for arg in "$@"; do
  case "$arg" in
    --import) DO_IMPORT=true ;;
    --apply) DO_APPLY=true ;;
  esac
done

if [[ -z "$TOKEN" ]]; then
  echo "Set TF_VAR_cloudflare_api_token or CLOUDFLARE_API_TOKEN"
  exit 1
fi
export TF_VAR_cloudflare_api_token="$TOKEN"

RESP=$(curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/access/apps")
if ! echo "$RESP" | jq -e '.success == true' >/dev/null 2>&1; then
  echo "API error: $(echo "$RESP" | jq -r '.errors[]?.message // .')"
  exit 1
fi

declare -A IMPORTS
while IFS='|' read -r domain id; do
  case "$domain" in
    omni.smadja.dev) key=omni ;;
    llm.smadja.dev) key=litellm ;;
    openclaw.smadja.dev) key=openclaw ;;
    grafana.smadja.dev) key=grafana ;;
    argocd.smadja.dev) key=argocd ;;
    prometheus.smadja.dev) key=prometheus ;;
    alerts.smadja.dev) key=alertmanager ;;
    proxmox.smadja.dev) key=proxmox ;;
    *) continue ;;
  esac
  IMPORTS[$key]="$ZONE_ID/$id"
done < <(echo "$RESP" | jq -r '.result[] | "\(.domain)|\(.id)"')

if [[ "$DO_IMPORT" != true && "$DO_APPLY" != true ]]; then
  for key in "${!IMPORTS[@]}"; do
    echo "terraform import 'cloudflare_zero_trust_access_application.internal_services[\"$key\"]' ${IMPORTS[$key]}"
  done
  echo ""
  echo "To run imports: $0 --import"
  echo "Then apply: $0 --apply  (or terraform apply -var=enable_zone_settings=false)"
  exit 0
fi

cd "$ROOT_DIR"
if [[ "$DO_IMPORT" == true ]]; then
  for key in "${!IMPORTS[@]}"; do
    echo "Importing $key..."
    terraform import -input=false "cloudflare_zero_trust_access_application.internal_services[\"$key\"]" "${IMPORTS[$key]}" || true
  done
fi
if [[ "$DO_APPLY" == true ]]; then
  terraform apply -var=enable_zone_settings=false -auto-approve -input=false
fi
