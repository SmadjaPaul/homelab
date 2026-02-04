# Ansible — Homelab

Déploiement du stack OCI management (Cloudflared, Authentik, Omni) via Ansible.

## Prérequis

- Ansible
- Collections : `ansible-galaxy collection install -r requirements.yml`

## Déploiement en local

Depuis la racine du dépôt :

```bash
# Installer les collections une fois
ansible-galaxy collection install -r ansible/requirements.yml

# Lancer le playbook (remplacer MGMT_IP et les secrets)
ansible-playbook ansible/playbooks/oci-mgmt-deploy.yml \
  -i "oci_mgmt," \
  -e "ansible_host=MGMT_IP" \
  -e "ansible_user=ubuntu" \
  -e "ansible_ssh_private_key_file=~/.ssh/oci_mgmt.pem" \
  -e "project_root=$(pwd)" \
  -e "cloudflare_tunnel_token=YOUR_TUNNEL_TOKEN" \
  -e "postgres_password=YOUR_POSTGRES_PASSWORD" \
  -e "authentik_secret_key=YOUR_AUTHENTIK_SECRET"
```

Ou avec un fichier de variables (ne pas commiter les secrets) :

```bash
# vars.yml (gitignore) avec ansible_host, cloudflare_tunnel_token, etc.
ansible-playbook ansible/playbooks/oci-mgmt-deploy.yml -e "@vars.yml"
```

## CI

Le workflow **Deploy OCI Management Stack** (`deploy-oci-mgmt.yml`) exécute ce playbook après récupération de l'IP (Terraform) et des secrets (OCI Vault).

## Install ArgoCD on DEV Cluster

Pour installer ArgoCD sur le cluster DEV :

```bash
# Exécuter le playbook
ansible-playbook ansible/playbooks/install-argocd.yml \
  -e "namespace=argocd" \
  -e "argocd_dir=kubernetes/argocd"

# Ou avec un fichier de variables
ansible-playbook ansible/playbooks/install-argocd.yml \
  -e "@vars.yml"
```

Le playbook :
- Vérifie les prérequis (kubectl, kustomize)
- Crée le namespace ArgoCD
- Installe ArgoCD via kustomize
- Attend que le serveur ArgoCD soit prêt
- Récupère et affiche le mot de passe admin initial
- Affiche les instructions pour accéder à l'UI
