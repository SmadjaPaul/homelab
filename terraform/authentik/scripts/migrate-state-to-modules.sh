#!/usr/bin/env bash
# Migrate Terraform state from root resources to module addresses.
# Run from repo root: bash terraform/authentik/scripts/migrate-state-to-modules.sh
# Requires: terraform state mv (run from terraform/authentik).

set -e
cd "$(dirname "$0")/.."

echo "Migrating Authentik state to module addresses..."

# Groups
terraform state mv -lock=false 'authentik_group.admin' 'module.groups.authentik_group.admin' 2>/dev/null || true
terraform state mv -lock=false 'authentik_group.family_validated' 'module.groups.authentik_group.family_validated' 2>/dev/null || true

# Policies
terraform state mv -lock=false 'authentik_policy_expression.admin_only' 'module.policies.authentik_policy_expression.admin_only' 2>/dev/null || true
terraform state mv -lock=false 'authentik_policy_expression.family_validated_only' 'module.policies.authentik_policy_expression.family_validated_only' 2>/dev/null || true
terraform state mv -lock=false 'authentik_policy_expression.admin_and_validated' 'module.policies.authentik_policy_expression.admin_and_validated' 2>/dev/null || true
terraform state mv -lock=false 'authentik_policy_expression.block_public_enrollment' 'module.policies.authentik_policy_expression.block_public_enrollment' 2>/dev/null || true

# Flows
terraform state mv -lock=false 'authentik_flow.recovery' 'module.flows.authentik_flow.recovery' 2>/dev/null || true
terraform state mv -lock=false 'authentik_stage_email.recovery_email' 'module.flows.authentik_stage_email.recovery_email' 2>/dev/null || true
terraform state mv -lock=false 'authentik_stage_prompt_field.recovery_password' 'module.flows.authentik_stage_prompt_field.recovery_password' 2>/dev/null || true
terraform state mv -lock=false 'authentik_stage_prompt_field.recovery_password_repeat' 'module.flows.authentik_stage_prompt_field.recovery_password_repeat' 2>/dev/null || true
terraform state mv -lock=false 'authentik_stage_prompt.recovery_prompt_password' 'module.flows.authentik_stage_prompt.recovery_prompt_password' 2>/dev/null || true
terraform state mv -lock=false 'authentik_stage_identification.recovery_identification' 'module.flows.authentik_stage_identification.recovery_identification' 2>/dev/null || true
terraform state mv -lock=false 'authentik_stage_user_write.recovery_user_write' 'module.flows.authentik_stage_user_write.recovery_user_write' 2>/dev/null || true
terraform state mv -lock=false 'authentik_stage_user_login.recovery_user_login' 'module.flows.authentik_stage_user_login.recovery_user_login' 2>/dev/null || true
terraform state mv -lock=false 'authentik_policy_expression.recovery_skip_if_restored' 'module.flows.authentik_policy_expression.recovery_skip_if_restored' 2>/dev/null || true
terraform state mv -lock=false 'authentik_flow_stage_binding.recovery_identification' 'module.flows.authentik_flow_stage_binding.recovery_identification' 2>/dev/null || true
terraform state mv -lock=false 'authentik_flow_stage_binding.recovery_email' 'module.flows.authentik_flow_stage_binding.recovery_email' 2>/dev/null || true
terraform state mv -lock=false 'authentik_flow_stage_binding.recovery_prompt_password' 'module.flows.authentik_flow_stage_binding.recovery_prompt_password' 2>/dev/null || true
terraform state mv -lock=false 'authentik_flow_stage_binding.recovery_user_write' 'module.flows.authentik_flow_stage_binding.recovery_user_write' 2>/dev/null || true
terraform state mv -lock=false 'authentik_flow_stage_binding.recovery_user_login' 'module.flows.authentik_flow_stage_binding.recovery_user_login' 2>/dev/null || true
terraform state mv -lock=false 'authentik_policy_binding.recovery_skip_identification' 'module.flows.authentik_policy_binding.recovery_skip_identification' 2>/dev/null || true
terraform state mv -lock=false 'authentik_stage_identification.default_auth_with_recovery' 'module.flows.authentik_stage_identification.default_auth_with_recovery' 2>/dev/null || true
terraform state mv -lock=false 'authentik_policy_password.strong' 'module.flows.authentik_policy_password.strong' 2>/dev/null || true
terraform state mv -lock=false 'authentik_policy_binding.recovery_password_policy' 'module.flows.authentik_policy_binding.recovery_password_policy' 2>/dev/null || true
terraform state mv -lock=false 'authentik_policy_reputation.login' 'module.flows.authentik_policy_reputation.login' 2>/dev/null || true
terraform state mv -lock=false 'authentik_policy_binding.login_reputation' 'module.flows.authentik_policy_binding.login_reputation' 2>/dev/null || true

# Apps (only resources that exist in state: omni, cloudflare_access, outpost)
terraform state mv -lock=false 'authentik_provider_proxy.omni' 'module.apps.authentik_provider_proxy.omni' 2>/dev/null || true
terraform state mv -lock=false 'authentik_application.omni' 'module.apps.authentik_application.omni' 2>/dev/null || true
terraform state mv -lock=false 'authentik_outpost.proxy_forward_auth' 'module.apps.authentik_outpost.proxy_forward_auth' 2>/dev/null || true
terraform state mv -lock=false 'authentik_provider_oauth2.cloudflare_access' 'module.apps.authentik_provider_oauth2.cloudflare_access' 2>/dev/null || true
terraform state mv -lock=false 'authentik_application.cloudflare_access' 'module.apps.authentik_application.cloudflare_access' 2>/dev/null || true

# Bindings (only omni_admin_policy is in state)
terraform state mv -lock=false 'authentik_policy_binding.omni_admin_policy' 'module.bindings.authentik_policy_binding.omni_admin_policy' 2>/dev/null || true

echo "Done. Run 'terraform plan' to verify (expect: create litellm/openclaw/openclaw_oidc if not in state)."
