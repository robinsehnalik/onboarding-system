# Lean Client Onboarding System

A minimal, resilient client onboarding automation designed for a solo consultancy. Built on **n8n**, this system automates contract issuance, invoicing, workspace provisioning, and onboarding outreach while keeping scoping, pricing, and project delivery as deliberate human actions.

---

## 1. System Overview

```mermaid
flowchart TD
    subgraph Intake["Client Intake"]
        Form["Website Form (Tally / Fillout)"]
    end

    subgraph Store["Canonical Storage"]
        DB[("Clients Database (Airtable / Notion)")]
    end

    subgraph Automation["n8n Automations"]
        W1["WF-01: Quote to Contract & Invoice"]
        W2["WF-02: Paid to Provision & Welcome"]
        W3["WF-03: Daily Watcher"]
        WE["WF-ERR: Error Alert"]
    end

    subgraph Services["External Services"]
        DS["DocuSeal (E-Signature)"]
        ST["Stripe (Invoices)"]
        NP["Notion (Client Portal)"]
        GD["Google Drive (Shared Assets)"]
        MB["Owner Mailbox (SMTP / Gmail)"]
        AC["Independent Alert Channel (Telegram / Slack)"]
    end

    Form -->|Native insert status: new| DB
    DB -.->|Owner sets scope & status: quoted| W1
    W1 -->|POST /submissions| DS
    W1 -->|Create & finalize invoice| ST
    W1 -->|Update status: contract_sent| DB

    ST -->|Webhook invoice.paid| W2
    W2 -->|Verify signed contract| DS
    W2 -->|Create portal page| NP
    W2 -->|Create folder & share| GD
    W2 -->|Send welcome email| MB
    W2 -->|Update status: onboarded| DB

    W3 -->|Daily schedule (09:00 UTC)| DB
    W3 -->|Query signature status| DS
    W3 -->|Alert owner on aging| AC

    W1 -.->|On error| WE
    W2 -.->|On error| WE
    W3 -.->|On error| WE
    WE -->|Incident dispatch| AC
```

### Core Architecture Principles
1. **Single Source of Truth**: The `clients` database record is canonical. Notion portals, Drive folders, DocuSeal contracts, and Stripe invoices are projections or executors.
2. **Human Decides, Machine Executes**: The owner scopes projects, sets pricing, and performs final code transfers. The machine handles mechanical coordination.
3. **Idempotent by Field**: Every provisioning step is guarded by its own stored URL or timestamp. Re-running workflows never produces duplicate folders, pages, or emails.
4. **Lean by Default**: Direct form-to-database connections; no n8n workflow sits on the intake path.

For full architectural specifications, see [`architecture-onboarding.md`](./architecture-onboarding.md).

---

## 2. Workflows Catalog

| Workflow | Specification | Trigger | Role |
| :--- | :--- | :--- | :--- |
| **WF-01** | [`workflows/wf-01-quote-to-contract-invoice.spec.md`](./workflows/wf-01-quote-to-contract-invoice.spec.md) | Database polling (`status == "quoted"`) | Creates DocuSeal submission, creates and finalizes Stripe invoice, sets `status = "contract_sent"`. |
| **WF-02** | [`workflows/wf-02-paid-to-provision-welcome.spec.md`](./workflows/wf-02-paid-to-provision-welcome.spec.md) | Stripe `invoice.paid` webhook OR manual trigger | Verifies signed contract, sets `status = "paid"`, provisions Notion portal & Drive folder, sends welcome email, sets `status = "onboarded"`. |
| **WF-03** | [`workflows/wf-03-daily-watcher.spec.md`](./workflows/wf-03-daily-watcher.spec.md) | Daily Schedule (09:00 UTC) | Syncs `signed_at` via DocuSeal API; alerts owner if contracts remain unsigned (> 3 days) or invoices unpaid (> 7 days). |
| **WF-ERR** | [`workflows/wf-err-error-alert.spec.md`](./workflows/wf-err-error-alert.spec.md) | Error Trigger | Catches runtime node failures and dispatches formatted alerts to Telegram or Slack. |

---

## 3. External Services & Accounts Required

| Service | Purpose | Setup Document |
| :--- | :--- | :--- |
| **Database** (Airtable / Notion) | Canonical storage of client records (`clients` table) | [`docs/database-schema.md`](./docs/database-schema.md) |
| **Form Tool** (Tally / Fillout) | Lead capture directly into database | [`docs/intake-form-setup.md`](./docs/intake-form-setup.md) |
| **DocuSeal** | E-signature contract generation (Outbound REST only) | [`templates/docuseal/contract-fields.md`](./templates/docuseal/contract-fields.md) |
| **Stripe** | Invoice generation and payment processing | [`.env.example`](./.env.example) |
| **Notion** | Client workspace portal pages | [`templates/notion/client-portal-template.md`](./templates/notion/client-portal-template.md) |
| **Google Drive** | Shared project asset folders | [`.env.example`](./.env.example) |
| **Owner Mailbox** (Gmail/SMTP) | Direct transactional welcome emails | [`templates/emails/welcome.md`](./templates/emails/welcome.md) |
| **Alert Channel** (Telegram / Slack) | Independent out-of-band operational notifications | [`.env.example`](./.env.example) |

