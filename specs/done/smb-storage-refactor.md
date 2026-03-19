# Spec: Refactorisation SMB Storage — apps.yaml comme source de vérité

## Contexte

Session de debug du 2026-03-20 : les 14 PVs SMB étaient down. La résolution a nécessité ~15 interventions manuelles (suppression de finalizers, rotation de credentials, correction de hostname/IP, relance de Pulumi, restart de pods). Causes racines identifiées :

1. **Hostname hardcodé et incohérent** : l'IP `91.98.241.77` correspondait au mauvais storagebox (`u537179`), alors que les credentials sont pour `u554589`. L'`hcloud_storage_box_id` (537179) est l'ID API Hetzner, pas le username SMB (554589) — aucun endroit dans le code ne stocke le hostname SMB.

2. **Share path `/backup` manquant pour comptes jaillés** : le paramètre `is_jailed` supprimait `/backup` du prefix, mais tous les sub-accounts accèdent au share `backup` — le jailing est transparent côté Hetzner.

3. **PVs immutables sans `deleteBeforeReplace`** : chaque changement de `source` SMB nécessite de supprimer manuellement les PVs (patch finalizers + kubectl delete) avant que Pulumi puisse les recréer.

4. **14 appels `make_smb_pv` hardcodés** : les volumes SMB sont définis en Python (`k8s-storage/__main__.py` L175-188) au lieu de `apps.yaml`. L'ajout d'un volume nécessite de modifier 3 endroits : `SMB_APP_ACCOUNTS`, `make_smb_pv`, et `apps.yaml`.

5. **Credentials désynchronisées silencieusement** : les `RandomPassword` + `StorageBoxSubaccount` créés par Pulumi n'ont aucune validation. Un password désynchronisé entre Hetzner et le K8s Secret = pods bloqués indéfiniment en `ContainerCreating` sans alarme.

6. **`SMB_APP_ACCOUNTS` et `make_smb_pv` découplés** : aucune validation que le secret référencé par un PV existe ou correspond au bon sub-account. Le lien `(app, home_dir)` ↔ `(pv_name, pvc_name, smb_path, secret_name)` est implicite via des conventions de nommage.

## Objectif

Toute la configuration SMB est déclarée dans `apps.yaml` et le code Python est générique : ajouter un volume SMB ne nécessite que de modifier `apps.yaml`.

## Scope

### In scope
- [ ] Ajouter le hostname SMB storagebox dans `apps.yaml` (champ `hcloud_storage_box_hostname`)
- [ ] Déclarer les sub-accounts SMB et leurs volumes dans `apps.yaml` (nouvelle section `storagebox`)
- [ ] Supprimer `SMB_APP_ACCOUNTS` et les 14 appels `make_smb_pv` hardcodés de `k8s-storage/__main__.py`
- [ ] Créer une classe `StorageBoxOrchestrator` qui lit `apps.yaml` et provisionne sub-accounts + PVs + secrets
- [ ] Ajouter `deleteBeforeReplace: True` sur tous les PVs SMB
- [ ] Supprimer le paramètre `is_jailed` (share `/backup` pour tous)
- [ ] Ajouter un test statique validant la cohérence du YAML (sub-accounts ↔ volumes)
- [ ] Ajouter un test dynamique vérifiant les credentials SMB post-deploy
- [ ] Parser le schema `storagebox` dans `schemas.py` (pydantic)

### Out of scope
- Migration des données sur le storagebox (structure des répertoires)
- Nextcloud External Storage (couvert par `unified-storage.md`)
- Ajout de nouvelles apps (Immich, RomM) — cette spec refactore l'existant

## Design

### 1. Nouveau schema `apps.yaml`

