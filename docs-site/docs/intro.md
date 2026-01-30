---
sidebar_position: 1
slug: /
---

# Homelab Documentation

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
| [Architecture](/architecture/overview) | Vue détaillée de l'architecture |
| [Services](/services/overview) | Liste des services déployés |
| [Runbooks](/runbooks) | Procédures d'intervention |
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
