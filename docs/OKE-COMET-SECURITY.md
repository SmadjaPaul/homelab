# Architecture OKE - Sécurité et Accès Direct

## 🏗️ Architecture Proposée (OKE)

```
Internet
    │
    ├────────────────────┬──────────────────────┐
    │                    │                      │
    ▼                    ▼                      ▼
Cloudflare        LoadBalancer OCI        NodePort/HostPort
(DNS/WAF)         (Layer 7 - Gratuit)     (Direct)
    │                    │                      │
    │                    │                      │
    ▼                    ▼                      ▼
*.smadja.dev      Traefik (K8s)            Comet Pod
(Apps web)        (Ingress)                (Port 8080)
                         │                      │
                         └──────────┬───────────┘
                                    │
                          ┌─────────▼──────────┐
                          │  OKE Workers       │
                          │  (2 VMs - 12GB)    │
                          │                    │
                          │  Node 1:           │
                          │  - Longhorn        │
                          │  - Authentik       │
                          │  - Comet (8080)    │
                          │                    │
                          │  Node 2:           │
                          │  - Nextcloud       │
                          │  - Matrix          │
                          │  - etc.            │
                          └────────────────────┘
                                    │
                          ┌─────────▼──────────┐
                          │ OKE Control Plane  │
                          │ (Gratuit - Oracle) │
                          └────────────────────┘
```

## ✅ Comet en Accès Direct - Sécurisé

### Pourquoi c'est acceptable ?

**1. Comet est un service "leaf"**
```
Comet = Service terminal (streaming)
  ↓
Pas d'accès aux autres pods
Pas d'accès à la DB
Pas de privilèges spéciaux
```

**2. Isolation par Network Policies**
```yaml
# Comet ne peut PAS parler aux autres services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: comet-isolation
  namespace: media
spec:
  podSelector:
    matchLabels:
      app: comet
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from: []  # Seulement depuis Internet (pas depuis le cluster)
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to: []  # Pas de sortie autorisée
```

**3. Cloudflare Access protège l'entrée**
- Authentification email obligatoire
- Geo-blocking possible
- Rate limiting
- Logs complets

## 🔧 Configuration Technique

### Option 1: NodePort (Recommandé)

```yaml
# kubernetes/apps/media/comet/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: comet
  namespace: media
  annotations:
    # Optionnel: Cloudflare Access protection
    cloudflare.com/access: "true"
spec:
  type: NodePort
  selector:
    app: comet
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30080  # Port fixe sur tous les nœuds
```

**Accès:**
- `http://node1-public-ip:30080`
- `http://node2-public-ip:30080`

**Avantages:**
- ✅ Simple
- ✅ Fonctionne avec les 2 nodes
- ✅ Sécurisé avec Network Policies
- ✅ Pas de coût

### Option 2: HostPort (Plus simple)

```yaml
# kubernetes/apps/media/comet/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: comet
  namespace: media
spec:
  replicas: 1
  selector:
    matchLabels:
      app: comet
  template:
    spec:
      containers:
      - name: comet
        image: ghcr.io/g0ldyy/comet:latest
        ports:
        - containerPort: 8080
          hostPort: 8080  # Bind direct sur le host
      nodeSelector:
        node-type: streaming  # Force sur un node spécifique
```

**Accès:**
- `http://node-public-ip:8080`

**Avantages:**
- ✅ Port standard (8080)
- ✅ Latence minimale
- ❌ Limité à 1 node

### Option 3: LoadBalancer OCI (Coût ?)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: comet-lb
  namespace: media
  annotations:
    oci.oraclecloud.com/load-balancer-type: "lb"
spec:
  type: LoadBalancer
  selector:
    app: comet
  ports:
  - port: 8080
```

**⚠️ Attention:** LoadBalancer OCI = ~$15/mois (pas gratuit)

## 🛡️ Mesures de Sécurité

### 1. Network Policies Strictes

```yaml
# kubernetes/apps/media/comet/network-policy.yaml
---
# Isoler Comet du reste du cluster
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: comet-isolation
  namespace: media
spec:
  podSelector:
    matchLabels:
      app: comet
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Autoriser uniquement le port 8080 depuis n'importe où
  - ports:
    - protocol: TCP
      port: 8080
  egress:
  # Comet n'a PAS besoin de sortie
  # Si besoin, autoriser explicitement:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system  # DNS uniquement
    ports:
    - protocol: UDP
      port: 53
