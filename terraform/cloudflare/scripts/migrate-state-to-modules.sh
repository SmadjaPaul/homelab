#!/usr/bin/env bash
# Migrate Terraform state from pre-module resource addresses to module addresses.
# Run once after the refactor (dns/tunnel/access/security → modules) to avoid
# "36 to destroy, 23 to add". Execute from repo root with backend init'd:
#   cd terraform/cloudflare && terraform init -reconfigure
#   ../../scripts/migrate-state-to-modules.sh
# Or from terraform/cloudflare: ./scripts/migrate-state-to-modules.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CDIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$CDIR"

echo "Migrating Cloudflare state to module addresses (from $CDIR)..."

# DNS: single resources
for r in root www spf dmarc; do
  if terraform state show "cloudflare_record.$r" &>/dev/null; then
    terraform state mv "cloudflare_record.$r" "module.dns.cloudflare_record.$r" 2>/dev/null || true
    echo "  mv cloudflare_record.$r → module.dns"
  fi
done

# DNS: oci_mgmt (count=0 or 1), oci_nodes (count)
if terraform state show 'cloudflare_record.oci_mgmt[0]' &>/dev/null; then
  terraform state mv 'cloudflare_record.oci_mgmt[0]' 'module.dns.cloudflare_record.oci_mgmt[0]' 2>/dev/null || true
  echo "  mv cloudflare_record.oci_mgmt[0] → module.dns"
fi
for i in 0 1 2; do
  if terraform state show "cloudflare_record.oci_nodes[$i]" &>/dev/null; then
    terraform state mv "cloudflare_record.oci_nodes[$i]" "module.dns.cloudflare_record.oci_nodes[$i]" 2>/dev/null || true
    echo "  mv cloudflare_record.oci_nodes[$i] → module.dns"
  fi
done

# DNS: homelab_services (for_each) and tunnel_cname (for_each)
SERVICE_KEYS="alertmanager argocd authentik docs feedback grafana homepage litellm omni openclaw prometheus status proxmox"
for k in $SERVICE_KEYS; do
  if terraform state show "cloudflare_record.homelab_services[\"$k\"]" &>/dev/null; then
    terraform state mv "cloudflare_record.homelab_services[\"$k\"]" "module.dns.cloudflare_record.homelab_services[\"$k\"]" 2>/dev/null || true
    echo "  mv cloudflare_record.homelab_services[$k] → module.dns"
  fi
  if terraform state show "cloudflare_record.tunnel_cname[\"$k\"]" &>/dev/null; then
    terraform state mv "cloudflare_record.tunnel_cname[\"$k\"]" "module.dns.cloudflare_record.tunnel_cname[\"$k\"]" 2>/dev/null || true
    echo "  mv cloudflare_record.tunnel_cname[$k] → module.dns"
  fi
done

# Tunnel
if terraform state show 'cloudflare_zero_trust_tunnel_cloudflared.homelab[0]' &>/dev/null; then
  terraform state mv 'cloudflare_zero_trust_tunnel_cloudflared.homelab[0]' 'module.tunnel[0].cloudflare_zero_trust_tunnel_cloudflared.homelab' 2>/dev/null || true
  echo "  mv tunnel homelab → module.tunnel[0]"
fi
if terraform state show 'cloudflare_zero_trust_tunnel_cloudflared_config.homelab[0]' &>/dev/null; then
  terraform state mv 'cloudflare_zero_trust_tunnel_cloudflared_config.homelab[0]' 'module.tunnel[0].cloudflare_zero_trust_tunnel_cloudflared_config.homelab' 2>/dev/null || true
  echo "  mv tunnel config → module.tunnel[0]"
fi

# Access: IdP
if terraform state show 'cloudflare_zero_trust_access_identity_provider.authentik[0]' &>/dev/null; then
  terraform state mv 'cloudflare_zero_trust_access_identity_provider.authentik[0]' 'module.access[0].cloudflare_zero_trust_access_identity_provider.authentik[0]' 2>/dev/null || true
  echo "  mv IdP authentik → module.access[0]"
fi

# Access: applications and policies (internal services only)
INTERNAL_KEYS="alertmanager argocd grafana litellm omni openclaw prometheus proxmox"
for k in $INTERNAL_KEYS; do
  if terraform state show "cloudflare_zero_trust_access_application.internal_services[\"$k\"]" &>/dev/null; then
    terraform state mv "cloudflare_zero_trust_access_application.internal_services[\"$k\"]" "module.access[0].cloudflare_zero_trust_access_application.internal_services[\"$k\"]" 2>/dev/null || true
    echo "  mv access_application[$k] → module.access[0]"
  fi
  if terraform state show "cloudflare_zero_trust_access_policy.authentik_everyone[\"$k\"]" &>/dev/null; then
    terraform state mv "cloudflare_zero_trust_access_policy.authentik_everyone[\"$k\"]" "module.access[0].cloudflare_zero_trust_access_policy.authentik_everyone[\"$k\"]" 2>/dev/null || true
    echo "  mv policy authentik_everyone[$k] → module.access[0]"
  fi
  if terraform state show "cloudflare_zero_trust_access_policy.internal_allow[\"$k\"]" &>/dev/null; then
    terraform state mv "cloudflare_zero_trust_access_policy.internal_allow[\"$k\"]" "module.access[0].cloudflare_zero_trust_access_policy.internal_allow[\"$k\"]" 2>/dev/null || true
    echo "  mv policy internal_allow[$k] → module.access[0]"
  fi
done

# Security
if terraform state show 'cloudflare_zone_settings_override.security[0]' &>/dev/null; then
  terraform state mv 'cloudflare_zone_settings_override.security[0]' 'module.security.cloudflare_zone_settings_override.security[0]' 2>/dev/null || true
  echo "  mv zone_settings_override.security → module.security"
fi
if terraform state show 'cloudflare_ruleset.geo_restrict[0]' &>/dev/null; then
  terraform state mv 'cloudflare_ruleset.geo_restrict[0]' 'module.security.cloudflare_ruleset.geo_restrict[0]' 2>/dev/null || true
  echo "  mv ruleset.geo_restrict → module.security"
fi
if terraform state show 'cloudflare_ruleset.authentik_api_skip_challenge[0]' &>/dev/null; then
  terraform state mv 'cloudflare_ruleset.authentik_api_skip_challenge[0]' 'module.security.cloudflare_ruleset.authentik_api_skip_challenge[0]' 2>/dev/null || true
  echo "  mv ruleset.authentik_api_skip_challenge → module.security"
fi

echo "Done. Run: terraform plan"
echo "You should see 0 to add, 0 to change, 0 to destroy (or only minor output changes)."
