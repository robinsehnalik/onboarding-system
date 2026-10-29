# Intake Form Configuration & Lead Handling Guide

This guide details how to configure the client-facing intake form using **Tally** or **Fillout**, wire it directly into the `clients` database, set up native email notifications, and handle duplicate inquiries.

---

## 1. Principles of Lean Intake

1. **Direct-to-Database**: The form tool writes directly to the canonical database (Airtable or Notion) using its native integration. **No n8n workflow sits on the intake path.**
2. **Reliability via Decoupling**: If n8n is restarting, updating, or temporarily down, leads are never dropped or delayed.
3. **Native Alerts**: The form tool notifies the owner directly via email immediately upon submission.
4. **Human Touch**: The owner replies directly from their personal mailbox to establish rapport before setting up a quote.

---

## 2. Form Tool Field Mapping

Whether using **Tally** or **Fillout**, configure the form questions and map them to the canonical `clients` table fields:

| Form Question / Input | Form Tool Field Type | Canonical DB Field (`clients`) | Required? |
| :--- | :--- | :--- | :---: |
| "What is your name?" | Short text | `name` | Yes |
| "What is your email address?" | Email | `email` | Yes |
| "What company or organization do you represent?" | Short text | `company` | Yes |
| "What type of automation or systems work do you need?" | Dropdown / Radio | `service_interest` | Yes |
| "Tell us about your project, goals, and current bottlenecks." | Long text / Textarea | `message` | Yes |
| "How did you hear about us?" | Dropdown / Short text | `source` | No |
| *(Hidden Field / Default Value)* | Fixed value: `new` | `status` | Yes |

> **Crucial Setting**: Ensure the form writes `status = "new"` by default on every record creation.

---

## 3. Native Email Notifications to Owner

Configure your form provider's native notification settings so you are alerted immediately on your phone/desktop without relying on intermediate webhooks.

### Tally Setup
1. In the Tally form builder, navigate to **Settings** $\rightarrow$ **Email notifications**.
2. Enable **Send notification email to yourself**.
3. Set destination email: `{{OWNER_EMAIL}}`.
4. Set Subject: `New Lead: [Respondent Name] from [Company Name]`.
5. Body: Include full submission summary.

### Fillout Setup
1. In Fillout, navigate to **Settings** $\rightarrow$ **Email notifications**.
2. Add notification recipient: `{{OWNER_EMAIL}}`.
3. Set Subject: `New Client Intake: {{name}} ({{company}})`.
4. Save settings.

---

## 4. Native Client Autoresponder Copy

Configure the form tool's native autoresponder to deliver an immediate, professional confirmation to the prospective client.

### Settings
* **Trigger**: Immediately upon form submission
* **Recipient**: Dynamic field `{{email}}`
* **Sender Name**: `{{OWNER_NAME}}`
* **Reply-To**: `{{OWNER_EMAIL}}`
* **Subject**: `Thanks for reaching out to {{OWNER_COMPANY}}`

### Autoresponder Body (Plain Text)

```text
Hi {{name}},

Thanks for reaching out! I've received your project inquiry regarding {{service_interest}} for {{company}}.

I personally review every submission. I'll review your notes and get back to you within 24 to 48 hours to discuss scope, feasibility, and next steps.

If you have any supporting documents, wireframes, or extra context you'd like to share in the meantime, feel free to reply directly to this email.

Best regards,

{{OWNER_NAME}}
{{OWNER_TITLE}}, {{OWNER_COMPANY}}
```

---

## 5. Duplicate Lead Handling Rules

When a prospect submits multiple inquiries:

1. **Detection**:
   * Filter the `clients` database by `email` or `company`.
   * Airtable or Notion will highlight duplicate records if configured with email deduplication rules.
2. **Review & Consolidation**:
   * If a record already exists with `status == "new"`, append the latest message to the existing record's `message` field and set the redundant submission's `status = "lost"` (with note: `Duplicate submission`).
   * If an active quote or project already exists (`contract_sent`, `paid`, `onboarded`), leave the active record unchanged and follow up directly via email with the client.
3. **Automated Safety**:
   * Because **WF-01** only triggers when `status == "quoted"` AND `docuseal_submission_id` is empty, duplicate submissions in status `new` will **never** accidentally trigger contracts or invoices.
