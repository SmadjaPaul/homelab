# =============================================================================
# One-time import: adopt existing Cloudflare resources into module state
# After a failed apply (migration not run in CI), the tunnel and Access apps
# still exist in Cloudflare; Terraform tries to create them again → already_exists.
# Run: terraform plan then apply (with cloudflare_account_id in tfvars).
# Once imported, these blocks have no effect on subsequent runs.
#
# IMPORTANT: This file references module.tunnel[0] and module.access[0].
# They exist only when enable_tunnel = true. If you run with enable_tunnel = false,
# remove or rename this file to avoid "resource not in configuration" errors.
# After the first successful apply with imports, you can remove this file.
# =============================================================================

# Note: When using an existing tunnel (tunnel_id in tfvars), the tunnel resource
# uses count = 0, so no import is needed. The tunnel_id is passed directly via variable.

# Access applications: if apply fails with application_already_exists, add back
# import blocks (see git history) or run: terraform import 'module.access[0].cloudflare_zero_trust_access_application.internal_services["<name>"]' <account_id>/<app_uuid>
