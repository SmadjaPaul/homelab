#!/usr/bin/env bash
# Affiche l'UUID d'un utilisateur Authentik (pour terraform import).
# Accepte soit un username soit l'ID numérique (pk) visible dans l'URL admin.
#
# Usage: AUTHENTIK_TOKEN=<token> ./scripts/get-user-uuid.sh <username|pk>
# Exemples:
#   AUTHENTIK_TOKEN=xxx ./scripts/get-user-uuid.sh smadja-paul
#   AUTHENTIK_TOKEN=xxx ./scripts/get-user-uuid.sh 5
set -e
BASE_URL="${AUTHENTIK_URL:-https://auth.smadja.dev}"
TOKEN="${AUTHENTIK_TOKEN:-}"
ARG="${1:-}"

if [[ -z "$TOKEN" ]]; then
  echo "Usage: AUTHENTIK_TOKEN=<token> $0 <username|pk>"
  exit 1
fi
if [[ -z "$ARG" ]]; then
  echo "Usage: AUTHENTIK_TOKEN=<token> $0 <username|pk>"
  echo "Exemples: $0 smadja-paul   ou   $0 5  (pk vu dans l'URL .../users/5)"
  exit 1
fi

if [[ "$ARG" =~ ^[0-9]+$ ]]; then
  # Argument numérique = pk (ID dans l'URL admin)
  RESP=$(curl -sS -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v3/core/users/$ARG/")
  UUID=$(echo "$RESP" | jq -r '.uuid // empty')
else
  # Argument = username
  RESP=$(curl -sS -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v3/core/users/?username=$ARG")
  UUID=$(echo "$RESP" | jq -r '.results[0].uuid // empty')
fi

if [[ -z "$UUID" ]]; then
  echo "Utilisateur '$ARG' introuvable ou token sans droits."
  exit 1
fi

echo "$UUID"
