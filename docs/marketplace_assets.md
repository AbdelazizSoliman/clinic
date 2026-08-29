# Marketplace and professional profile assets

Use these passages as foundations, then tailor the first and last paragraph to
the specific client or role. Capability wording follows the
[feature matrix](feature_matrix.md); it should not be expanded without new
repository evidence.

## Upwork Project Catalog package

### Project title

Build an Arabic RTL Rails commerce and operations application

### Subtitle

A server-rendered workflow foundation for catalog, checkout, roles, inventory,
fulfilment, reporting, and secure document review.

### Category

Ecommerce Development

### Skills

Ruby on Rails, Ruby, PostgreSQL, Hotwire, Turbo, Stimulus, Tailwind CSS,
E-commerce Development, Database Design, Web Application Security, Arabic RTL

### Deliverables

- Discovery summary and confirmed workflow scope.
- Arabic RTL responsive customer and staff interfaces.
- Rails/PostgreSQL domain model and role-based access boundaries.
- Agreed commerce and operations workflows with explicit state transitions.
- Inventory reservation and auditable movement behavior where included in scope.
- Automated tests for agreed high-risk paths.
- Setup, architecture, operations, and demonstration documentation.
- A private handover walkthrough using fictional or client-approved test data.

### Client requirements

The client supplies the target country and operating rules, required user roles,
catalog and inventory concepts, checkout and payment expectations, delivery
workflow, prescription or document-handling policy, Arabic content ownership,
branding assets, hosting constraints, integration documentation, and acceptance
criteria. Any real medical, privacy, tax, payment, or regulatory requirements
must be reviewed by the client's qualified advisers and converted into explicit
product requirements.

### Indicative timeline

1. Discovery and scope confirmation.
2. Data model, architecture, and interface direction.
3. Iterative implementation of the agreed customer and staff workflows.
4. Security, edge-case, and automated-test pass.
5. Client acceptance, documentation, and handover.

Duration depends on the selected modules, integrations, data migration, design
inputs, and review turnaround. A schedule is confirmed only after discovery.

### What the client receives

The client receives source code for the agreed scope, database migrations,
responsive views, automated tests, environment/setup guidance, architecture and
operations notes, and a structured handover demonstration. Third-party service
accounts, fees, production data preparation, and regulatory approval are not
implied.

### Out-of-scope items unless separately agreed

- Production deployment, hosting, paid infrastructure, and ongoing operations.
- Payment gateways, SMS, WhatsApp, courier, ERP, or other external integrations.
- Client-specific adaptation of the implemented purchasing, batch/FEFO, POS,
  customer/POS sales returns, loyalty/wallet, multi-branch, organization-tenancy,
  scoped API/webhook, analytics, and configurable drug-safety foundations.
- Platform-super-admin provisioning, tenant subscription billing, plan
  enforcement, supplier returns, or provider-specific integrations.
- Diagnosis, prescribing, autonomous clinical decisions, or medical advice.
- Legal, medical, privacy, accessibility, PCI, or regulatory certification.
- Content entry, production data migration, branding creation, and native mobile
  applications.

### FAQ

**Is this a ready-made product purchase?**

The portfolio demonstrates a working foundation and delivery approach. A client
engagement still begins with discovery and an agreed scope; it is not presented
as an off-the-shelf regulated pharmacy product.

**Can you demonstrate it before a project starts?**

Yes. A temporary, private, on-request walkthrough can use deterministic
fictional data. There is no permanent public demo or shared credential.

**Does it support Arabic and RTL layouts?**

Yes. The demonstrated application is Arabic RTL and includes responsive
customer and staff screens. Client-supplied terminology and content still need
review for the target market.

**Is online payment included?**

The demonstrated workflow uses cash on delivery. A payment gateway would be a
separate integration with provider, country, security, and reconciliation
requirements agreed during discovery.

**Is it ready for multiple branches?**

Application-level multi-branch operations are implemented and demo-ready:
authorized staff can switch branches, and inventory/FEFO, POS, purchasing,
fulfilment, transfers, returns, and reporting retain branch context. A client
engagement must still confirm market-specific branch catalog, pricing, staffing,
tax, and delivery rules.

**Does prescription scanning mean clinical validation?**

No. File validation and malware-scan gating protect the upload boundary;
pharmacist decisions remain human workflow. The application also includes
configurable deterministic drug-safety decision support based on locally
configured rules and structured data. It does not diagnose, prescribe, use a
certified external clinical knowledge provider, or replace pharmacist judgment.

**What technologies are used?**

Ruby on Rails 8, PostgreSQL, server-rendered Hotwire/Turbo/Stimulus, Tailwind
CSS, Active Storage, and Solid Queue/Cache, with Minitest and security/build
checks.

**Can external services be integrated?**

A scoped integration API and signed outbound webhooks are implemented for the
documented Release 1.0 surface. Compatibility with a particular ERP, courier,
payment, SMS, WhatsApp, supplier, or clinical provider requires a separate
adapter, test environment, failure policy, and operational owner.

