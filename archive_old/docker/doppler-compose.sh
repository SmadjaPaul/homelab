#!/bin/bash
# Doppler Docker Compose Wrapper
# Usage: ./doppler-compose.sh [project] [docker-compose-args]
# Example: ./doppler-compose.sh arm up -d

set -e

PROJECT=${1:-default}
shift || true

# Map project names to Doppler projects
 case $PROJECT in
  arm)
    DOPPLER_PROJECT="apps"
    CONFIG="arm"
    ;;
  db-server)
    DOPPLER_PROJECT="databases"
    CONFIG="db-server"
    ;;
  blocky-ha)
    DOPPLER_PROJECT="infrastructure"
    CONFIG="blocky"
    ;;
  ark-ripper)
    DOPPLER_PROJECT="apps"
    CONFIG="ark-ripper"
    ;;
  kasm)
    DOPPLER_PROJECT="apps"
    CONFIG="kasm"
    ;;
  npm|nginx-proxy-manager)
    DOPPLER_PROJECT="infrastructure"
    CONFIG="npm"
    ;;
  ollama)
    DOPPLER_PROJECT="apps"
    CONFIG="ollama"
    ;;
  ubu)
    DOPPLER_PROJECT="apps"
    CONFIG="ubu"
    ;;
  wazuh)
    DOPPLER_PROJECT="monitoring"
    CONFIG="wazuh"
    ;;
  proxy)
    DOPPLER_PROJECT="infrastructure"
    CONFIG="proxy"
    ;;
  *)
    echo "Unknown project: $PROJECT"
    echo "Available projects: arm, db-server, blocky-ha, ark-ripper, kasm, npm, ollama, ubu, wazuh, proxy"
    exit 1
    ;;
esac

# Check if Doppler CLI is installed
if ! command -v doppler &> /dev/null; then
    echo "Doppler CLI not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install doppler
    else
        (curl -Ls --tlsv1.2 --proto "=https" --retry 3 https://cli.doppler.com/install.sh || wget -t 3 -qO- https://cli.doppler.com/install.sh) | sudo sh
    fi
fi

# Check if logged in
if ! doppler me &> /dev/null; then
    echo "Please login to Doppler first:"
    doppler login
fi

echo "Running docker compose for project: $PROJECT (Doppler: $DOPPLER_PROJECT/$CONFIG)"

# Change to the project directory and run with Doppler
cd "$PROJECT" || exit 1

# Run docker compose with Doppler secrets injected
doppler run --project "$DOPPLER_PROJECT" --config "$CONFIG" -- docker compose "$@"
