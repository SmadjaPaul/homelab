# Spec: Dashboard d'Observabilité Auto-Généré

## Contexte

L'infra génère déjà des `ServiceMonitor` pour chaque app, et Homepage affiche un dashboard basique avec les apps. Mais il n'y a aucune vue opérationnelle centralisée : health des pods, status SSO, taille des bases, dernière backup, latence tunnel. Le diagnostic d'un problème nécessite plusieurs commandes `kubectl` manuelles.

## Objectif

Un dashboard Grafana auto-généré depuis `apps.yaml` donnant une vue opérationnelle complète du homelab en un coup d'œil.

## Scope

### In scope
- [ ] Déployer Grafana via Helm (ou via kube-prometheus-stack s'il est déjà inclus)
- [ ] Créer un dashboard ConfigMap provisionné automatiquement avec les panels suivants :
  - **Overview** : Tableau de toutes les apps avec pod status (Running/CrashLoop/Pending), uptime, dernière restart
  - **Resources** : CPU/Memory par app (requiert les `resources` définis dans `apps.yaml`)
  - **Database** : Taille DB par app, connections actives, dernière backup CNPG
  - **Storage** : Utilisation PVC par app (% rempli)
  - **Tunnel** : Latence Cloudflare par hostname (si les métriques sont disponibles)
- [ ] Le dashboard est **généré par Pulumi** à partir des données de `apps.yaml` (pas maintenu manuellement)
- [ ] Protéger Grafana derrière Authentik (mode: protected, SSO OIDC pour login auto)

### Out of scope
- Alerting (couvert par la spec `alerting-auto.md`)
- Dashboards custom par app (Nextcloud, Authentik ont leurs propres dashboards)
- Métriques applicatives custom (seulement les métriques K8s/infra standard)
- Logging centralisé (Loki/ELK — spec séparée si besoin)

## Contraintes
- Secrets via Doppler uniquement (jamais en dur)
- Définir les apps dans apps.yaml, pas en Python
- Tout passe par Pulumi (pas de kubectl apply direct)
- Grafana doit être léger (pas de base de données dédiée, utiliser SQLite ou la DB CNPG partagée)
- Le dashboard JSON doit être versionné en tant que ConfigMap, pas édité dans l'UI

## Critères d'acceptance
- [ ] `uv run pulumi preview --stack oci` passe sans erreur
- [ ] `uv run pytest tests/static/ -v` passe
- [ ] Grafana est accessible via `grafana.smadja.dev` avec SSO Authentik
- [ ] Le dashboard "Homelab Overview" existe et montre toutes les apps de `apps.yaml`
- [ ] Chaque app a un panel montrant le pod status et le resource usage
- [ ] Le dashboard se met à jour automatiquement quand on ajoute une app dans `apps.yaml`

## Fichiers concernés
- `kubernetes-pulumi/apps.yaml` — ajouter Grafana comme app
- `kubernetes-pulumi/shared/apps/common/registry.py` — optionnel : méthode pour générer le dashboard JSON
- `kubernetes-pulumi/shared/apps/impl/grafana.py` — optionnel : app spécialisée pour générer le ConfigMap dashboard
- `kubernetes-pulumi/k8s-apps/__main__.py` — déployer Grafana dans la boucle standard

## Notes / Références
- Grafana provisioning via ConfigMaps : https://grafana.com/docs/grafana/latest/administration/provisioning/#dashboards
- kube-prometheus-stack inclut Grafana — vérifier si on peut l'utiliser directement
- Les métriques K8s standard (kube-state-metrics, node-exporter) sont probablement déjà disponibles si prometheus-stack est déployé
- Dashboard JSON peut être généré avec la lib Python `grafanalib` ou en construisant le JSON directement
