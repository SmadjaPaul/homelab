# Configuration automatique du provider OAuth2 ci-automation
# Configure les grant types et l'OAuth Source via l'API Authentik pour éviter le drift
# Ces configurations ne sont pas directement supportées par le provider Terraform Authentik

resource "null_resource" "configure_ci_automation_provider" {
  # Dépend de la création du provider et de l'OAuth Source
  depends_on = [
    authentik_provider_oauth2.ci_automation,
    authentik_source_oauth.ci_automation_jwks
  ]

  # Re-run si le provider ou la source change
  triggers = {
    provider_id   = authentik_provider_oauth2.ci_automation.id
    source_id     = authentik_source_oauth.ci_automation_jwks.id
    authentik_url = var.authentik_url != "" ? var.authentik_url : "https://auth.smadja.dev"
  }

  # Provisioner local-exec pour configurer via l'API
  provisioner "local-exec" {
    command = <<-EOT
      set -e

      # Variables depuis l'environnement shell (doivent être exportées avant terraform apply)
      PROVIDER_ID="${authentik_provider_oauth2.ci_automation.id}"
      SOURCE_ID="${authentik_source_oauth.ci_automation_jwks.id}"

      # Lire depuis l'environnement shell (exporté via source .env ou export)
      AUTHENTIK_URL="$${AUTHENTIK_URL:-https://auth.smadja.dev}"

      if [ -z "$${AUTHENTIK_TOKEN}" ]; then
        echo "Error: AUTHENTIK_TOKEN not set in environment."
        echo "Please run: source .env && terraform apply"
        echo "Or export AUTHENTIK_TOKEN before running terraform apply"
        exit 1
      fi

      echo "Configuring Authentik OAuth2 provider ci-automation..."
      echo "Provider ID: $${PROVIDER_ID}"
      echo "OAuth Source ID: $${SOURCE_ID}"

      # Step 1: Enable Client Credentials grant type
      echo "Step 1: Enabling Client Credentials grant type..."
      PROVIDER_CONFIG=$(curl -s -X GET \
        "$${AUTHENTIK_URL}/api/v3/providers/oauth2/$${PROVIDER_ID}/" \
        -H "Authorization: Bearer $${AUTHENTIK_TOKEN}" \
        -H "Content-Type: application/json")

      CURRENT_GRANTS=$(echo "$${PROVIDER_CONFIG}" | jq -r '.grant_types // []')

      if echo "$${CURRENT_GRANTS}" | jq -e 'contains(["client_credentials"])' > /dev/null 2>&1; then
        echo "✓ Client credentials grant type already enabled"
      else
        UPDATED_GRANTS=$(echo "$${CURRENT_GRANTS}" | jq '. + ["client_credentials"] | unique')

        UPDATE_RESPONSE=$(curl -s -X PATCH \
          "$${AUTHENTIK_URL}/api/v3/providers/oauth2/$${PROVIDER_ID}/" \
          -H "Authorization: Bearer $${AUTHENTIK_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "{\"grant_types\": $${UPDATED_GRANTS}}")

        if echo "$${UPDATE_RESPONSE}" | jq -e '.error' > /dev/null 2>&1; then
          ERROR=$(echo "$${UPDATE_RESPONSE}" | jq -r '.error // "unknown"')
          echo "Warning: Failed to enable client_credentials: $${ERROR}"
          echo "You may need to enable it manually in Authentik UI"
        else
          echo "✓ Client credentials grant type enabled"
        fi
      fi

      # Step 2: Link OAuth Source for private_key_jwt
      echo "Step 2: Linking OAuth Source for private_key_jwt..."

      # Try different field names that Authentik might use
      # Common field names: jwt_issuer, oauth_source, jwt_verification
      UPDATE_RESPONSE=$(curl -s -X PATCH \
        "$${AUTHENTIK_URL}/api/v3/providers/oauth2/$${PROVIDER_ID}/" \
        -H "Authorization: Bearer $${AUTHENTIK_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"jwt_issuer\": \"$${SOURCE_ID}\"}")

      if echo "$${UPDATE_RESPONSE}" | jq -e '.error' > /dev/null 2>&1; then
        # Try alternative field name
        UPDATE_RESPONSE=$(curl -s -X PATCH \
          "$${AUTHENTIK_URL}/api/v3/providers/oauth2/$${PROVIDER_ID}/" \
          -H "Authorization: Bearer $${AUTHENTIK_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "{\"oauth_source\": \"$${SOURCE_ID}\"}")
      fi

      if echo "$${UPDATE_RESPONSE}" | jq -e '.error' > /dev/null 2>&1; then
        ERROR=$(echo "$${UPDATE_RESPONSE}" | jq -r '.error // "unknown"')
        echo "Warning: Failed to link OAuth Source: $${ERROR}"
        echo "You may need to configure it manually in Authentik UI:"
        echo "Applications → Providers → ci-automation → Edit → OAuth Source → Select 'ci-automation-jwks'"
      else
        echo "✓ OAuth Source linked to provider"
      fi

      echo "✓ Provider configuration completed"
    EOT

    # Le script lit directement depuis l'environnement shell
    # Les variables AUTHENTIK_URL et AUTHENTIK_TOKEN doivent être exportées avant terraform apply
    # Exemple: source .env && terraform apply
  }

  # Destroy provisioner pour nettoyer (optionnel)
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Note: Provider configuration will remain in Authentik after destroy."
      echo "To fully remove, delete the provider manually in Authentik UI or via API."
    EOT
  }
}
