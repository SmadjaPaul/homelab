# Story 1.4.1: Install ArgoCD on DEV Cluster

Status: ready-for-dev

## Story

As a developer administrator,
I want ArgoCD installed on the DEV cluster,
so that I can test GitOps workflows.

## Acceptance Criteria

1. [ ] ArgoCD installed via manifest
2. [ ] ArgoCD UI accessible
3. [ ] Admin password configured
4. [ ] ArgoCD namespace created

## Tasks / Subtasks

- [ ] Task 1: Install ArgoCD using Ansible (AC: #1, #4)
  - [ ] Run Ansible playbook: `ansible-playbook ansible/playbooks/install-argocd.yml`
  - [ ] Playbook verifies prerequisites (kubectl, kustomize)
  - [ ] Playbook creates namespace and installs ArgoCD
  - [ ] Playbook waits for ArgoCD server to be ready
  - [ ] Verify namespace created: `kubectl get namespace argocd`
- [ ] Task 3: Configure admin password (AC: #3)
  - [ ] Get initial admin password from secret: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
  - [ ] Change admin password using ArgoCD CLI or UI
  - [ ] Store password securely (password manager, not in Git)
  - [ ] Optionally: configure password via values.yaml and Helm (if switching to Helm)
- [ ] Task 4: Verify ArgoCD UI access (AC: #2)
  - [ ] Port-forward ArgoCD server: `kubectl port-forward svc/argocd-server -n argocd 8080:443`
  - [ ] Access UI: `https://localhost:8080` (accept self-signed cert)
  - [ ] Login with admin credentials
  - [ ] Verify UI loads correctly
  - [ ] Note: Future access via Cloudflare Tunnel (Story 3.4.1)
- [ ] Task 5: Verify installation (AC: #1, #4)
  - [ ] Check all ArgoCD pods are running: `kubectl get pods -n argocd`
  - [ ] Verify ArgoCD server is ready: `kubectl get deployment argocd-server -n argocd`
  - [ ] Check ArgoCD version: `kubectl exec -n argocd deployment/argocd-server -- argocd version`
  - [ ] Verify namespace exists: `kubectl get namespace argocd`

## Dev Notes

- **Installation Method**: Using kustomize with official ArgoCD manifests (see `kubernetes/argocd/install.yaml`)
- **Namespace**: `argocd` (already defined in `kubernetes/argocd/namespace.yaml`)
- **Configuration**: Manifests reference official ArgoCD install.yaml with patches for insecure mode
- **Future**: Will be self-managed via App of Apps pattern (Story 1.4.3 ✅ already created)
- **Access**: Initially via port-forward, later via Cloudflare Tunnel (Story 3.4.1)

### Project Structure Notes

- **Ansible playbook**: `ansible/playbooks/install-argocd.yml` (recommended method)
- **Ansible role**: `ansible/roles/argocd_install/`
- ArgoCD manifests: `kubernetes/argocd/`
  - `namespace.yaml` - Namespace definition
  - `install.yaml` - Kustomization referencing official manifests
  - `values.yaml` - Helm values (for future Helm migration if needed)
  - `app-of-apps.yaml` - Root application (Story 1.4.3 ✅)
- Documentation: `docs-site/docs/infrastructure/kubernetes.md` (ArgoCD section)

### References

- [Source: _bmad-output/planning-artifacts/epics-and-stories-homelab.md] Story 1.4.1 acceptance criteria
- [Source: kubernetes/argocd/install.yaml] Kustomization configuration
- [ArgoCD Documentation: Installation](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)
- [ArgoCD Documentation: Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)

## Dev Agent Record

### Agent Model Used

(To be filled by dev agent)

### Debug Log References

### Completion Notes List

### File List
