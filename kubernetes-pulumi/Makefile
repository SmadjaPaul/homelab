# Makefile for Homelab Kubernetes Pulumi

# Default cluster
CLUSTER ?= oci

# Colors
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m # No Color

.PHONY: help init up destroy status clean test test-static test-e2e \
        k9s lens headlamp debug-pods logs \
        update-crds check-crds \
        validate-apps

# =============================================================================
# HELP
# =============================================================================

help:
	@echo "Homelab Kubernetes Pulumi - Available targets:"
	@echo ""
	@echo "  $(GREEN)Stack Management:$(NC)"
	@echo "    init              Initialize all stacks"
	@echo "    up                Deploy all stacks"
	@echo "    up-core           Deploy k8s-core only"
	@echo "    up-storage        Deploy k8s-storage only"
	@echo "    up-apps           Deploy k8s-apps only"
	@echo "    preview           Preview all stacks"
	@echo "    preview-core      Preview k8s-core only"
	@echo "    preview-storage   Preview k8s-storage only"
	@echo "    preview-apps      Preview k8s-apps only"
	@echo "    destroy           Destroy all stacks"
	@echo "    status            Show status of all stacks"
	@echo ""
	@echo "  $(GREEN)CRD Management:$(NC)"
	@echo "    update-crds       Update CRDs from official sources"
	@echo "    check-crds       Check for CRD updates"
	@echo ""
	@echo "  $(GREEN)Testing:$(NC)"
	@echo "    test              Run all tests"
	@echo "    test-static       Run static tests (Kubeconform, Polaris)"
	@echo "    test-e2e          Run E2E tests (Kuttl)"
	@echo "    validate-apps     Validate apps.yaml"
	@echo ""
	@echo "  $(GREEN)Observability:$(NC)"
	@echo "    k9s               Launch K9s terminal UI"
	@echo "    lens              Launch Lens desktop UI"
	@echo "    headlamp          Launch Headlamp web UI"
	@echo ""
	@echo "  $(GREEN)Debugging:$(NC)"
	@echo "    debug-pods        List pods in CrashLoopBackOff or ImagePullBackOff"
	@echo "    logs              Tail logs from a specific pod"
	@echo "    port-forward      Port forward to a service"
	@echo ""
	@echo "  $(GREEN)Configuration:$(NC)"
	@echo "    CLUSTER=local     Use local cluster instead of OCI"
	@echo ""
	@echo "  Examples:"
	@echo "    make up CLUSTER=local"
	@echo "    make k9s"
	@echo "    make debug-pods"

# =============================================================================
# STACK MANAGEMENT
# =============================================================================

init:
	@echo "$(YELLOW)Initializing stacks...$(NC)"
	python3 scripts/stack_manager.py init --cluster $(CLUSTER)

up: init
	@echo "$(YELLOW)Deploying all stacks...$(NC)"
	python3 scripts/stack_manager.py up --cluster $(CLUSTER)

up-core:
	@echo "$(YELLOW)Deploying k8s-core...$(NC)"
	python3 scripts/stack_manager.py up --stack core --cluster $(CLUSTER)

up-storage:
	@echo "$(YELLOW)Deploying k8s-storage...$(NC)"
	python3 scripts/stack_manager.py up --stack storage --cluster $(CLUSTER)

up-apps:
	@echo "$(YELLOW)Deploying k8s-apps...$(NC)"
	python3 scripts/stack_manager.py up --stack apps --cluster $(CLUSTER)

preview: init
	@echo "$(YELLOW)Previewing all stacks...$(NC)"
	python3 scripts/stack_manager.py up --cluster $(CLUSTER) --preview-only

preview-core:
	@echo "$(YELLOW)Previewing k8s-core...$(NC)"
	python3 scripts/stack_manager.py up --stack core --cluster $(CLUSTER) --preview-only

preview-storage:
	@echo "$(YELLOW)Previewing k8s-storage...$(NC)"
	python3 scripts/stack_manager.py up --stack storage --cluster $(CLUSTER) --preview-only