```yaml
# Top-level : identifiants du Hetzner Storage Box
hcloud_storage_box_id: 537179                         # ID API Hetzner (pour créer les sub-accounts)
hcloud_storage_box_hostname: u554589.your-storagebox.de  # hostname SMB (pour les mounts)

# Déclaration des sub-accounts et de leurs volumes
storagebox:
  # Sub-accounts isolés (1 sub-account = 1 jeu de credentials = 1 secret K8s)
  accounts:
    - name: immich
      home_directory: immich
      volumes:
        - pv_name: pv-immich-library
          pvc_name: immich-library
          namespace: photography
          smb_path: /library/
          size: 2Ti

    - name: paperless
      home_directory: paperless
      volumes:
        - pv_name: pv-paperless-data
          pvc_name: paperless-ngx-data
          namespace: productivity
          smb_path: /data/
        - pv_name: pv-paperless-media
          pvc_name: paperless-ngx-media
          namespace: productivity
          smb_path: /media/
          size: 100Gi
        - pv_name: pv-paperless-export
          pvc_name: paperless-ngx-export
          namespace: productivity
          smb_path: /export/
        - pv_name: pv-paperless-consume
          pvc_name: paperless-ngx-consume
          namespace: productivity
          smb_path: /consume/

    - name: media-ro
      home_directory: shared
      volumes:
        - pv_name: pv-navidrome-music
          pvc_name: navidrome-music
          namespace: music
          smb_path: /music/
        - pv_name: pv-slskd-config
          pvc_name: slskd-config
          namespace: music
          smb_path: /slskd/
        - pv_name: pv-audiobookshelf
          pvc_name: audiobookshelf-data
          namespace: media
          smb_path: /audiobooks/

    - name: romm
      home_directory: romm
      volumes:
        - pv_name: pv-romm-library
          pvc_name: romm-library
          namespace: gaming
          smb_path: /library/
          size: 1Ti
        - pv_name: pv-romm-assets
          pvc_name: romm-assets
          namespace: gaming
          smb_path: /assets/
          size: 100Gi
        - pv_name: pv-romm-resources
          pvc_name: romm-resources
          namespace: gaming
          smb_path: /resources/
          size: 100Gi

    - name: authentik
      home_directory: authentik
      volumes:
        - pv_name: pv-authentik-data
          pvc_name: authentik-data
          namespace: authentik
          smb_path: /data/
          size: 10Gi

    - name: vaultwarden
      home_directory: vaultwarden
      volumes:
        - pv_name: pv-vaultwarden-data
          pvc_name: vaultwarden-data
          namespace: vaultwarden
          smb_path: /data/
          size: 10Gi

  # Compte principal (accès racine, credentials via Doppler/ExternalSecret)
  main_account:
    secret_name: smb-nextcloud
    doppler_user_key: HETZNER_STORAGE_BOX_1_USER
    doppler_pass_key: HETZNER_STORAGE_BOX_1_PASS
    volumes:
      - pv_name: pv-nextcloud-data
        pvc_name: nextcloud-data
        namespace: productivity
        smb_path: /nextcloud/data/
        size: 2Ti
```

### 2. Schema Pydantic (`schemas.py`)

```python
class StorageBoxVolume(BaseModel):
    pv_name: str
    pvc_name: str
    namespace: str
    smb_path: str
    size: str = "500Gi"

class StorageBoxAccount(BaseModel):
    name: str
    home_directory: str
    volumes: List[StorageBoxVolume]

class StorageBoxMainAccount(BaseModel):
    secret_name: str
    doppler_user_key: str
    doppler_pass_key: str
    volumes: List[StorageBoxVolume]

class StorageBoxConfig(BaseModel):
    accounts: List[StorageBoxAccount]
    main_account: Optional[StorageBoxMainAccount] = None
```

### 3. `StorageBoxOrchestrator` (nouvelle classe, remplace tout le code impératif)

Responsabilités :
- Lit `StorageBoxConfig` depuis `apps.yaml`
- Pour chaque `account` : crée `RandomPassword` → `StorageBoxSubaccount` → `Secret` K8s
- Pour chaque `volume` dans chaque account : crée PV + PVC avec `deleteBeforeReplace=True`
- Pour `main_account` : crée `ExternalSecret` + PVs/PVCs
- Le source SMB est toujours : `//{ hostname }/backup/{ smb_path }`

```python
# k8s-storage/__main__.py — remplacement de ~80 lignes par :
orchestrator = StorageBoxOrchestrator(
    hostname=raw_config["hcloud_storage_box_hostname"],
    storage_box_id=raw_config["hcloud_storage_box_id"],
    config=storagebox_config,    # StorageBoxConfig parsé depuis apps.yaml
    provider=provider,
)
```

### 4. ResourceOptions sur les PVs

```python
opts=pulumi.ResourceOptions(
    provider=provider,
    delete_before_replace=True,   # ← élimine les erreurs "immutable"
    parent=sub_account,           # ← dépendance explicite sur le sub-account
)
```

### 5. Tests

