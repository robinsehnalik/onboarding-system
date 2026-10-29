# Operational Runbook & Incident Playbook

This runbook documents operational procedures, incident response workflows, and the end-of-project handover checklist for the solo consultant operating the onboarding system.

---

## 1. Quick Reference: System Lifecycle

```
[Form Submit] --> status: new (Owner reviews lead & replies personally)
      |
[Scoping]       --> Owner fills services, price, currency, payment_terms --> status: quoted
      |
[WF-01]         --> Generates DocuSeal contract & Stripe invoice --> status: contract_sent
      |
[Signing & Pay] --> Client signs agreement and settles Stripe invoice
      |
[WF-02]         --> Validates signed contract, creates Notion portal & Drive, emails welcome --> status: onboarded
      |
[Execution]     --> Owner works on deliverables, updates Notion portal manually --> status: in_progress
      |
[Handout]       --> Owner checks final payment, delivers code, updates portal --> status: completed
```

---

## 2. Failure Recovery Procedures

### 2.1. WF-01 Partial Failure (DocuSeal or Stripe Fails)

* **Symptom**: WF-01 fails midway (e.g., DocuSeal created a contract, but Stripe timed out or threw an API error).
* **Guards in Place**:
  * `docuseal_submission_id` is populated in the database only after DocuSeal succeeds.
  * `stripe_invoice_id` is populated only after Stripe succeeds.
* **Recovery Steps**:
  1. Check the error notification in your alert channel (Telegram/Slack) for the exact error message.
  2. Inspect the client record in the database:
     * If `docuseal_submission_id` is present but `stripe_invoice_id` is empty:
       * Keep the `docuseal_submission_id`.
       * Ensure `status` remains `quoted`.
       * Re-run WF-01. WF-01 detects existing `docuseal_submission_id`, skips DocuSeal submission, and proceeds directly to creating and sending the Stripe invoice.
  3. Once both IDs exist, WF-01 automatically sets `status = "contract_sent"`.

---

### 2.2. Paid But Unsigned (WF-02 Gate Check Alert)

* **Symptom**: An alert is received: `[WF-02 Gate Warning] Client paid invoice but contract is unsigned.`
* **Context**: A client paid the Stripe invoice before completing the DocuSeal signing process.
* **Automated Guard**: WF-02 strictly halts without provisioning the Notion portal, creating the Drive folder, or sending the welcome email. The record remains in `status: contract_sent` (or `paid` with no provisioning).
* **Recovery Steps**:
  1. Open DocuSeal dashboard or run `curl -H "X-Auth-Token: $DOCUSEAL_API_KEY" https://api.docuseal.com/submissions/{id}` to verify the signing status.
  2. Contact the client directly via personal email or phone:
     *"Hi [Name], thank you for settling the invoice! Before we can provision your workspace and hold our kickoff call, we need your signature on the agreement sent via DocuSeal. Here is your signing link: [link]."*
  3. Once the client signs, manually trigger WF-02 using the Manual Execution Procedure (Section 3 below).

---

### 2.3. Notion or Drive Failure in WF-02

* **Symptom**: Alert received that Notion portal creation or Google Drive provisioning failed during WF-02 execution.
* **Guards in Place**:
  * `portal_url`, `drive_url`, and `welcome_sent_at` are written individually upon success.
* **Recovery Steps**:
  1. Check the error alert to identify which service failed (e.g., Google Drive API quota or Notion API rate limit).
  2. If Drive succeeded but Notion failed: `drive_url` is stored, while `portal_url` remains blank.
  3. Resolve the underlying service issue (e.g. check Notion integration permissions on the parent database).
  4. Trigger WF-02 manually with `client_id`.
  5. WF-02 checks each resource guard:
     * Sees `drive_url` $\rightarrow$ skips Google Drive folder creation.
     * Sees blank `portal_url` $\rightarrow$ creates the Notion portal page.
     * Sees blank `welcome_sent_at` $\rightarrow$ sends the welcome email.
     * Sets `status = "onboarded"`.

---

### 2.4. Duplicate Form Submission

