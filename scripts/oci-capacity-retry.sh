#!/bin/bash
# Oracle Cloud ARM Capacity Retry Script
# Retries terraform apply until instances are successfully created
# Common practice for OCI Free Tier ARM instances

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../terraform/oracle-cloud"
LOG_FILE="${SCRIPT_DIR}/oci-retry.log"
MAX_RETRIES=1000  # Can run for days
RETRY_INTERVAL=300  # 5 minutes between retries

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_instances() {
    cd "$TF_DIR"
    # Check if all instances exist in state
    local mgmt
    local nodes
    mgmt=$(terraform state list 2>/dev/null | grep -c "oci_core_instance.management") || mgmt=0
    nodes=$(terraform state list 2>/dev/null | grep -c "oci_core_instance.k8s_node") || nodes=0
    
    if [ "$mgmt" -ge 1 ] && [ "$nodes" -ge 2 ]; then
        return 0  # All instances exist
    fi
    return 1
}

main() {
    log "${YELLOW}🚀 Starting Oracle Cloud ARM Capacity Retry Script${NC}"
    log "Terraform directory: $TF_DIR"
    log "Max retries: $MAX_RETRIES"
    log "Retry interval: ${RETRY_INTERVAL}s ($(($RETRY_INTERVAL / 60)) minutes)"
    log ""
    
    # Check if already complete
    if check_instances; then
        log "${GREEN}✅ All instances already exist! Nothing to do.${NC}"
        cd "$TF_DIR"
        terraform output -json 2>/dev/null | jq -r '.ssh_connection_commands.value // empty'
        exit 0
    fi
    
    for i in $(seq 1 $MAX_RETRIES); do
        log "${YELLOW}━━━ Attempt $i/$MAX_RETRIES ━━━${NC}"
        
        cd "$TF_DIR"
        
        # Run terraform apply
        if terraform apply -auto-approve 2>&1 | tee -a "$LOG_FILE"; then
            # Check if instances were created
            if check_instances; then
                log ""
                log "${GREEN}🎉 SUCCESS! All instances created!${NC}"
                log ""
                terraform output
                exit 0
            fi
        fi
        
        # Check for "Out of host capacity" error
        if grep -q "Out of host capacity" "$LOG_FILE" 2>/dev/null; then
            log "${RED}❌ Out of host capacity - will retry in ${RETRY_INTERVAL}s${NC}"
        else
            log "${RED}❌ Other error occurred - check logs${NC}"
        fi
        
        # Wait before retrying
        log "⏳ Waiting ${RETRY_INTERVAL}s before next attempt..."
        log "   Press Ctrl+C to stop"
        sleep $RETRY_INTERVAL
    done
    
    log "${RED}❌ Max retries reached. No capacity found.${NC}"
    exit 1
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Stopped by user. Run again to resume.${NC}"; exit 130' INT

main "$@"
