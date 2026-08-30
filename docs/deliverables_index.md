# Reviewer and presentation index

Start here for a structured review of Saydaliyati. The project is an engineering
portfolio and supports temporary, on-request demonstrations; it has no
guaranteed permanent validated public deployment. The isolated `demo:seed`
dataset is fictional; the general starter seed has a separately documented
commercial-distribution cleanup requirement.

## Choose a review path

| Audience | Recommended path |
| --- | --- |
| Recruiter or hiring manager | [README](../README.md) → [visual gallery](visual_gallery.md) → [case study](portfolio_case_study.md) → [presentation messaging](presentation_messaging.md) |
| Engineering reviewer | [Architecture](architecture.md) → [feature matrix](feature_matrix.md) → [technical reviewer guide](reviewer_guide.md) → code and tests linked there |
| Client or marketplace reviewer | [Presentation messaging](presentation_messaging.md) → [marketplace assets](marketplace_assets.md) → [client FAQ](client_faq.md) → [screenshot selection](screenshot_selection.md) |
| Live-demo participant/operator | [Demo-mode guide](demo_mode.md) → [operator checklist](demo_operator_checklist.md) → [live demo guide](live_demo_guide.md) |
| Interview preparation | [Case study](portfolio_case_study.md) → [interview guide](interview_guide.md) → [presentation deck outline](presentation_deck_outline.md) |

## Core repository documents

- [README](../README.md) — project orientation, capabilities, stack, setup,
  historical screenshots, documentation, and Release 1.0 boundary.
- [Architecture](architecture.md) — domains, data flows, consistency and
  security boundaries, external systems, and limitations.
- [Engineering case study](portfolio_case_study.md) — problem, product approach,
  implementation decisions, outcomes, trade-offs, and next steps.
- [Feature matrix](feature_matrix.md) — canonical distinction between
  implemented, demo-ready, externally configured, and intentionally absent
  capabilities.
- [Technical reviewer guide](reviewer_guide.md) — high-signal code and test path.
- [Authorization matrix](authorization_matrix.md) — role/domain access boundary.
- [Release notes](release_1_0.md) and [release checklist](release_checklist.md) —
  evidence, limitations, and the canonical future release gate.
- [Completed phase history](roadmap.md) — status of the implemented Phase 18–27
  business domains and deliberately deferred search/clinical capabilities.

## Demo and visual evidence

- [Demo-mode guide](demo_mode.md) — safe environment assumptions,
  deterministic seed, journeys, and temporary access lifecycle.
- [Live demo guide](live_demo_guide.md) — 5-, 10-, and 20-minute click/explain/
  avoid routes plus common-question answers.
- [Arabic presentation script](demo_presentation_script.md) — existing focused
  Arabic 10–15 minute narrative.
- [Operator checklist](demo_operator_checklist.md) — before, during, and after
  controls for a temporary session.
- [Visual gallery](visual_gallery.md) — 21 reviewed Phase 15 real-browser captures,
  retained as historical evidence pending a Release 1.0 recapture.
- [Screenshot plan](screenshot_plan.md) — capture scenarios, manifest,
  sanitization, and verification evidence.
- [Screenshot selection](screenshot_selection.md) — ranked top 5, 8, and 12,
  with README, LinkedIn, Upwork, and slide recommendations.

## Presentation and marketplace package

- [Presentation messaging](presentation_messaging.md) — repository discovery,
  differentiators, limitations, three elevator pitches, short/medium/long
  summaries, and portfolio positioning.
- [Marketplace assets](marketplace_assets.md) — complete Upwork Project Catalog
  copy, reusable proposal sections, Freelancer.com profile text, and LinkedIn
  project entry.
- [Presentation deck outline](presentation_deck_outline.md) — 14-slide
  professional narrative; no PowerPoint generated.
- [Interview guide](interview_guide.md) — repository-grounded questions and
  concise answers across Rails, architecture, Hotwire, database, security,
  inventory, testing, deployment, and trade-offs.
- [Client FAQ](client_faq.md) — clear implemented/external/extension
  answers for branches, payments, suppliers, loyalty, WhatsApp, ERP, and related
  questions.

## Operational supporting documents

- [Production readiness](production_readiness.md)
- [Environment variables](environment_variables.md)
- [Security operations](security_operations.md)
- [Backup and restore](backup_restore.md)
- [Incident response](incident_response.md)
- [Job schedule](job_schedule.md)
- [Performance baseline](performance_baseline.md)
- [Launch checklist](launch_checklist.md)
- [Render deployment plan—not deployed](deployment_render.md)

## Presentation boundary

Release 1.0 implements batches/FEFO, purchasing, POS, per-item substitution,
deterministic drug-safety decision support, advanced search, customer/POS sales
returns, loyalty/wallet, application-level organization tenancy and branches,
scoped APIs/signed webhooks and analytics. Do not turn these into claims of a
commercial SaaS control plane or provider/production certification: online or
external-card payment execution, supplier returns, supplier/courier/SMS/
WhatsApp/ERP/clinical providers, real SMTP/scanner/storage/monitoring/backups,
regulatory/accessibility/penetration-test certification, production scale, a
permanent validated demo, or real-client results are not evidenced.