* **Symptom**: Two or more records for the same client in `status == "new"`.
* **Recovery Steps**:
  1. Open the database view for `Needs Quote` (`status == "new"`).
  2. Compare the inquiry details.
  3. Merge any extra context from the second submission into the `message` field of the primary record.
  4. Set the duplicate record's `status = "lost"` and add `Duplicate entry` in `notes`.
  5. Never set duplicate records to `quoted`.

---

### 2.5. Scope or Pricing Amended After Contract Sent

* **Symptom**: The client requests a scope adjustment or different payment schedule after WF-01 has already run (`status == "contract_sent"`).
* **Recovery Steps**:
  1. **Void DocuSeal Submission**: Log in to DocuSeal and void / cancel the pending submission (or call `DELETE https://api.docuseal.com/submissions/{id}`).
  2. **Void Stripe Invoice**: In Stripe Dashboard, navigate to Invoices $\rightarrow$ locate the invoice $\rightarrow$ click "Change invoice status" $\rightarrow$ mark as "Void".
  3. **Reset Database Record**:
     * Clear `docuseal_submission_id`.
     * Clear `stripe_invoice_id` and `stripe_invoice_url`.
     * Update `services`, `price`, `currency`, or `payment_terms` as agreed.
     * Set `status = "quoted"`.
  4. **Re-trigger**: WF-01 will pick up the updated record and issue a fresh contract and invoice.

---

## 3. Manual WF-02 Execution Procedure

When WF-02 needs to be re-run after a resolved gate check or API recovery:

1. Open n8n and navigate to `WF-02: Paid to Provision & Welcome`.
2. Locate the node named **Manual Trigger** (`n8n-nodes-base.manualTrigger`).
3. Click **Test Step** or **Execute Workflow**.
4. In the test input pin, supply the JSON payload containing the client's database identifier:
   ```json
   {
     "client_id": "rec_abcdef123456"
   }
   ```
5. Click **Execute Workflow**.
6. Verify node execution highlights green through:
   * Fetch Record $\rightarrow$ Check Signature Gate $\rightarrow$ Provision Portal $\rightarrow$ Provision Drive $\rightarrow$ Send Welcome $\rightarrow$ Update DB to `onboarded`.

---

## 4. Handout Checklist (End of Project)

Before handing off deliverables to the client, complete the following manual checklist:

- [ ] **1. Verify Final Invoicing & Settlement**:
  - If project was structured as milestone or 50/50 upfront/completion, verify in Stripe Dashboard that the final invoice has been generated, sent, and marked `Paid`.
  - **Never hand over irreversible access or code before final payment is settled.**
- [ ] **2. Code Repository Transfer / Access**:
  - In your Git platform (GitHub / GitLab):
    - Option A (Transfer): Go to Repository Settings $\rightarrow$ Transfer ownership to client organization.
    - Option B (Invite): Invite client technical contact as Admin/Owner to the repository.
  - Record the repository URL in the database `repo_url` field.
  - Set `handout_method` to the appropriate selection (`GitHub Transfer`, `GitHub Invite`, or `Zip/Drive`).
- [ ] **3. Deliverables Upload to Google Drive**:
  - Upload final architecture diagrams, exports, PDF documentation, and any zipped artifacts into the client's shared Google Drive folder (`drive_url`).
- [ ] **4. Close Out Notion Client Portal**:
  - Open client's portal (`portal_url`).
  - Mark Phase 4 (Handout & Go-Live) checklist items as completed.
  - Populate the "Deliverables & Handout" section with repository links and documentation references.
- [ ] **5. Close Out Database Record**:
  - Set `completed_at` to the current timestamp.
  - Set `status = "completed"`.
- [ ] **6. Send Final Personal Wrap-up**:
  - Send a personal sign-off message from your mailbox thanking the client and confirming access.

---

## 5. Routine Portal Maintenance

During active delivery:
* Do not attempt to sync individual Jira/Linear/GitHub issues into Notion via automation.
* Spend 3 minutes at the end of every week or sprint to update the milestone checkboxes in the client's Notion portal (`[MANUAL UPDATE]`).
* This provides clear communication without fragile API sync scripts.
