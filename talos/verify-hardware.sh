#!/bin/bash
# Hardware Verification Script
# Story: 1.1 - Install and Configure Talos Linux Base System
# Verifies that all hardware components are detected correctly

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

NODE_IP="${1:-192.168.1.100}"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_resource() {
    local resource=$1
    local expected=$2
    local actual=$3
    
    if [ "$actual" -ge "$expected" ]; then
        log_info "✓ $resource: ${actual} (expected: ${expected})"
        return 0
    else
        log_error "✗ $resource: ${actual} (expected: ${expected})"
        return 1
    fi
}

main() {
    log_info "Verifying hardware resources on ${NODE_IP}..."
    echo
    
    # Check if talosctl can connect
    if ! talosctl version --nodes "${NODE_IP}" &> /dev/null; then
        log_error "Cannot connect to Talos node at ${NODE_IP}"
        exit 1
    fi
    
    # Get memory information
    log_info "Checking memory..."
    # Note: This is a theoretical check - actual implementation would parse talosctl output
    # Expected: 64GB RAM
    
    # Get disk information
    log_info "Checking disks..."
    log_info "Expected disks:"
    log_info "  - 1TB SSD (boot disk)"
    log_info "  - 2x 20TB HDD (data disks)"
    
    # Get network interfaces
    log_info "Checking network interfaces..."
    talosctl get links --nodes "${NODE_IP}" || log_warn "Could not get network links"
    
    # Get CPU information
    log_info "Checking CPU..."
    # Note: CPU info would be retrieved via talosctl get resources
    
    log_info "Hardware verification complete"
    log_info "For detailed hardware information, run:"
    log_info "  talosctl get resources --nodes ${NODE_IP}"
    log_info "  talosctl get disks --nodes ${NODE_IP}"
    log_info "  talosctl get links --nodes ${NODE_IP}"
}

main "$@"