**Test statique** (`tests/static/test_storagebox_config.py`) :
- Tous les `pv_name` sont uniques
- Tous les `pvc_name` sont uniques
- Tous les `namespace` existent dans les apps déclarées
- Chaque `smb_path` commence par `/`
- Pas de `home_directory` dupliqué entre sub-accounts

**Test dynamique** (`tests/dynamic/test_smb_credentials.py`) :
- Pour chaque secret `smb-*` dans `kube-system` : vérifier que le username/password permet une connexion WebDAV (HTTP 200) vers `https://{ hostname }/`
- Prérequis : activer `webdav_enabled=True` dans `AppStorageBoxProvisioner.access_settings`

## Contraintes
- Secrets via Doppler uniquement pour le compte principal (les sub-accounts utilisent RandomPassword Pulumi)
- Tout passe par Pulumi — pas de kubectl apply direct
- `apps.yaml` = source de vérité — le code Python ne contient aucune valeur hardcodée de PV/PVC/path
- Le refactoring ne doit PAS supprimer les PVs existants (les données sont en `Retain`) — uniquement changer comment ils sont provisionnés
- Le hostname SMB est **distinct** de l'ID API Hetzner — ne jamais dériver l'un de l'autre

## Critères d'acceptance
- [ ] `uv run pulumi preview --stack oci` passe sans erreur
- [ ] `uv run pytest tests/static/ -v` passe (incluant le nouveau test de cohérence)
- [ ] Ajouter un volume SMB ne nécessite que de modifier `apps.yaml` (zéro changement Python)
- [ ] Changer le hostname storagebox ne nécessite que de modifier `apps.yaml` + `pulumi up`
- [ ] Les PVs sont recréés automatiquement par Pulumi lors d'un changement de `source` (pas de suppression manuelle)
- [ ] Le test dynamique valide les credentials de tous les sub-accounts

## Fichiers concernés

### Créer
- `kubernetes-pulumi/shared/apps/common/storagebox_orchestrator.py` — nouvelle classe `StorageBoxOrchestrator`
- `kubernetes-pulumi/tests/static/test_storagebox_config.py` — tests de cohérence YAML
- `kubernetes-pulumi/tests/dynamic/test_smb_credentials.py` — tests de credentials post-deploy

### Modifier
- `kubernetes-pulumi/apps.yaml` — ajouter section `storagebox` + champ `hcloud_storage_box_hostname`
- `kubernetes-pulumi/shared/utils/schemas.py` — ajouter `StorageBoxVolume`, `StorageBoxAccount`, `StorageBoxConfig`
- `kubernetes-pulumi/k8s-storage/__main__.py` — remplacer `SMB_APP_ACCOUNTS` + `make_smb_pv` + ExternalSecret par appel à `StorageBoxOrchestrator`
- `kubernetes-pulumi/shared/apps/common/storagebox.py` — activer `webdav_enabled=True` dans `AppStorageBoxProvisioner`

### Supprimer (code mort après refactor)
- `make_smb_pv()` dans `k8s-storage/__main__.py`
- `SMB_APP_ACCOUNTS` dans `k8s-storage/__main__.py`
- Le bloc `ExternalSecret` inline pour `smb-nextcloud` dans `k8s-storage/__main__.py`

## Plan d'implémentation

1. **Schema** : ajouter les modèles Pydantic dans `schemas.py`, parser la nouvelle section `storagebox` dans `AppLoader`
2. **YAML** : migrer la configuration hardcodée vers `apps.yaml` (section `storagebox`)
3. **Orchestrator** : créer `StorageBoxOrchestrator` avec sub-accounts + PVs + secrets
4. **Intégration** : remplacer le code impératif dans `k8s-storage/__main__.py` par l'orchestrator
5. **Tests statiques** : test de cohérence du YAML
6. **Validation** : `pulumi preview` + `pulumi up` + vérification que les pods montent correctement
7. **Tests dynamiques** : ajout du test de credentials WebDAV

## Notes / Références
- Session de debug : conversation Claude 2026-03-20
- Specs liées : `specs/wip/unified-storage.md` (architecture cible), `specs/wip/unified-storage-implementation-plan.md` (plan d'implémentation Phase 1 = cette spec)
- Doc Hetzner Storage Box : share SMB = toujours `/backup`, jailing transparent pour sub-accounts
- Hetzner API ID (537179) ≠ username SMB (u554589) — ne pas confondre
