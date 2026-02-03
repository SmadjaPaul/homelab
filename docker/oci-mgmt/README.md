# OCI Management Stack (Story 1.3.2)

Docker Compose pour la VM management Oracle Cloud : **Omni** + PostgreSQL.

À déployer sur la VM créée par Terraform (Story 1.3.1) après `terraform apply` réussi.

## Prérequis

- VM OCI management opérationnelle (`ssh ubuntu@<public_ip>`)
- Docker et Docker Compose déjà installés (cloud-init)

## Déploiement Omni

1. Sur la VM ou en local, cloner/copier ce dossier vers la VM :
   ```bash
   scp -r docker/oci-mgmt ubuntu@<management_ip>:~/homelab/
   ```

2. Sur la VM, créer un fichier `.env` avec (ou fourni par la CI via secrets `OMNI_DB_*`) :
   ```bash
   OMNI_DB_USER=omni
   OMNI_DB_PASSWORD=<mot_de_passe_fort>
   OMNI_DB_NAME=omni
   ```
   En CI : le workflow **Deploy OCI Management Stack** crée `.env` à partir des secrets GitHub ; voir `.github/workflows/deploy-oci-mgmt.yml` et `DEPLOYMENTS.md` (section 3b).

3. Puis :
   ```bash
   cd ~/homelab/oci-mgmt
   docker compose up -d
   ```

4. Documentation officielle Omni self-hosted :
   - [Deploy Omni On-Prem](https://omni.siderolabs.com/how-to-guides/self_hosted/)
   - [Sidero Docs - Self-hosted](https://docs.siderolabs.com/omni/infrastructure-and-extensions/self-hosted/deploy-omni-on-prem)

## Services

| Service   | Rôle                          |
|----------|---------------------------------|
| postgres | Base de données Omni (et optionnel Authentik) |
| omni     | Omni server (management Talos)  |

HTTPS et reverse proxy (Nginx / Caddy) à ajouter selon [Expose Omni with Nginx (HTTPS)](https://omni.siderolabs.com/how-to-guides/self_hosted/).

## Docker Compose vs autres options

**Pourquoi Docker Compose ici (et pas Kubernetes) ?**

| Critère | Docker Compose (actuel) | K8s (k3s/microk8s) sur oci-mgmt |
|--------|---------------------------|----------------------------------|
| **Ressources** | Léger (pas de control plane) | Lourd (etcd + API server sur une 6 GB VM) |
| **Omni** | Omni tourne **hors** K8s, comme prévu par Sidero | Omni dans un cluster qu’il ne gère pas = cas particulier, plus fragile |
| **Opérations** | `docker compose up/restart/logs` | `kubectl`, Helm, voire ArgoCD — plus de pièces pour 4–5 services |
| **Cohérence avec le reste** | Un seul “nœud management” à part | Même outil (kubectl) partout, mais un 4ᵉ cluster à maintenir |

**Conclusion** : pour une VM dédiée à Omni + Authentik + PostgreSQL + Cloudflared, Docker Compose reste le plus adapté : peu de ressources, modèle simple, et Omni est conçu pour tourner en dehors des clusters qu’il gère. Passer à un petit K8s sur oci-mgmt ajouterait de la complexité (control plane, upgrades K8s) pour peu d’avantage réel.

**Podman / Podman Compose** : possible en remplacement de Docker (rootless, pas de daemon). Même modèle opérationnel, avantage surtout côté sécurité ; pas nécessaire pour démarrer.

## Suite (Epic 1.3)

- **1.3.3** : Enregistrer le cluster DEV dans Omni (join token)
- **1.3.4** : MachineClasses dans `omni/machine-classes/`