## Upwork proposal foundation

### Opening

Your project is less about adding isolated screens and more about keeping the
customer order, stock, staff decisions, and history consistent as the workflow
moves forward. That is the kind of Rails work I would focus on first: define the
states and ownership boundaries, then build the interface around them.

### Problem understanding

From your brief, the critical path appears to be **[insert the client's actual
workflow]**. The main questions I would resolve during discovery are who may
perform each transition, what must remain historically unchanged, which actions
reserve or consume inventory, and how external-service failures should appear
to staff and customers.

### Technical solution

I would model the agreed workflow in Rails and PostgreSQL with explicit service
boundaries for multi-record changes, server-side authorization, database
constraints, and tests around the risky transitions. Hotwire can keep the UI
responsive while retaining server-side validation and avoiding an unnecessary
API/client split. The exact modules would follow your confirmed requirements,
not a prewritten feature list.

### Architecture explanation

For a closely connected commerce-and-operations workflow, a modular Rails
monolith is often a practical starting point: order, inventory, promotion, and
fulfilment updates can share clear database transactions while domain-specific
services keep responsibilities separated. External providers can remain behind
adapters so their timeouts and failures do not silently corrupt completed
business transactions.

### Relevant evidence

My Saydaliyati portfolio project demonstrates this approach in an Arabic RTL
pharmacy scenario: atomic checkout and snapshots, inventory reservations and
append-only branch-local batch movements, private per-item prescription review,
configurable deterministic drug-safety gates, purchasing, POS, customer/POS
sales returns, loyalty/wallet ledgers, tenant/branch isolation, scoped APIs,
signed webhooks, analytics, TOTP 2FA, and deterministic demo data. I will
distinguish reusable engineering patterns from pharmacy-specific assumptions
when discussing your project.

### Demo invitation

I can walk you through a temporary private demo using fictional data and focus
the session on the part most relevant to your brief—for example checkout
integrity, role separation, inventory, or background workflows. No public demo
credentials or real personal records are used.

### Closing

If the workflow above matches your priorities, the useful next step is to turn
your first operational scenario and acceptance criteria into a bounded initial
milestone. I can then identify dependencies, open decisions, and a realistic
delivery sequence before implementation begins.

### Adaptation notes

- Replace the bracketed workflow with details from the client's brief.
- Mention only two or three relevant portfolio parallels.
- Ask one concrete question that affects architecture or acceptance.
- Never imply that provider-specific integrations or unimplemented control-plane
  features already exist.
- Avoid promising compliance, scale, production launch, or a schedule before
  the client requirements are known.

## Freelancer.com profile version

I build workflow-heavy Ruby on Rails applications with PostgreSQL, Hotwire, and
server-rendered responsive interfaces. My Saydaliyati portfolio project connects
an Arabic RTL storefront with checkout, private prescription review, inventory
reservations, fulfilment, promotions, reporting, role-based access, and TOTP
2FA. The implementation emphasizes transactions, explicit state changes,
immutable order history, append-only stock movements, automated tests, and
clear documentation. A private demonstration with fictional data is available
on request. Release 1.0 includes application-level organization tenancy,
multi-branch operations, purchasing, batch/FEFO inventory, POS, customer/POS
sales returns, loyalty/wallet, scoped APIs/webhooks, and analytics. Real payment
gateways and provider-specific integrations are separate work.

## LinkedIn Featured Project entry

### Headline

Saydaliyati — Arabic RTL Pharmacy Commerce and Operations in Rails

### Description

Built a Rails 8 portfolio application that connects an Arabic RTL customer
storefront to prescription review, inventory reservations, order fulfilment,
delivery configuration, promotions, reporting, and administration. The project
uses explicit service objects and PostgreSQL consistency controls for critical
state changes, private role-scoped document access, TOTP 2FA for privileged
users, and deterministic fictional data for repeatable on-request demos. It also
includes application-level organization/branch isolation, purchasing,
batch/FEFO inventory, POS, sales returns, loyalty/wallet, scoped integration APIs,
signed outbound webhooks, and tenant-aware analytics. It is not presented as a
production-validated SaaS control plane or as having real payment/provider
integrations.

### Technology list

Ruby 3.4.6; Rails 8.1.3.1; PostgreSQL; Hotwire; Turbo; Stimulus; Tailwind CSS;
Devise; TOTP; Active Storage; Solid Queue; Solid Cache; Minitest; Docker;
GitHub Actions

### Key achievements

- Connected customer ordering to prescription, reservation, fulfilment, and
  reporting workflows in one modular monolith.
- Preserved submitted commercial history through immutable order snapshots.
- Modeled physical, reserved, and available stock with append-only movements.
- Enforced role and ownership boundaries around medical, inventory, order, and
  administrative data.
- Created deterministic fictional demo journeys and 21 reviewed browser
  screenshots without publishing credentials or a permanent deployment.
