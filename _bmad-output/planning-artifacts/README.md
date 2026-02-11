# Planning Artifacts (BMad) — Index

Ce dossier contient les **livrables BMad** (Analysis, Planning, Solutioning). Voici quel document est **à jour** et lesquels sont **remplacés** (conservés pour l’historique).

---

## Documents à jour (référence)

| Document | Rôle | Version / date |
|----------|------|----------------|
| **prd-homelab-2026-01-29.md** | PRD (Product Requirements Document) | v2.0 — aligné Architecture v6.0 ; Stack IA + services entreprise (FR-032 à FR-037, Phase 4b) |
| **architecture-proxmox-omni.md** | Architecture système | v6.0 — Proxmox + Omni + Talos + ArgoCD + Authentik |
| **epics-and-stories-homelab.md** | Epics et User Stories | 25 epics, 84 stories (dont Phase 4b : Stack IA, Fleet, Odoo, Migadu, DocuSeal, Docusaurus) |
| **stack-ia-et-services-entrepreneuse.md** | Intégration Stack IA & services entreprise | Référence docs/fiche-stack-ia.md, docs/synthese-outils-entrepreneuse.md ; mapping FR/epics Phase 4b |
| *(résumé)* | Product Brief | Conclusions dans docs-site/docs/advanced/planning-conclusions.md §1 |
| **bmm-workflow-status.yaml** | Statut des workflows BMad | Pointe vers les livrables ci‑dessus |
| **story-0.0.1-pre-implementation-checklist.md** | Implementation Readiness | PASSED |
| **implementation-progress.md** | Suivi manuel de la progression | Phase 1–3 |

---

## Documents remplacés (historique)

| Document | Remplacé par |
|----------|--------------|
| **prd-homelab-2026-01-22.md** | prd-homelab-2026-01-29.md (v2.0) |
| **architecture-homelab.md** | architecture-proxmox-omni.md (v6.0) |
| **architecture-cozystack.md** | architecture-proxmox-omni.md |

---

## Sources intégrées (hors _bmad-output)

| Document | Rôle |
|----------|------|
| **docs/fiche-stack-ia.md** | Stack IA : LiteLLM, DLP, RAG, observabilité, limites — intégrée via Phase 4b (Epic 4.6) |
| **docs/synthese-outils-entrepreneuse.md** | Stratégie et services (Fleet, Odoo, Migadu, DocuSeal, Docusaurus) — intégrée via Phase 4b (Epic 4.7) |

## Autres artefacts

| Document | Rôle |
|----------|------|
| *(résumé)* | Décision invitation-only + Cloudflare → docs-site/docs/advanced/planning-conclusions.md §3 |
| *(résumé)* | Stack identité (Authentik retenu) → §2 |
| **rbac-family-onboarding-research.md** | Recherche RBAC / onboarding famille |
| *(résumé)* | Design Authentik (flux, apps, CI) → docs-site/docs/advanced/planning-conclusions.md §4 |

---

## Où est quoi ?

- **docs-site/docs/** : documentation opérationnelle (runbooks, architecture, décisions & limites). Voir [README à la racine](../../README.md#documentation).
- **docs-site/** : site Docusaurus (doc « site web »).
- **_bmad-output/implementation-artifacts/** : livrables d’implémentation (sprint-status, next-steps, etc.).
