Revue d'Architecture et Recommandations (Homelab V1.0)
Suite à l'analyse approfondie de votre infrastructure basées sur Pulumi (kubernetes-pulumi), voici un retour global sur l'architecture, ainsi que des recommandations concrètes pour améliorer la lisibilité, la logique et la stabilité du code.

🌟 Points Forts de l'Architecture Actuelle
Déclaratif Fort (

apps.yaml
 +

schemas.py
) : L'utilisation de Pydantic pour valider l'intégralité de la configuration ("Fail-Fast" type-checking) est une excellente pratique. Cela évite les surprises à l'exécution de Pulumi.
Gestion des Secrets Fail-Fast (

registry.py
) : La vérification synchrone des clés dans Doppler avant même de créer les ExternalSecrets garantit que l'infrastructure ne démarre jamais dans un état hybride cassé.
Zero Trust NetworkPolicies (

base.py
) : L'approche "Default-Deny" par application, avec ouvertures explicites (

dependencies
,

cloudflared
,

authentik_outpost
), démontre une posture de sécurité mature.
Auto-Provisionnement OIDC : Le chaînage dynamique entre

AppRegistry
 et Authentik pour générer les Providers/Applications à la volée est très élégant.
🛠️ Recommandations d'Amélioration
1. Lisibilité et Maintenabilité (Refactoring)
Problème A : Le fichier

generic.py
 est monolithique et trop intelligent. La méthode

get_final_values()
 fait plus de 200 lignes et contient une multitude de conditions (if app_name == "authentik", if is_v3 (app-template), if app_name == "homarr"). Elle tente d'injecter la persistance et les variables d'environnement dans des structures YAML radicalement différentes.

Recommandation : Implémenter le patron de conception Strategy / Adapter pour les Helm Charts. Créez un dossier shared/apps/adapters/ avec des classes par défaut (AppTemplateV3Adapter, AppTemplateV2Adapter, AuthentikAdapter, StandardAdapter). Ainsi,

GenericHelmApp
 délègue l'injection à l'adapteur approprié, réduisant drastiquement les conditions imbriquées.

Problème B :

registry.py
 viole le principe de responsabilité unique (SRP). Ce fichier gère à la fois les RBAC, le monitoring, les instances de Base de Données, et les appels APIs vers l'IdP (Authentik).

Recommandation : Découper

registry.py
. Par exemple, extraire la logique Authentik dans un AuthentikRegistry (

configure_authentik_layer
 et

finalize_authentik_outpost
) et la logique Kubernetes de base dans un KubernetesRegistry (

_setup_rbac_for_app
,

_setup_monitoring_for_app
).

Problème C : Pollution de

main
.py
 (Stack Apps) Dans

k8s-apps/
main
.py
, toute la configuration DNS statique pour migadu (domaines, MX, SPF, DKIM) est codée en dur au milieu du flux de configuration des Tunnels Cloudflare.

Recommandation : Extraire cette logique dans un module shared.networking.cloudflare.MailDnsManager pour garder le point d'entrée (

main
.py
) purement orchestrateur.

2. Logique et Robustesse
Problème D : Fausse validation de dépendance Pulumi dans

generic.py
. Lors de la création de mots de passe aléatoires locaux (auto_secrets), des objets K8s

Secret
 sont générés, mais la Helm Release de l'application n'a pas de depends_on=[auto_k8s_secret] explicite. Si Helm démarre ses pods plus vite que l'objet

Secret
 n'est poussé par l'API Kubernetes, les pods tomberont en CreateContainerConfigError.

Recommandation : À la fin de

deploy_components
 dans

generic.py
, ajouter auto_secret_resources à la liste release_depends_on.

Problème E : Accès réseau pour les initContainers (Base de données). Si l'application est dans le namespace media et que la base CNPG est dans databases, l'initContainer wait-for-database risque d'être bloqué par le NetworkPolicy "Default-Deny" si databases n'est pas déclaré explicitement dans les

dependencies
.

Recommandation : Dans

base.py
 (NetworkPolicyBuilder), si app.database.local est True, injecter silencieusement ou obligatoirement une règle d'egress vers le port 5432 de l'hôte ${app_name}-db-rw.databases.svc.cluster.local.

3. Stabilité et Déploiement
Problème F : Ignorer l'attente des Helm Charts (skip_await=True). Dans

generic.py
, le déploiement Helm passe skip_await=True. Cela accélère grandement pulumi up, mais Pulumi considèrera le déploiement comme un succès même si l'image Docker crashe en boucle (CrashLoopBackOff) ou que l'application manque un secret vital.

Recommandation : Pour un environnement de Production (V1.0), passer skip_await=False (le défaut). Pulumi attendra que les pods passent en condition Ready. Cela double le temps de déploiement, mais vous assure que ce qui est rapporté "Succès" fonctionne réellement.

Problème G : Nommage statique dans Cloudflare Tunnel. Dans l'Ingress Cloudflare (

main
.py
), les routes vers Authentik Outpost sont hardcodées : http://ak-outpost-authentik-embedded-outpost.authentik.svc.cluster.local:9000. Si une mise à jour mineure d'Authentik change ce nommage Helm interne, votre accès Outpost cassera mondialement.