```

### 2. Security Context

```yaml
# kubernetes/apps/media/comet/deployment.yaml
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: comet
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
```

### 3. Cloudflare Access (Protection entrée)

```hcl
# terraform/cloudflare/main.tf
resource "cloudflare_access_application" "comet" {
  zone_id          = var.zone_id
  name             = "Comet Streaming"
  domain           = "stream.smadja.dev"
  type             = "self_hosted"
  session_duration = "24h"

  policies {
    decision = "allow"
    include {
      email = var.allowed_emails
    }
  }
}

# DNS record pointant vers l'IP publique du node
resource "cloudflare_record" "comet" {
  zone_id = var.zone_id
  name    = "stream"
  value   = oci_core_instance.worker[0].public_ip  # IP du node
  type    = "A"
  proxied = false  # Pas de proxy pour le streaming (latence)
}
```

### 4. Firewall OCI (Security List)

```hcl
# terraform/oke/network.tf
resource "oci_core_security_list" "workers" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id

  # Autoriser Comet (8080) depuis Internet
  ingress_security_rules {
    protocol = "6"  # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 8080
      max = 8080
    }
    description = "Comet streaming"
  }

  # Bloquer tout le reste par défaut
}
```

## 📊 Comparaison des Options

| Option | Coût | Sécurité | Latence | Complexité | Recommandé |
|--------|------|----------|---------|------------|------------|
| **NodePort** | Gratuit | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ✅ **OUI** |
| **HostPort** | Gratuit | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐ | ✅ OUI |
| **LoadBalancer** | $15/mois | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ❌ Non |
| **Ingress (Traefik)** | Gratuit | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ❌ Trop de latence |

## 🎯 Configuration Recommandée

### Setup Optimal pour Comet

**1. Déployer Comet avec NodePort:**

```yaml
# kubernetes/apps/media/comet/
apiVersion: v1
kind: Service
metadata:
  name: comet
  namespace: media
spec:
  type: NodePort
  selector:
    app: comet
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: comet
  namespace: media
spec:
  replicas: 1
  selector:
    matchLabels:
      app: comet
  template:
    spec:
      containers:
      - name: comet
        image: ghcr.io/g0ldyy/comet:latest
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_PATH
          value: "/data/comet.db"
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: comet-data
```

**2. Network Policy restrictive:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: comet-isolation
  namespace: media
spec:
  podSelector:
    matchLabels:
      app: comet
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - ports:
    - protocol: TCP
      port: 8080
  egress: []  # Pas de sortie
```

**3. Accès via Cloudflare Access:**

```
User → Cloudflare Access (Auth) → NodeIP:30080 → Comet Pod
```

**4. URL:**
- `https://stream.smadja.dev` → Cloudflare Access → NodeIP:30080

## ✅ Checklist Sécurité

- [ ] Comet isolé par Network Policy
- [ ] SecurityContext (non-root, read-only FS)
- [ ] Cloudflare Access (authentification)
- [ ] Security List OCI (port 8080 uniquement)
- [ ] Pas de secrets dans Comet (RD_API_KEY uniquement)
- [ ] Logs activés (Cloudflare + K8s)
- [ ] Rate limiting (Cloudflare)

## 🚨 Risques et Mitigations

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| **Comet compromis** | Faible | Moyen | Network Policy, non-root, read-only FS |
| **Accès non autorisé** | Faible | Élevé | Cloudflare Access, authentification |
| **DDoS** | Faible | Moyen | Rate limiting Cloudflare |
| **Fuite données** | Très faible | Faible | Pas de données sensibles dans Comet |

## 📈 Monitoring

```bash
# Voir les connexions à Comet
kubectl logs -n media deployment/comet

# Vérifier Network Policy
kubectl describe networkpolicy -n media comet-isolation

# Voir le trafic réseau
kubectl top pod -n media
```

## 🎬 Conclusion

**Oui, tu peux avoir Comet en accès direct sans compromettre la sécurité si:**

1. ✅ Isolation réseau stricte (Network Policies)
2. ✅ Authentification via Cloudflare Access
3. ✅ Pas de privilèges dans le container
4. ✅ Monitoring des logs

**Le reste du cluster reste protégé car:**
- Comet ne peut pas parler aux autres pods (Network Policy)
- Les autres services sont derrière le tunnel Cloudflare
- L'isolation est au niveau réseau (CNI)

Tu veux que je prépare cette config dans le repo ?
