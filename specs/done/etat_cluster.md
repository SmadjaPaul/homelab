# Spec: Stabilisation et Optimisation du Cluster OCI

## Contexte
Le cluster est actuellement déployé mais plusieurs services présentent des erreurs fonctionnelles (clés API manquantes, erreurs d'authentification SSO, erreurs 502) et l'utilisation du stockage OCI doit être optimisée pour respecter les limites "Always Free".

## Objectif
Résoudre les problèmes d'accès et de configuration des applications et consolider le stockage Block Volume pour rester sous la limite des 200 Go.

## Scope

### In scope
- [ ] **ROMM** : Configurer les clés API via Doppler (IGDB, MobyGames, ScreenScrapper, SteamgridDB).
- [ ] **ROMM** : Corriger l'erreur de `redirect_uri` dans Authentik.
- [ ] **Vaultwarden** : Résoudre le problème d'authentification (identifiants incorrects).
- [ ] **Paperless-ngx** : Créer le compte utilisateur `paul@smadja.dev` (ou synchroniser via SSO).
- [ ] **Open Web UI** : Corriger les permissions d'accès à `/auth`.
- [ ] **Services 502** : Diagnostiquer et réparer Audiobookshelf, Navidrome, Soulseek et Nextcloud (Cloud).
- [ ] **Immich** : Monter en version (v1.117.0 -> vX.Y.Z stable récente). *Note: v2.6.1 semble être la version actuelle*
- [ ] **Storage** : Consolider les 3 Block Volumes de 50 Go actuels en 2 volumes partagés pour respecter la limite OCI de 200 Go total (incluant 100 Go de boot).

## État actuel des services (Mise à jour)
**Fonctionnels :**
- Audiobookshelf
- Homepage
- Paperless-ngx

**Problèmes de SSO (Page de login au lieu de l'auto-provisioning) :**
- Vaultwarden
- Navidrome
- Soulseek (Slskd)
- ROMM

**Timeout :**
- Immich

**Erreur 502 Bad Gateway (Cloudflare) :**
- Nextcloud

**Erreur 500 Internal Error :**
- Open Web UI


### Out of scope
- Migration vers un autre fournisseur de cloud.
- Refonte complète de l'architecture réseau.

## Contraintes
- Secrets via Doppler uniquement (jamais en dur).
- Définir les apps dans `apps.yaml`, pas en Python.
- Tout passe par Pulumi (pas de `kubectl apply` direct).
- Respecter la limite OCI de 200 Go total (incluant le boot volume de 100 Go).

## Critères d'acceptance
- [ ] Les 4 intégrations metadata de ROMM sont fonctionnelles (Check vert).
- [ ] Le login Authentik fonctionne pour ROMM, Paperless et Open Web UI.
- [ ] Tous les services (Audiobookshelf, Navidrome, Soulseek, Cloud) sont accessibles sans erreur 502.
- [ ] Immich affiche une version à jour (> v1.117.0).
- [ ] Seuls 2 Block Volumes additionnels de 50 Go sont présents sur OCI.

## Fichiers concernés
- `kubernetes-pulumi/apps.yaml`
- `kubernetes-pulumi/shared/apps/common/kubernetes_registry.py` (si ajustements de provisioning nécessaires)

## Notes / Références
- État actuel des volumes OCI :
  - `csi-85819f50...` : 50 Go
  - `csi-56e54dc7...` : 50 Go (Always Free)
  - `csi-4b6a968f...` : 50 Go (Always Free)
- Total utilisé : 150 Go + 100 Go (Boot) = 250 Go (Dépassement de 50 Go des limites gratuites).
