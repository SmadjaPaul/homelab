# Omni — flux CLOUD et DEV

## CLOUD (OCI)

Flux aligné avec [Zwindler - Talos Linux sur Oracle Cloud](https://blog.zwindler.fr/2025/01/04/sideros-omni-talos-oracle-cloud/) :

1. **Omni UI** : créer le cluster (ex. « cloud »), télécharger l’image Oracle.
2. **OCI** : importer l’image en Custom Image, noter l’OCID.
3. **Terraform** : `talos_image_id` = OCID, puis `terraform apply`. Les nœuds K8s démarrent avec cette image et s’enrôlent dans Omni au premier boot.
4. **Omni UI** : ajouter les machines au cluster.

Aucun playbook Ansible ni join token dans Terraform.

## DEV (Proxmox)

1. Créer le cluster dans l’UI Omni, copier le join token.
2. Ajouter la section `omni` (url, joinToken) dans les configs Talos (`talos/controlplane.yaml`, `talos/worker.yaml`).
3. `talosctl apply-config` sur chaque nœud.

Voir [omni-register-cluster.md](omni-register-cluster.md).
