# Post-Deployment Configuration Guide
# ====================================
# Configuring services after initial deployment

## 1. Access Argo CD

```bash
# Port-forward
kubectl port-forward svc/argocd-server -n argo-cd 8080:443

# Get admin password
kubectl -n argo-cd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d

# Open browser
echo "https://localhost:8080"
```

## 2. Configure Authentik (Identity Provider)

### 2.1 Initial Setup
```bash
# Get bootstrap token from Doppler
doppler secrets get AUTHENTIK_BOOTSTRAP_TOKEN --plain -p authentik -c prod

# Access Authentik
echo "https://authentik.k8s.smadja.dev"

# Login with:
# Username: akadmin
# Password: <bootstrap_token>
```

### 2.2 Create Admin User
1. Go to Directory → Users
2. Click "Create"
3. Set username, email, password
4. Add to group "authentik Admins"

### 2.3 Create OIDC Provider for Argo CD
1. Go to Providers → Create
2. Select "OAuth2/OpenID Provider"
3. Configuration:
   - Name: argo-cd
   - Client ID: argo-cd
   - Client Secret: <generate random>
   - Redirect URIs: https://argocd.k8s.smadja.dev/auth/callback
4. Save

### 2.4 Create Application in Authentik
1. Go to Applications → Create
2. Name: Argo CD
3. Provider: Select the one created above
4. Launch URL: https://argocd.k8s.smadja.dev

### 2.5 Update Argo CD Configuration
```bash
# Edit the Argo CD app configuration
kubectl edit application argo-cd -n argo-cd

# Add to values:
# configs:
#   cm:
#     dex.config: |
#       connectors:
#         - type: oidc
#           id: authentik
#           name: Authentik
#           config:
#             issuer: https://authentik.k8s.smadja.dev/application/o/argo-cd/
#             clientID: argo-cd
#             clientSecret: <secret_from_step_2.3>
```

## 3. Configure Cloudflare Tunnel

### 3.1 Verify Tunnel Connection
```bash
# Check logs
kubectl logs -n cloudflared deployment/cloudflared | grep "Connected"

# Should show: "Connected to https://<tunnel-id>.cfargotunnel.com"
```

### 3.2 Configure Public Hostnames (if not done in Terraform)
1. Go to Cloudflare Zero Trust dashboard
2. Networks → Tunnels → Select your tunnel
3. Public Hostnames tab
4. Add routes:
   - argocd.k8s.smadja.dev → http://traefik.kube.svc.cluster.local:80
   - authentik.k8s.smadja.dev → http://traefik.kube.svc.cluster.local:80
   - grafana.k8s.smadja.dev → http://traefik.kube.svc.cluster.local:80
   - etc.

## 4. Configure Robusta

### 4.1 Verify Connection
```bash
# Check pods
kubectl get pods -n robusta

# Check logs
kubectl logs -n robusta deployment/robusta-runner
```

### 4.2 Access Dashboard
1. Go to https://platform.robusta.dev
2. Login with your account
3. Verify the cluster appears as "Connected"

## 5. Configure Grafana

### 5.1 Access Grafana
```bash
# Get admin password from Doppler
doppler secrets get GRAFANA_ADMIN_PASSWORD --plain -p grafana -c prod

# Access Grafana
echo "https://grafana.k8s.smadja.dev"
# Login: admin / <password>
```

### 5.2 Add Datasources (if not auto-configured)
1. Configuration → Datasources → Add
2. Add Prometheus: http://prometheus-server.o11y.svc.cluster.local:9090
3. Add Loki: http://loki-gateway.o11y.svc.cluster.local:80
4. Add Tempo: http://tempo-gateway.o11y.svc.cluster.local:80

### 5.3 Import Dashboards
1. Create → Import
2. Import Kubernetes dashboards (ID: 7249, 315, etc.)

## 6. Configure n8n

### 6.1 Access n8n
```bash
# Get encryption key (already configured via secret)
doppler secrets get N8N_ENCRYPTION_KEY --plain -p n8n -c prod

# Access n8n
echo "https://n8n.k8s.smadja.dev"
# Create admin user on first access
```