---

## 4. Setup & Deployment Order

Follow these steps sequentially to deploy the system:

### Step 1: Configure the Canonical Database
* Refer to [`docs/database-schema.md`](./docs/database-schema.md).
* Create the `clients` table with the exact 25 fields specified.
* Set default values and views (`Needs Quote`, `Awaiting Payment`, `Active Projects`).

### Step 2: Configure the Intake Form
* Refer to [`docs/intake-form-setup.md`](./docs/intake-form-setup.md).
* Connect Tally or Fillout directly to your `clients` table via native integration.
* Configure the form to set `status = "new"` on record creation.
* Enable native email notifications to the owner and configure the plain-text autoresponder.

### Step 3: Configure Environment Credentials
* Copy [`.env.example`](./.env.example) to `.env`:
  ```bash
  cp .env.example .env
  ```
* Fill in your API keys: DocuSeal API token, Stripe restricted key, database token, Notion integration secret, Google OAuth credentials, and owner mailbox SMTP credentials.

### Step 4: Set Up DocuSeal Template & Notion Parent Page
* In DocuSeal, create your consulting agreement template and name fields matching [`templates/docuseal/contract-fields.md`](./templates/docuseal/contract-fields.md). Note the template ID in `.env`.
* In Notion, create a parent page called `Client Portals` and share it with your Notion integration. Note the parent page ID in `.env`.

### Step 5: Implement Workflows in n8n
* Build or import workflows according to each specification:
  * [`workflows/wf-01-quote-to-contract-invoice.spec.md`](./workflows/wf-01-quote-to-contract-invoice.spec.md)
  * [`workflows/wf-02-paid-to-provision-welcome.spec.md`](./workflows/wf-02-paid-to-provision-welcome.spec.md)
  * [`workflows/wf-03-daily-watcher.spec.md`](./workflows/wf-03-daily-watcher.spec.md)
  * [`workflows/wf-err-error-alert.spec.md`](./workflows/wf-err-error-alert.spec.md)
* In Workflow Settings for WF-01, WF-02, and WF-03, set **Error Workflow** to `WF-ERR: Error Alert`.

### Step 6: End-to-End Staging Verification
1. Submit a test form $\rightarrow$ Verify record appears with `status = "new"`.
2. Fill in `services`, `price`, `currency`, and change `status` to `quoted`.
3. Verify **WF-01** creates DocuSeal submission and Stripe test invoice, and sets `status = "contract_sent"`.
4. Sign the DocuSeal test document.
5. In Stripe test mode, mark the invoice as paid $\rightarrow$ Verify **WF-02** triggers.
6. Verify Notion portal page is created, Drive folder is provisioned, welcome email arrives in inbox, and database updates to `status = "onboarded"`.
7. Re-run WF-02 manually $\rightarrow$ Verify all guards hold (no duplicate pages, folders, or emails).

### Step 7: Production Activation
* Switch Stripe keys to production restricted key.
* Activate all 4 workflows in n8n.

---

## 5. Day-to-Day Operations & Handout

* **Scoping & Pricing**: Human deliberate action. You review inquiries, discuss requirements, and input pricing directly into the database.
* **Incident Response & Manual Overrides**: See [`docs/runbook.md`](./docs/runbook.md) for step-by-step procedures to recover from API timeouts, chase unsigned contracts, or re-run WF-02.
* **Project Handover**: Complete the handover checklist in [`docs/runbook.md`](./docs/runbook.md) (final payment settlement, manual Git repository transfer/invite, Drive deliverables upload, and portal closeout).

---

## 6. Repository Structure

```text
onboarding-automation/
├── README.md                                  # This documentation
├── architecture-onboarding.md                 # Complete lean architecture specification
├── .env.example                               # Environment variable reference
├── workflows/
│   ├── wf-01-quote-to-contract-invoice.spec.md # Quote -> DocuSeal + Stripe Invoice
│   ├── wf-02-paid-to-provision-welcome.spec.md # Stripe Paid -> Notion + Drive + Welcome
│   ├── wf-03-daily-watcher.spec.md            # Daily status & aging monitor
│   └── wf-err-error-alert.spec.md             # Global error handler
├── templates/
│   ├── emails/
│   │   └── welcome.md                         # Plain-text onboarding welcome email
│   ├── docuseal/
│   │   └── contract-fields.md                 # DocuSeal field mappings & payload
│   └── notion/
│       └── client-portal-template.md          # Client portal structure & manual tracker
├── docs/
│   ├── database-schema.md                     # Single flat table field spec & lifecycle
│   ├── intake-form-setup.md                   # Direct form-to-database configuration
│   └── runbook.md                             # Failure recovery & handover checklist
└── scripts/
    └── export-workflows.sh                    # Workflow sanitizer and export script
```
