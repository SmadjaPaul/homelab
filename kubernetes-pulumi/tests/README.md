# Homelab Testing Architecture

Notre stratégie de tests repose sur une validation multi-niveau (Fail-Fast) pour garantir qu'aucune erreur de configuration ne puisse casser l'infrastructure en production.

## 🧠 Philosophie (Le Pipeline)

Les tests sont conçus pour s'exécuter de gauche à droite, du plus rapide (et isolé) au plus lent (sur un vrai cluster).

1. **Static** : Code / Configuration (Pas de cluster requis)
2. **Unit** : Logique métier Python interne
3. **Dynamic** : Interaction de base (Le cluster existe)
4. **Integration** : Ressources complexes et APIs Cloud externes
5. **E2E (Kuttl)** : Comportement des applications (Le vrai test utilisateur)

---

## 📂 Structure des Tests (Pytest)

### 1. `static/` (Pre-flight Checks)
- **Objectif** : Valider que le code Pulumi et les manifests Helm ne contiennent pas d'erreurs **avant** de toucher le cluster.
- **Ce qui est testé** : Syntaxe YAML, dépendances croisées, correspondances avec les secrets Doppler, rendu des templates Helm.
- **Quand l'utiliser** : En local avant un commit, ou à chaque Push dans la CI.

### 2. `unit/` (Logique Python)
- **Objectif** : Valider les classes et fonctions internes de `shared/`.
- **Ce qui est testé** : Analyse du DAG de dépendances, détection de cycles, parsing du `apps.yaml`.

### 3. `dynamic/` (Live Verification)
- **Objectif** : Vérifier que les promesses déclaratives ("l'application a une route") se traduisent par une réalité (le endpoint HTTP répond). La génération des tests est dynamique selon `apps.yaml`.
- **Ce qui est testé** : Routage HTTP (200/302), santé réseau (NetworkPolicy).
- **Quand l'utiliser** : Après un `pulumi up` pour s'assurer que les pods ont bien démarré et sont accessibles.

### 4. `integration/` (External APIs)
- **Objectif** : Tester la création et la destruction de ressources sur des fournisseurs Cloud externes ou complexes.
- **Exemple** : Script qui appelle l'API Hetzner Cloud pour créer un sous-compte StorageBox, vérifie l'accès WebDAV/FTP, puis le supprime.
- **Quand l'utiliser** : De manière planifiée (cron) ou en développement lors du changement des scripts d'infrastructure Storage/Cloudflare.

---

## 🚜 Tests de Bout-en-Bout (E2E) - Kuttl

### `e2e/` (Kuttl Tests)
- **Objectif** : L"E2E" (End-to-End) en Kubernetes consiste à vérifier l'état réel et final des ressources après que tous les contrôleurs aient fait leur travail.
- **Outil** : [Kuttl](https://kuttl.dev/) (KUbernetes Test TooL).
- **Philosophie** : Au lieu d'écrire du Python, vous écrivez du YAML métier. Kuttl déploie des manifests (`00-install.yaml`), attend, puis vérifie que l'état du cluster (`00-assert.yaml`) correspond exactement à ce qui est attendu.
- **Exemple** : Mettre un fichier `apps.yaml` expérimental, et Kuttl vérifiera que les Pods démarrent bien, que les PVCs sont correctement bindés et que les namespaces sont créés.
- **Quand l'utiliser** : En environnement de Staging ou minikube, pour valider que vos Helm Charts custom ou vos opérateurs fonctionnent vraiment.

---

## ⏱️ Performance & Bottlenecks

Voici les temps d'exécution moyens constatés :

| Catégorie | Temps (Moyen) | Bottlenecks / Risques |
| :--- | :--- | :--- |
| **Static** | ~180s (3m) | **Lent** : `test_helm_manifests.py` car il lance `helm template` pour chaque application. |
| **Unit** | < 1s | Très rapide, idéal pour le feedback immédiat. |
| **Dynamic** | ~100s (1m 40) | Dépend de la latence réseau et de la santé du cluster. |
| **Integration** | ~30s | Dépend de la propagation DNS/Cloud APIs (Hetzner). |

> [!TIP]
> Pour accélerer les tests **Static**, vous pouvez utiliser `pytest -n auto` (si `pytest-xdist` est installé) pour paralléliser le rendu des templates Helm.

## 🚀 Comment lancer les tests

**Installation des prérequis :**
```bash
pip install pytest pytest-xdist requests tenacity
brew install kuttl
```

**Lancer les tests rapides (Static + Unit) :**
```bash
pytest tests/static tests/unit -v
```

**Lancer la vérification applicative sur le cluster actif (Dynamic) :**
```bash
pytest tests/dynamic -v
```

**Lancer les tests système E2E (Kuttl) :**
```bash
kubectl kuttl test --config tests/e2e/kuttl.yaml
```

> [!IMPORTANT]
> **Zero-Modification Policy** : Lors de l'ajout d'une nouvelle application dans `apps.yaml`, les tests `static` et `dynamic` se mettent à jour **automatiquement**. Vous n'avez plus besoin de modifier les fichiers de tests Python, sauf pour des fonctions très spécifiques non-standard.
