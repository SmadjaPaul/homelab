---
sidebar_position: 4
---

# Certificate Expired

## Symptômes

- Alerte `CertificateExpiringSoon` ou `CertificateExpired`
- Erreurs SSL dans le navigateur
- Services HTTPS inaccessibles

## Impact

- Services HTTPS down
- Erreurs de sécurité pour les utilisateurs
- APIs cassées

## Diagnostic

### 1. Identifier le certificat

```bash
# Lister les certificats
kubectl get certificates -A

# Détails
kubectl describe certificate <cert-name> -n <namespace>

# Vérifier l'expiration
kubectl get certificate <cert-name> -n <namespace> -o jsonpath='{.status.notAfter}'
```

### 2. Vérifier cert-manager

```bash
# Status cert-manager
kubectl get pods -n cert-manager

# Logs
kubectl logs -f deploy/cert-manager -n cert-manager

# ClusterIssuers
kubectl get clusterissuers
kubectl describe clusterissuer letsencrypt-prod
```

### 3. Vérifier le challenge

```bash
# Orders en cours
kubectl get orders -A

# Challenges
kubectl get challenges -A
kubectl describe challenge <challenge-name> -n <namespace>
```

## Résolution

### Cas 1: Renouvellement bloqué

```bash
# Supprimer et recréer le certificat
kubectl delete certificate <cert-name> -n <namespace>

# cert-manager va recréer automatiquement
# Vérifier
kubectl get certificate <cert-name> -n <namespace> -w
```

### Cas 2: Challenge DNS échoue

```bash
# Vérifier le token Cloudflare
kubectl get secret cloudflare-api-token -n cert-manager -o yaml

# Vérifier les logs external-dns
kubectl logs -f deploy/external-dns -n external-dns

# Forcer la récréation
kubectl delete order -n <namespace> --all
```

### Cas 3: Rate limit Let's Encrypt

Attendre 1h et réessayer. Let's Encrypt a des limites :
- 50 certificats par semaine par domaine
- 5 échecs par heure par compte

### Cas 4: Certificat manuel expiré

```bash
# Générer un nouveau certificat
# Via Cloudflare si disponible
# Ou manuellement via certbot
```

## Vérification

```bash
# Vérifier le certificat déployé
kubectl get secret <tls-secret> -n <namespace> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

# Ou via curl
curl -vI https://<domain> 2>&1 | grep -A5 "Server certificate"
```

## Prévention

1. Alertes à 30, 14, 7 jours avant expiration
2. Utiliser cert-manager pour le renouvellement automatique
3. Monitorer les certificats dans Grafana
4. Tester les challenges DNS régulièrement
