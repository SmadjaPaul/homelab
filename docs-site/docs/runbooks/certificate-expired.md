---
sidebar_position: 5
---

# Certificate Expired

## Symptômes

- Alerte `CertificateExpiring`
- Erreurs SSL dans le navigateur
- Services HTTPS down

## Impact

Services HTTPS inaccessibles.

## Diagnostic

```bash
# Certificats
kubectl get certificates -A

# Détails
kubectl describe certificate <cert-name> -n <namespace>

# cert-manager
kubectl logs -f deploy/cert-manager -n cert-manager
```

## Résolution

### Renouvellement bloqué

```bash
# Recréer le certificat
kubectl delete certificate <cert-name> -n <namespace>
# cert-manager va recréer automatiquement
```

### Challenge DNS échoue

```bash
# Vérifier le token Cloudflare
kubectl get secret cloudflare-api-token -n cert-manager

# Voir les challenges
kubectl get challenges -A
```

### Rate limit Let's Encrypt

Attendre 1h. Limites :
- 50 certificats/semaine/domaine
- 5 échecs/heure/compte

## Prévention

1. Alertes à 30, 14, 7 jours
2. cert-manager pour renouvellement auto
3. Monitorer dans Grafana
