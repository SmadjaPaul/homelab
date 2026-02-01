# OVH Managed Kubernetes — Alternative pour le cluster CLOUD

Option pour héberger le **cluster CLOUD** (services famille, accès externe) sur OVH Managed Kubernetes au lieu d’Oracle Cloud (Talos sur VMs ARM).

## Offre OVH Managed Kubernetes

| Plan   | SLO    | ETCD quota | Max nodes | Prix |
|--------|--------|------------|-----------|------|
| **Free** | 99.5% | 400 Mio    | 100       | **Control plane gratuit** |

- **Control plane** : gratuit (orchestration Kubernetes managée, certifié CNCF).
- **Nœuds (workers)** : payants au standard OVH Public Cloud (CPU/RAM + stockage).
- Ordre de grandeur : petit cluster dès ~22 €/mois HT (ex. 1–2 nœuds).

Source : [OVH Managed Kubernetes](https://www.ovhcloud.com/en/public-cloud/kubernetes/).

## Où ça rentre dans l’archi

Aujourd’hui, le **cluster CLOUD** est prévu sur **Oracle Cloud** (Talos sur VMs ARM Always Free) :

- **oci-mgmt** : Omni + Keycloak + Cloudflared (hors K8s).
- **oci-node-1 / oci-node-2** : nœuds Talos du cluster CLOUD (Comet, Nextcloud, Vaultwarden, etc.).

**Avec OVH Managed Kubernetes** :

- Le **cluster CLOUD** devient un cluster OVH Managed K8s (plus de Talos sur OCI pour ce cluster).
- **Omni** continue de gérer **DEV** et **PROD** (Talos sur Proxmox). Le cluster CLOUD OVH n’est **pas** géré par Omni (Omni cible Talos, pas un K8s managé OVH).
- **Keycloak / Cloudflare Tunnel** : soit restent sur une petite VM OCI (oci-mgmt uniquement), soit sont déplacés sur le cluster OVH ou ailleurs.

En résumé : OVH Managed K8s peut **remplacer** la partie “cluster Kubernetes CLOUD” de l’archi actuelle (les nœuds OCI Talos), pas Omni ni les clusters DEV/PROD sur Proxmox.

## Avantages / inconvénients vs OCI Talos pour CLOUD

| Critère              | OCI Talos (actuel)     | OVH Managed K8s        |
|----------------------|------------------------|-------------------------|
| Coût                 | Always Free (si dispo) | CP gratuit, nœuds payants (~22 €/mois+) |
| Capacité             | Souvent “Out of host capacity” | Pas ce blocage |
| Gestion              | Toi (Talos + Omni)     | OVH (control plane)    |
| Omni                 | CLOUD dans Omni        | CLOUD hors Omni         |
| Static IP (Comet)    | IP réservée OCI        | À vérifier (LB / egress OVH) |
| Localisation         | eu-paris-1             | Régions OVH (ex. Paris) |

**Points à valider pour ton cas** :

1. **IP fixe pour Comet (Real-Debrid)** : vérifier qu’OVH permet une IP sortante ou un Load Balancer stable pour le trafic Comet.
2. **ArgoCD / GitOps** : identique (tu pointes un kubeconfig OVH au lieu d’OCI).
3. **Réseau / Twingate** : même logique (connector dans le cluster CLOUD, peu importe OCI ou OVH).

## Complexité : CLOUD hors Omni

Si le cluster CLOUD est sur OVH Managed Kubernetes, **il n’est pas géré par Omni**. Tu te retrouves avec :

- **DEV + PROD** : dans Omni (Talos) — une seule console, upgrades et kubeconfig au même endroit.
- **CLOUD** : hors Omni — un second cluster à gérer à part (kubeconfig OVH, upgrades OVH, monitoring à brancher séparément).

Ça **ajoute de la complexité** (deux contextes, deux façons de déployer/upgrader, pas une seule vue “tous mes clusters”). Rester sur **OCI + Omni** pour les trois clusters garde un seul outil et une seule stack.

## Recommandation

- **Priorité** : attendre que l’upgrade OCI soit effectif et déployer le cluster CLOUD sur OCI (Talos) dans Omni. Tu restes avec **une seule complexité** (Omni pour tout).
- **Secours** : n’envisager OVH Managed Kubernetes que si OCI reste bloqué ou trop instable, en acceptant **une complexité en plus** (CLOUD hors Omni, second flux opérationnel).

Tu peux garder l’option OVH en tête sans rien casser : l’archi (namespaces, apps, ArgoCD) reste réutilisable sur un cluster OVH, mais la gestion au quotidien sera moins simple qu’avec tout dans Omni.
