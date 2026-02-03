---
sidebar_position: 2
---

# Réseau

## Topologie

### Réseau local

| Segment | CIDR | Usage |
|---------|------|-------|
| Home Network | 192.168.68.0/24 | Réseau domestique |
| Proxmox | 192.168.68.51 | Hyperviseur |
| VMs K8s | 192.168.68.100-150 | Cluster local |

### Oracle Cloud

| Ressource | CIDR | Usage |
|-----------|------|-------|
| VCN | 10.0.0.0/16 | Réseau virtuel |
| Public Subnet | 10.0.1.0/24 | VMs avec IP publique |

## Accès externe

### Cloudflare Tunnel

Pas de ports ouverts sur le routeur. Tout passe par Cloudflare Tunnel.

```
Internet → Cloudflare → Tunnel → cloudflared (K8s) → Service
```

**Services exposés via Tunnel :**

| Subdomain | Service | Accès |
|-----------|---------|-------|
| home.smadja.dev | Homepage | Public |
| auth.smadja.dev | Authentik | Public |
| status.smadja.dev | Uptime Kuma | Public |
| feedback.smadja.dev | Fider | Public |
| grafana.smadja.dev | Grafana | Cloudflare Access |
| argocd.smadja.dev | ArgoCD | Cloudflare Access |

### Twingate (VPN Zero Trust)

Pour l'accès aux services internes sans exposition.

```
Client Twingate → Twingate Cloud → Connector (K8s) → Service interne
```

**Ressources accessibles via Twingate :**

| Ressource | Adresse | Usage |
|-----------|---------|-------|
| Proxmox | 192.168.68.51:8006 | Administration |
| K8s API | 10.0.1.x:6443 | kubectl |
| Prometheus | prometheus.monitoring:9090 | Métriques |

## DNS

### Cloudflare DNS

Tous les enregistrements DNS sont gérés via Terraform.

```hcl
# terraform/cloudflare/dns.tf
resource "cloudflare_record" "homelab_services" {
  for_each = var.homelab_services
  zone_id  = var.zone_id
  name     = each.value.subdomain
  # ...
}
```

### Enregistrements

| Type | Name | Value |
|------|------|-------|
| A | @ | Cloudflare Tunnel |
| CNAME | www | smadja.dev |
| CNAME | *.smadja.dev | Tunnel UUID |
| TXT | _dmarc | DMARC policy |
| TXT | @ | SPF record |

## Network Policies

Cilium Network Policies isolent les namespaces.

```yaml
# Deny all ingress by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: monitoring
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

Voir `kubernetes/infrastructure/network-policies/` pour toutes les policies.