Recommandation : Utiliser les Outputs de ressources (par exemple, récupérer le nom du service généré dynamiquement lors du déploiement de l'Outpost) ou consolider cette information comme une variable importée depuis la stack

core
.

🧪 Revue de l'Architecture des Tests (kubernetes-pulumi/tests)
Votre structure de tests est très bien pensée avec une séparation claire des responsabilités (static, dynamic, integration, e2e). L'utilisation de conftest.py pour charger dynamiquement la configuration depuis apps.yaml (DRY) est excellente.

Cependant, voici quelques points d'amélioration pour rendre la suite de tests plus robuste :

Problème H : test_storagebox_subaccount.py n'est pas un vrai test Pytest. Ce fichier d'intégration s'exécute comme un script standalone (if __name__ == "__main__": run()) et fait sa propre gestion d'erreurs/nettoyage. Si une assertion échoue au milieu, le compte de sous-stockage Hetzner n'est pas supprimé (fuite de ressources).

Recommandation : Refactoriser ce fichier en utilisant les Fixtures Pytest (yield). La création du sous-compte doit se faire au début de la fixture, avec un yield bloc, et le nettoyage (DELETE) juste après, garantissant la suppression même en cas d'échec du test. De plus, remplacez urllib et subprocess.run(['curl']) par la librairie requests pour améliorer grandement la lisibilité du code Python.

Problème I : Risque concurrentiel (Race Condition) dans test_helm_manifests.py. Pour valider les manifests statiques, le test écrit dans un fichier en dur : /tmp/values-{app_name}.yaml. Si vous exécutez les tests en parallèle (ex: pytest -n auto avec xdist) pour gagner du temps, les tests se marcheront dessus ou le fichier sera effacé prématurément.

Recommandation : Utiliser la fixture native tmp_path de Pytest pour générer des fichiers temporaires uniques et isolés pour chaque exécution de fonction.

Problème J : Flakiness du test dynamique de routage (test_routing_auto.py). Le test se contente de faire une seule requête HTTP via urllib et s'attend à un retour 200/302. Lors d'un déploiement fresh, les ingress Cloudflare ou les pods peuvent mettre quelques secondes à démarrer (retournant temporairement des 502/503).

Recommandation : Remplacer l'approche "One-shot" par une logique de "Retry" robuste, idéalement avec la librairie tenacity (ex: # @retry(stop=stop_after_attempt(5), wait=wait_fixed(2))) et requests.

Problème K : Utilisation de Kuttl (E2E) dans un contexte GitOps/Pulumi. La suite de tests inclut un dossier e2e utilisant kuttl, qui est un outil déclaratif YAML pour tester des flux Kubernetes (créer un Pod, vérifier qu'un PVC est bindé). Dans sa version actuelle, l'infrastructure est pilotée par Pulumi, ce qui rend l'intérêt de Kuttl mineur pour l'environnement de production. En effet, Pulumi avec skip_await=False fait déjà le travail (il plante si un PVC ne bound pas). Par conséquent, les tests E2E via Kuttl pourraient se révéler redondants ou difficiles à maintenir par rapport aux tests dynamiques Pytest.

Recommandation : Évaluer l'utilité réelle de Kuttl. Si vous souhaitez vérifier la fonctionnalité interne d'un composant (comme "est-ce que Traefik achemine vraiment la requête avec le bon Header"), oui. Mais pour vérifier que "le Namespace existe" ou "le PVC est Bindé", Pulumi est déjà responsable et garant de l'état. Vous devriez envisager de scoper Kuttl uniquement aux comportements complexes d'opérateurs métiers si vous en créez un jour.

Problème L : Duplication inutile de l'approche dynamique (*_auto.py). Dans le dossier tests/dynamic, il y a une redondance évidente entre test_network.py et test_network_auto.py (même chose pour routing et secrets). Les fichiers nommés _auto.py testent l'ensemble de vos applications via une boucle for à l'intérieur d'un seul test Pytest. Si une seule application échoue, la boucle s'arrête, cachant l'état des autres. À l'inverse, les tests normaux (test_network.py) utilisent test_case (Paramétrisation Pytest), ce qui génère un test totalement isolé par application.

Recommandation : Supprimer complètement tous les fichiers *_auto.py. S'ils contiennent des assertions uniques (ex: test_dependency_policies_exist), fusionnez ce bloc de code dans le fichier standard paramétré.

Problème M : Violation de la règle "Zero-Modification" pour de nouvelles applications (test_deployment_readiness.py). Dans l'objectif initial de ne jamais toucher aux tests lorsqu'on ajoute une application dans apps.yaml, certains tests trichent en hardcodant des configurations métier :

La fonction test_critical_apps_have_timeout_config a une liste hardcodée : slow_apps = {"authentik", "vaultwarden", "navidrome"}. Si vous ajoutez Nextcloud, ce test ne s'appliquera pas.
La classe TestIngressClassValidation a une liste hardcodée KNOWN_INGRESS_CLASSES = {"cloudflare-tunnel", "envoy-gateway", "nginx"}.
Recommandation : Au lieu de hardcoder slow_apps, ajoutez un nouveau champ optionnel dans le schéma AppTestConfig (schemas.py) : requires_extended_timeout: bool = False. Puis, dans le test, basez-vous factuellement sur le booléen app.test.requires_extended_timeout tiré depuis le YAML.

Note sur test_preflight.py : Ce fichier d'intégration hardcode la vérification des CRDs (ex: clusters.postgresql.cnpg.io). Cela est parfaitement moral, car il s'agit d'un test qui vérifie les fondations d'infrastructure (Core) du noeud, et non une application métier dynamique. Il doit conserver son aspect rigide.
