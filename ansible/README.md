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

Le workflow **Deploy OCI Management Stack** (`deploy-oci-mgmt.yml`) exécute ce playbook après récupération de l’IP (Terraform) et des secrets (OCI Vault).