preview-apps:
	@echo "$(YELLOW)Previewing k8s-apps...$(NC)"
	python3 scripts/stack_manager.py up --stack apps --cluster $(CLUSTER) --preview-only

destroy:
	@echo "$(YELLOW)Destroying all stacks...$(NC)"
	python3 scripts/stack_manager.py destroy --cluster $(CLUSTER)

status:
	@echo "$(YELLOW)Stack status...$(NC)"
	python3 scripts/stack_manager.py status --cluster $(CLUSTER) --verbose

# =============================================================================
# CRD MANAGEMENT
# =============================================================================

update-crds:
	@echo "$(YELLOW)Updating CRDs...$(NC)"
	python3 scripts/update_crds.py --force

check-crds:
	@echo "$(YELLOW)Checking CRD updates...$(NC)"
	python3 scripts/update_crds.py --check

# =============================================================================
# TESTING
# =============================================================================

test: validate-apps test-static
	@echo "$(GREEN)All tests passed!$(NC)"

test-static:
	@echo "$(YELLOW)Running static tests...$(NC)"
	cd tests && pytest static/ -v

test-e2e:
	@echo "$(YELLOW)Running E2E tests...$(NC)"
	@which kubectl-kuttl > /dev/null || echo "Kuttl not installed. Install with: brew install kuttl"
	kubectl kuttl test --config tests/e2e/kuttl.yaml

validate-apps:
	@echo "$(YELLOW)Validating apps.yaml...$(NC)"
	cd shared && python3 -c "from apps.loader import get_loader; valid, err = get_loader().validate(); exit(0 if valid else 1)"

# =============================================================================
# OBSERVABILITY TOOLS
# =============================================================================

k9s:
	@echo "$(YELLOW)Launching K9s...$(NC)"
	@which k9s > /dev/null || (echo "K9s not installed. Install with: brew install k9s" && exit 1)
	k9s --context $(CLUSTER)

lens:
	@echo "$(YELLOW)Launching Lens...$(NC)"
	@if [ -d "/Applications/Lens.app" ]; then \
		open -a Lens --args --context=$(CLUSTER); \
	else \
		echo "Lens not installed. Download from https://k8slens.dev"; \
	fi

headlamp:
	@echo "$(YELLOW)Launching Headlamp...$(NC)"
	@which headlamp > /dev/null || (echo "Headlamp not installed. Install with: brew install headlamp" && exit 1)
	headlamp

# =============================================================================
# DEBUGGING
# =============================================================================

debug-pods:
	@echo "$(YELLOW)Pods in problematic state...$(NC)"
	@kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.status.phase != "Running" or (.status.containerStatuses != null and .status.containerStatuses[].state.waiting != null and (.status.containerStatuses[].state.waiting.reason == "CrashLoopBackOff" or .status.containerStatuses[].state.waiting.reason == "ImagePullBackOff"))) | "\(.metadata.namespace)/\(.metadata.name) - \(.status.phase) - \(.status.containerStatuses[0].state.waiting.reason // "unknown")"'

logs:
	@echo "$(YELLOW)Usage: make logs POD=<namespace/pod-name>$(NC)"
	@if [ -n "$(POD)" ]; then \
		kubectl logs -n $$(echo $(POD) | cut -d/ -f1) $$(echo $(POD) | cut -d/ -f2) -f; \
	fi

port-forward:
	@echo "$(YELLOW)Usage: make port-forward SERVICE=<namespace/service-name> PORT=<local:remote>$(NC)"
	@if [ -n "$(SERVICE)" ] && [ -n "$(PORT)" ]; then \
		kubectl port-forward -n $$(echo $(SERVICE) | cut -d/ -f1) svc/$$(echo $(SERVICE) | cut -d/ -f2) $(PORT); \
	fi

# =============================================================================
# CLEANUP
# =============================================================================

clean:
	@echo "$(YELLOW)Cleaning Pulumi cache...$(NC)"
	rm -rf k8s-core/.pulumi k8s-storage/.pulumi k8s-apps/.pulumi
	rm -rf .pytest_cache
	@echo "$(GREEN)Cleanup complete!$(NC)"
