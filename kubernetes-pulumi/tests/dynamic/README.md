# Tests Dynamiques

Ces tests nécessitent un **cluster Kubernetes opérationnel** avec `kubectl` configuré.
Ils valident le runtime réel : pods, secrets synchronisés, endpoints HTTP, TLS.

## Prérequis

```bash
# Vérifier que kubectl est configuré
kubectl cluster-info

# Vérifier que les namespaces sont déployés
kubectl get namespaces
```

## Quand les exécuter

- ✅ Après un `pulumi up` pour valider le déploiement
- ✅ En post-deploy CI (optionnel, nécessite accès cluster)
- ❌ Pas en pre-commit (trop lent, besoin du cluster)

## Exécution

```bash
# Tous les tests dynamiques
uv run pytest tests/dynamic/ -v

# Tests de santé seulement
uv run pytest tests/dynamic/test_pod_health.py -v

# Tests HTTP/TLS (nécessite accès internet ou VPN)
uv run pytest tests/dynamic/test_connectivity.py -v
```

## Fichiers

| Fichier | Ce qui est testé |
|---------|-----------------|
| `test_pod_health.py` | Pods Running/Ready, pas de CrashLoop ou ImagePullBackOff |
| `test_secrets_sync.py` | ExternalSecrets synced (`SecretSynced` status), secrets K8s présents |
| `test_connectivity.py` | HTTP 200 sur les URLs publiques, redirection HTTPS, TLS valide |
