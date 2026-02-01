---
sidebar_position: 1
---

# Documentation technique

Cette section s’adresse à **l’administrateur** de la plateforme. Elle décrit l’infrastructure, le déploiement et les procédures d’exploitation.

Bienvenue dans la documentation technique du homelab Smadja.

## Vue d'ensemble

Ce homelab est une infrastructure hybride combinant :

- **Proxmox VE** : Hyperviseur local
- **Oracle Cloud** : VMs cloud gratuites (Always Free)
- **Kubernetes** : Orchestration via Talos Linux + Omni
- **GitOps** : Déploiement automatique via ArgoCD

## Architecture rapide

```
┌─────────────────────────────────────────────────────────────┐
│                      Internet                                │
│                          │                                   │
│                    Cloudflare                                │
│                    (WAF + Tunnel)                            │
│                          │                                   │
│         ┌────────────────┼────────────────┐                 │
│         │                │                │                 │
│    Oracle Cloud     Cloudflare       Twingate               │
│    (Services)        Tunnel          (VPN)                  │
│         │                │                │                 │
│         └────────────────┼────────────────┘                 │
│                          │                                   │
│                   ┌──────┴──────┐                           │
│                   │  Kubernetes │                           │
│                   │   Cluster   │                           │
│                   └─────────────┘                           │
└─────────────────────────────────────────────────────────────┘
```

## Liens rapides

| Ressource | Description |
|-----------|-------------|
| [Architecture](/advanced/architecture) | Vue détaillée de l'architecture |
| [Infrastructure](/infrastructure/kubernetes) | Infrastructure déployée |
| [Runbooks](/runbooks/overview) | Procédures d'intervention |
| [Status Page](https://status.smadja.dev) | État des services |

## Stack technique

| Composant | Technologie |
|-----------|-------------|
| Hyperviseur | Proxmox VE 8.x |
| Kubernetes | Talos Linux |
| CNI | Cilium |
| GitOps | ArgoCD |
| Secrets | SOPS + Age |
| DNS/CDN | Cloudflare |
| Monitoring | Prometheus + Grafana + Loki |
| SSO | Keycloak |

## Coût mensuel

| Provider | Service | Coût |
|----------|---------|------|
| Oracle Cloud | VMs ARM | **Gratuit** |
| Cloudflare | DNS + Tunnel | **Gratuit** |
| OVHcloud | Domaine | ~10€/an |
| **Total** | | **~1€/mois** |
