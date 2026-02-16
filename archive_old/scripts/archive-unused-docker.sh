#!/bin/bash
# Script to identify and archive unused Docker services
# Run this to move unused Docker images to archive folder

echo "🔍 Identifying Docker services to archive..."
echo ""

# Services to keep (new modular architecture)
KEEP_SERVICES=(
  "docker/core"
  "docker/authentik"
  "docker/monitoring"
  "docker/services"
  "docker/scripts"
  "docker/Dockerfiles"
  "docker/README.md"
  "docker/docker-stack.sh"
  "docker/DOPPLER_INTEGRATION.md"
)

# Services to archive (old/legacy)
ARCHIVE_SERVICES=(
  "docker/oci-core"
  "docker/arm"
  "docker/jellyfin"
  "docker/wazuh"
  "docker/caddy"
  "docker/npm"
  "docker/blocky"
  "docker/downloaders"
  "docker/alloy"
  "docker/exporters"
  "docker/ubu"
  "docker/proxy"
  "docker/kasm"
  "docker/db-server"
)

ARCHIVE_DIR="docker/archive"

# Create archive directory
mkdir -p "$ARCHIVE_DIR"

echo "📦 The following services will be archived:"
echo ""
for service in "${ARCHIVE_SERVICES[@]}"; do
  if [ -e "$service" ]; then
    echo "  📁 $service"
  fi
done

echo ""
echo "✅ The following services will be KEPT:"
echo ""
for service in "${KEEP_SERVICES[@]}"; do
  if [ -e "$service" ]; then
    echo "  ✅ $service"
  fi
done

echo ""
echo "⚠️  To archive the unused services, run:"
echo ""
echo "  mkdir -p docker/archive"
for service in "${ARCHIVE_SERVICES[@]}"; do
  if [ -e "$service" ]; then
    echo "  mv $service docker/archive/"
  fi
done
echo ""
echo "📝 Note: This is a dry-run. No files have been moved."
echo "   Review the list above and execute the commands manually if you're sure."
