# Spec: Alerting Automatique pour Apps Critiques

## Contexte

Les `ServiceMonitor` sont auto-générés pour chaque app (`kubernetes_registry.py:136-188`), mais il n'y a ni `PrometheusRule` ni alerting configuré. Si un pod `tier: critical` (authentik, vaultwarden) crash ou qu'un backup DB échoue, personne n'est notifié. La détection de panne repose sur une vérification manuelle.

## Objectif

Les apps `tier: critical` génèrent automatiquement des alertes Prometheus en cas de panne pod, backup DB manquée, ou certificat SSL expirant.

## Scope

### In scope
- [ ] Créer un `PrometheusRule` auto-généré pour les apps `tier: critical` dans `kubernetes_registry.py` :
  - **PodDown** : `kube_pod_status_phase{phase="Failed"}` ou pod absent > 5min
  - **PodRestartLoop** : `increase(kube_pod_container_status_restarts_total[1h]) > 3`
  - **ContainerOOMKilled** : `kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}`
- [ ] Ajouter des alertes DB pour les apps avec `database.local: true` :
  - **DBBackupStale** : dernier backup CNPG > 25h (schedule = 24h)
  - **DBClusterDegraded** : `cnpg_cluster_status != 1` (cluster not healthy)
- [ ] Configurer un canal de notification (Alertmanager → webhook ou email)
- [ ] Les alertes sont labellisées avec `severity: critical|warning` et `app: {name}`

### Out of scope
- Dashboard Grafana (spec séparée #8)
- Alerting pour les apps `tier: standard` ou `ephemeral`
- PagerDuty / OpsGenie intégration (overkill pour un homelab)
- Alertes SSL (cert-manager a ses propres alertes)

## Contraintes
- Secrets via Doppler uniquement (jamais en dur)
- Tout passe par Pulumi (pas de kubectl apply direct)
- Prometheus/Alertmanager doit déjà être déployé (via kube-prometheus-stack)
- Les alertes doivent utiliser les labels standard Kubernetes (`app.kubernetes.io/name`)
- Pas de bruit : les alertes ne doivent se déclencher que sur des situations actionnables

## Critères d'acceptance
- [ ] `uv run pulumi preview --stack oci` passe sans erreur
- [ ] `uv run pytest tests/static/ -v` passe
- [ ] `kubectl get prometheusrules -A` montre des règles pour chaque app `tier: critical`
- [ ] Simuler un crash pod → alerte `PodDown` se déclenche dans Alertmanager
- [ ] Les apps `tier: standard` n'ont PAS de `PrometheusRule` auto-générée
- [ ] Chaque alerte a un `runbook_url` ou `description` avec les étapes de résolution

## Fichiers concernés
- `kubernetes-pulumi/shared/apps/common/kubernetes_registry.py` — ajouter `setup_alerting_for_app()` à côté de `setup_monitoring_for_app()`
- `kubernetes-pulumi/shared/apps/common/registry.py` — appeler `setup_alerting_for_app()` dans `register_app()`
- `kubernetes-pulumi/apps.yaml` — optionnel : champ `alerting: true|false` pour override par app
- `kubernetes-pulumi/shared/utils/schemas.py` — optionnel : ajouter `alerting: bool` à `AppModel`

## Notes / Références
- PrometheusRule CRD : https://prometheus-operator.dev/docs/api-reference/api/#monitoring.coreos.com/v1.PrometheusRule
- CNPG expose des métriques Prometheus nativement : https://cloudnative-pg.io/documentation/current/monitoring/
- kube-prometheus-stack inclut déjà Alertmanager