## 7. Verify All Services

### 7.1 Quick Health Check
```bash
# Run verification script
./scripts/verify-deployment.sh
```

### 7.2 Manual Checks
```bash
# Check all pods
kubectl get pods -A

# Check services
kubectl get svc -A

# Check ingresses
kubectl get ingress -A

# Check certificates
kubectl get certificate -A
```

## 8. Configure DNS (if needed)

If using Cloudflare Tunnel, DNS should be automatic. If not:

```bash
# Add DNS records in Cloudflare dashboard
Type: CNAME
Name: argocd
Target: <tunnel-id>.cfargotunnel.com
Proxy status: Enabled (orange cloud)
```

## 9. SSL/TLS Certificates

Cert-manager should automatically issue certificates. Verify:

```bash
# Check certificates
kubectl get certificate -A

# Check cert-manager logs
kubectl logs -n kube deployment/cert-manager

# Force renewal if needed
kubectl annotate certificate <name> -n <namespace> cert-manager.io/revoke-next="true"
```

## 10. Backup Strategy

### 10.1 Enable VolSync
```bash
# Check VolSync is running
kubectl get pods -n volsync

# Create ReplicationSource for each app (example for Authentik)
kubectl apply -f - <<EOF
apiVersion: volsync.backube/v1alpha1
kind: ReplicationSource
metadata:
  name: authentik-backup
  namespace: authentik
spec:
  sourcePVC: authentik-postgres-data
  trigger:
    schedule: "0 */6 * * *"  # Every 6 hours
  restic:
    repository: doppler-secret:authentik-backup-repo
    retain:
      hourly: 6
      daily: 7
      weekly: 4
EOF
```

## 11. Monitoring & Alerting

### 11.1 Configure Robusta Alerts
Create `robusta-config.yaml`:
```yaml
active_playbooks:
  - name: "CPU Throttling"
    action: cpu_throttling_analysis
  - name: "OOMKilled Pods"
    action: oomkilled_analysis
  - name: "High Memory Usage"
    action: high_memory_analysis
```

### 11.2 Grafana Alerts
1. Alerting → Alert Rules → New
2. Create rules for:
   - High CPU usage (>80%)
   - High memory usage (>85%)
   - Pod restart count (>3 in 10min)
   - Certificate expiry (<30 days)

## 12. Security Hardening

### 12.1 Network Policies
```bash
# Verify network policies are applied
kubectl get networkpolicies -A
```

### 12.2 RBAC Review
```bash
# Check service accounts
kubectl get serviceaccounts -A

# Check roles
kubectl get roles,clusterroles -A
```

### 12.3 Secrets Audit
```bash
# List all secrets (excluding default tokens)
kubectl get secrets -A | grep -v default-token | grep -v "kubernetes.io/service-account-token"
```

## 13. Documentation

### 13.1 Create Runbook
Document:
- How to access each service
- Emergency procedures
- Backup/restore procedures
- Contact information

### 13.2 Update README
Update the main README with:
- Service URLs
- Admin credentials location (Doppler)
- Troubleshooting steps

## 14. Final Verification

Run all verification commands:
```bash
# Full verification
./scripts/verify-deployment.sh

# Check all External Secrets
kubectl get externalsecret -A

# Check all certificates
kubectl get certificate -A

# Check Argo CD apps
kubectl get applications -n argo-cd
```

---

## Emergency Contacts & Procedures

### If Authentik is Down
```bash
# Bypass Authentik temporarily
kubectl edit ingress authentik -n authentik
# Remove auth annotations
```

### If Argo CD is Down
```bash
# Deploy manually
kubectl apply -f kubernetes/apps/base/argo-cd/base/
```

### Recover from Doppler Issues
```bash
# List all secrets locally
doppler secrets -p infrastructure -c prod

# Export to file (secure!)
doppler secrets download -p infrastructure -c prod --format json > backup.json
```
