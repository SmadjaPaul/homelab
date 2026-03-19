# Homelab Stabilization v2 & Immich Integration

## Current Cluster State (Audit: 2026-03-19)

### 🔴 Critical Issues (Down/Unusable)
- **Open-WebUI (ai.smadja.dev)**:
    - **Status**: Pod Running (1/1).
    - **Error**: Authentik "Access Denied" (403). "You do not have permission to access this resource."
    - **Analysis**: The application/provider in Authentik likely has a policy gating access (e.g. group membership) that isn't satisfied after the slug refactoring.
- **Paperless-ngx (paperless.smadja.dev)**:
    - **Status**: 502 Bad Gateway.
    - **Error**: `MountVolume.MountDevice failed with mount failed: exit status 32`.
    - **Analysis**: Persistent SMB permission issues on Hetzner Storage Box.
- **Owncloud (cloud.smadja.dev)**:
    - **Status**: 502 Bad Gateway.
    - **Error**: Same as Paperless (SMB Mount Fail).
- **Homepage (home.smadja.dev)**:
    - **Status**: 502 Bad Gateway.
    - **Analysis**: Outpost connectivity or health check failure.

### 🟢 Healthy Services
- **Vaultwarden (vault.smadja.dev)**: Operational via OIDC.
- **Navidrome (music.smadja.dev)**: Operational via Header-Auth (Wait, user says SSO doesn't work for *any* service, need to re-verify).
- **Audiobookshelf**: Operational.

---

## Planned Modifications

### 1. Authentik Policy Audit
- **Issue**: The application slugs were recently changed to include `-oidc` or `-header` suffixes (or vice versa during refactoring).
- **Instruction**:
    1. Log in to your Authentik Admin interface.
    2. Go to `Applications` -> `Applications`.
    3. Check if the applications (`open-webui`, `paperless-ngx`, etc.) have any **Policy Bindings**.
    4. If the bindings are missing, you must re-attach them to the NEW applications created by Pulumi.
    5. Check the `Providers` to ensure they are correctly linked to the new applications.

### 2. SMB Mount Recovery
- **Issue**: `exit status 32` (Permission Denied) persists despite ExternalSecrets.
- **Instruction**:
    - Verify if the `backup` directory on the Storage Box has specific **IP restrictions** or **Host restrictions** in the Hetzner Robot UI.
    - Try mounting with `sec=ntlmssp` or `vers=2.1` if `3.0` fails (though `navidrome` works on the same node).

### 3. Immich Integration
- Added `immich` to `apps.yaml` using the official Helm chart (`immich-app.github.io/immich-charts`).
- Ready for deployment via `make up-apps`.

---

## Immich Configuration (Draft)

```yaml
- name: immich
  category: media
  tier: standard
  namespace: photography
  hostname_prefix: photos
  sso: authentik-oidc
  requires: [postgres, redis]
  storage:
    - name: library
      size: 1Ti
      mount_path: /usr/src/app/upload
      storage_class: hetzner-smb
  helm:
    chart: immich
    repo: https://immich-app.github.io/immich-charts
    version: 0.6.0
```
