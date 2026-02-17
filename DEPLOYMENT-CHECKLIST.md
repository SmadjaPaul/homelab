# Deployment Checklist
# ====================
# GitOps Deployment with GitHub Actions

## Quick Start (GitOps)

The deployment is automated via GitHub Actions. Simply push to main or trigger workflows manually.

### Prerequisites
- [ ] GitHub repository secrets configured:
  - `DOPPLER_TOKEN` - Your Doppler personal/CI token
  - `ROBUSTA_ACCOUNT_ID` - From Robusta dashboard
  - `ROBUSTA_SIGNING_KEY` - From Robusta dashboard
  - `KUBECONFIG_OCI` - Base64 encoded kubeconfig for OCI cluster

### Automated Deployment

1. **Push to main** triggers:
   - KCL validation
   - Terraform secrets generation
   - Kubernetes deployment via Argo CD

2. **Or trigger manually**:
   - Go to Actions → "GitOps - Deploy Infrastructure"
   - Click "Run workflow"
   - Select environment (oci or home)

## Phase 1: Manual Doppler Setup (One-time)

⚠️ **Only needed for first deployment or new projects**

- [ ] 1.1 Create Doppler projects
  ```bash
  ./scripts/setup-doppler.sh
  ```

- [ ] 1.2 Add external secrets (manual)
  ```bash
  # Get from Cloudflare dashboard
  doppler secrets set TUNNEL_TOKEN="<token>" -p cloudflare -c prod

  # Get from Robusta dashboard
  doppler secrets set account_id="<id>" -p robusta -c prod
  doppler secrets set signing_key="<key>" -p robusta -c prod
  ```

## Phase 2: GitOps Deployment

- [ ] 2.1 Ensure GitHub secrets are set
  - Check: Settings → Secrets and variables → Actions

- [ ] 2.2 Trigger deployment
  ```bash
  # Option 1: Push to main
  git add .
  git commit -m "Deploy infrastructure"
  git push origin main

  # Option 2: Manual trigger
  # Go to GitHub Actions → "GitOps - Deploy Infrastructure" → Run workflow
  ```

- [ ] 2.3 Monitor deployment
  - Watch GitHub Actions logs
  - Check Argo CD UI: `kubectl port-forward svc/argocd-server -n argo-cd 8080:443`

## Phase 3: Verification

- [ ] 3.1 Run verification script
  ```bash
  ./scripts/verify-deployment.sh
  ```

- [ ] 3.2 Check GitHub Actions summary
  - Go to the completed workflow run
  - Review the "Deployment Summary" section

- [ ] 3.3 Manual checks
  ```bash
  # Check all pods
  kubectl get pods -A

  # Check Argo CD apps
  kubectl get applications -n argo-cd

  # Check secrets
  kubectl get externalsecret -A
  ```

## Phase 4: Post-Deployment

- [ ] 4.1 Configure Authentik
  - Access: https://authentik.k8s.smadja.dev
  - Use bootstrap token from Doppler
  - Create admin user
  - Set up OIDC providers

- [ ] 4.2 Verify Cloudflare Tunnel
  ```bash
  kubectl logs -n cloudflared deployment/cloudflared
  ```

- [ ] 4.3 Access services
  - Argo CD: https://argocd.k8s.smadja.dev
  - Grafana: https://grafana.k8s.smadja.dev
  - Authentik: https://authentik.k8s.smadja.dev

---

## Commandes de Debug Rapide

```bash
# Voir tous les pods en erreur
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

# Logs Argo CD
kubectl logs -n argo-cd deployment/argocd-server

# Logs External Secrets Operator
kubectl logs -n kube deployment/external-secrets

# Forcer sync d'un secret
kubectl annotate externalsecret -n <namespace> <name> force-sync=$(date +%s)

# Redémarrer une app
kubectl rollout restart deployment/<name> -n <namespace>
```

---

## Post-Déploiement: À faire manuellement

1. **Authentik**:
   - Se connecter à https://authentik.k8s.smadja.dev
   - Utiliser le bootstrap token pour créer un admin
   - Créer les providers OIDC pour chaque service

2. **Cloudflare**:
   - Vérifier dans le dashboard CF que le tunnel est "Healthy"
   - Confirmer que les DNS pointent bien vers le tunnel

3. **Robusta**:
   - Se connecter au dashboard Robusta
   - Vérifier que le cluster est connecté

4. **Backup**:
   - Sauvegarder les tokens Doppler générés (/tmp/doppler-tokens-*)
   - Documenter les mots de passe générés par Terraform

---

## Prochaines Étapes (Après déploiement initial)

- [ ] Configurer le backup (VolSync)
- [ ] Ajouter le cluster Home quand il sera prêt
- [ ] Configurer les alertes Robusta
- [ ] Setup cert-manager pour les certificats TLS
- [ ] Configurer les dashboards Grafana
