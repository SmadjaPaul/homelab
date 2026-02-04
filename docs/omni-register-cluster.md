# Enregistrer des clusters Talos avec Omni

## CLOUD (OCI) — image Omni

Pour le cluster CLOUD sur Oracle Cloud, on utilise l’**image Talos générée par Omni** (préconfigurée). Pas d’enregistrement manuel ni de playbook.

1. Dans l’**UI Omni** : créer le cluster (ex. « cloud »), télécharger l’**image Oracle** (ex. `oracle-amd64-omni-*.qcow2.xz`).
2. Importer l’image dans OCI (voir [terraform/oracle-cloud/README.md](../terraform/oracle-cloud/README.md) et [Zwindler - Omni Talos OCI](https://blog.zwindler.fr/2025/01/04/sideros-omni-talos-oracle-cloud/)).
3. Définir `talos_image_id` dans Terraform et lancer `terraform apply`. Les VMs bootent en Talos et **s’enrôlent dans Omni au premier boot** ; les ajouter au cluster depuis l’UI Omni.

## DEV (Proxmox) — config manuelle

Pour le cluster DEV (Talos sur Proxmox, boot via ISO) :

1. **Omni UI** : créer le cluster (ex. « dev »), copier le **join token**.
2. **Talos** : ajouter la section Omni dans `talos/controlplane.yaml` et `talos/worker.yaml` (sous `machine:`), avec `omni.url` et `omni.joinToken`.
3. Appliquer la config : `talosctl apply-config --insecure --nodes <IP> --file talos/controlplane.yaml` (idem pour les workers avec `worker.yaml`).
4. Vérifier dans l’UI Omni que le cluster et les nœuds apparaissent.

Voir aussi [Omni - Register machines](https://docs.siderolabs.com/omni/omni-cluster-setup/registering-machines/register-machines-with-omni).
