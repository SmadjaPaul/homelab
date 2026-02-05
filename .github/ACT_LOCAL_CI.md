# Tests CI locaux avec act

[act](https://github.com/nektos/act) permet de lancer les GitHub Actions localement pour débugger et tester avant de push.

## Installation

```bash
brew install act
```

## Utilisation

Le script `./scripts/act-run.sh` récupère automatiquement les secrets depuis OCI Vault et les passe à `act`.

```bash
# Lister les workflows disponibles
./scripts/act-run.sh -l

# Lancer un workflow spécifique
./scripts/act-run.sh -W .github/workflows/terraform-cloudflare.yml

# Lancer un job spécifique
./scripts/act-run.sh -W .github/workflows/terraform-cloudflare.yml -j validate

# Lancer avec un événement spécifique
./scripts/act-run.sh -W .github/workflows/terraform-oci.yml --eventpath /dev/stdin <<< '{"inputs":{"action":"plan"}}'

# Mode dry-run (voir ce qui serait exécuté)
./scripts/act-run.sh -n
```

## Prérequis

1. **Docker** doit être lancé
2. **OCI CLI** configuré (`~/.oci/config`)
3. **Secrets OCI Vault** peuplés (`./scripts/oci-vault-secrets-setup.sh --list`)

## Comment ça fonctionne

```
┌──────────────────────────────────────────────────────────────┐
│                    ./scripts/act-run.sh                       │
├──────────────────────────────────────────────────────────────┤
│  1. Récupère secrets depuis OCI Vault                        │
│  2. Génère .secrets.act (temporaire, supprimé après)         │
│  3. Lance act avec --secret-file .secrets.act                │
│  4. Nettoie .secrets.act à la fin                            │
└──────────────────────────────────────────────────────────────┘
```

## Secrets disponibles

Le script récupère ces secrets depuis OCI Vault et les expose à `act` :

| Variable | Source |
|----------|--------|
| `CLOUDFLARE_API_TOKEN` | OCI Vault: `homelab-cloudflare-api-token` |
| `OMNI_DB_USER` | OCI Vault: `homelab-omni-db-user` |
| `OMNI_DB_PASSWORD` | OCI Vault: `homelab-omni-db-password` |
| `OMNI_DB_NAME` | OCI Vault: `homelab-omni-db-name` |
| `OCI_MGMT_SSH_PRIVATE_KEY` | OCI Vault: `homelab-oci-mgmt-ssh-private-key` |
| `OCI_CLI_*` | `~/.oci/config` |
| `OCI_SESSION_TOKEN` | `~/.oci/session_token` |
| `OCI_SESSION_PRIVATE_KEY` | `~/.oci/session_key.pem` |
| `SSH_PUBLIC_KEY` | `~/.ssh/oci-homelab.pub` |

## Limitations

- **Temps d'exécution** : La première exécution télécharge l'image Docker (~2GB)
- **Composite actions** : Les actions locales (`.github/actions/`) fonctionnent
- **Environnements GitHub** : Pas supportés, les secrets sont passés directement
- **GITHUB_TOKEN** : Limité, certaines API GitHub ne fonctionnent pas

## Dépannage

### Docker non lancé

```
Error: Docker is not running
```

→ Lancer Docker Desktop

### Secrets manquants

```
Warning: Secret not found: homelab-xxx
```

→ Peupler les secrets : `./scripts/oci-vault-secrets-setup.sh`

### Session OCI expirée

```
Error: The token is expired
```

→ Régénérer le session token : `./scripts/oci-session-auth-to-gh.sh`

## Configuration

Le fichier `.actrc` à la racine du projet configure les options par défaut :

```
# Image runner (ubuntu-latest)
-P ubuntu-latest=catthehacker/ubuntu:act-latest

# Réutiliser les containers
--reuse

# Bind workspace
--bind
```
