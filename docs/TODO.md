# Homelab TODO List

## 🚨 Auto-Provisioning (Dual-Layer Architecture)
- [ ] Add `ProvisioningConfig` schema to `schemas.py`
- [ ] Refactor `authentik_registry.py` — generic redirect URIs + dual-layer providers
- [ ] Add Doppler auto-upload of OIDC client secrets
- [ ] Add `apply_provisioning_config()` to `HelmValuesAdapter`
- [ ] Add `provisioning:` blocks to all apps in `apps.yaml`
- [ ] Deploy and verify auto-provisioning flow for each app

## 🔄 Nextcloud → OpenCloud Migration
- [ ] Deploy OpenCloud via Helm chart (`opencloud-eu/charts`)
- [ ] Configure OIDC auto-provisioning (`PROXY_AUTOPROVISION_ACCOUNTS`)
- [ ] Mount Hetzner Storage Box as data volume
- [ ] Migrate existing Nextcloud data (if any)
- [ ] Remove Nextcloud from `apps.yaml`

## 🛠️ SSO Fixes
- [ ] Fix Paperless-ngx Zero-Click SSO (header matching)
- [ ] Global Logout — invalidate sessions across all subdomains

##  Future
- [ ] Immich — photo management
- [ ] Home Assistant — home automation
- [ ] MCP server for WebDAV (AI file access via OpenCloud)

---
*Last updated: 2026-03-09*
