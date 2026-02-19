<!-- Context: project-intelligence/nav | Priority: high | Version: 2.0 | Updated: 2026-02-19 -->

# Project Intelligence

> Start here for quick project understanding. These files bridge business and technical domains.

## Structure

```
.opencode/context/project-intelligence/
├── navigation.md              # This file - quick overview
├── technical-domain.md        # Stack, architecture, technical decisions
├── homelab-standards.md       # Coding standards (K8s, Flux, Kustomize, Doppler)
├── living-notes.md            # Active issues, debt, open questions
├── decisions-log.md           # Major decisions with rationale
├── business-domain.md         # Business context (optional)
└── business-tech-bridge.md    # How business needs map to solutions (optional)
```

## Quick Routes

| What You Need | File | Description |
|---------------|------|-------------|
| Understand the "how" | `technical-domain.md` | Stack, architecture, integrations |
| Coding standards | `homelab-standards.md` | K8s, Flux, Kustomize, Doppler patterns |
| Current state | `living-notes.md` | Active issues and open questions |
| Decision context | `decisions-log.md` | Why decisions were made |

## Usage

**Agent / Developer**:
1. Start with `technical-domain.md` to understand the stack
2. Check `homelab-standards.md` for coding patterns
3. Use `living-notes.md` for current issues

## Key Technologies

- **OCI**: Oracle Cloud Infrastructure
- **OKE**: Oracle Kubernetes Engine
- **Flux**: GitOps reconciliation
- **Doppler**: Secret management
- **GitHub Actions**: CI/CD
- **Kustomize**: Configuration management
