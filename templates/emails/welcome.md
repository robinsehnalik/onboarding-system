# Welcome Email Template

> **Channel**: Dispatched directly from the owner's mailbox (Gmail / SMTP via n8n in WF-02)  
> **Format**: Plain text / minimal markdown (ensures high deliverability and personal feel)  
> **Trigger**: Executed automatically upon verified contract signature and initial invoice payment  

---

```text
Subject: Welcome to {{COMPANY_NAME}} — Onboarding & Next Steps

Hi {{CLIENT_NAME}},

Thank you for completing the agreement and initial payment. I'm excited to partner with you on this project.

To get everything running smoothly and set us up for a productive kickoff, here are the key links and initial steps:

1. Client Portal (Project Hub)
   {{PORTAL_URL}}
   This is your dedicated Notion portal. It contains our scope overview, milestone roadmap, and deliverable checklists. I personally update the milestone tracker as we complete each phase of work.

2. Shared Google Drive Folder
   {{DRIVE_URL}}
   I've provisioned a secure shared folder for all project assets, raw files, and deliverables. Please drop your brand assets, design guidelines, and reference materials here.

3. Schedule Our Kickoff Call
   {{BOOKING_LINK}}
   Please select a 45-minute slot that works best for your calendar so we can align on goals, review timelines, and address any immediate questions.

4. Secure Credential Sharing (Important Security Note)
   Please do NOT send passwords, credentials, or API tokens via email.
   Instead, use a secure password manager sharing link (e.g., 1Password, Bitwarden, or {{PASSWORD_MANAGER_LINK}}) to share any necessary access securely.

What happens next:
Once you book our kickoff call and upload any initial assets to Google Drive, I'll review everything before our meeting and prepare our first sprint backlog.

If you have any questions in the meantime, simply reply directly to this email.

Best regards,

{{OWNER_NAME}}
{{OWNER_TITLE}}
{{OWNER_COMPANY}}
```

---

## Placeholders Reference

| Placeholder | Source | Description |
| :--- | :--- | :--- |
| `{{CLIENT_NAME}}` | `clients.name` | Contact's first or full name |
| `{{COMPANY_NAME}}` | `clients.company` | Client's company name |
| `{{PORTAL_URL}}` | `clients.portal_url` | Generated Notion client portal URL |
| `{{DRIVE_URL}}` | `clients.drive_url` | Generated Google Drive shared folder URL |
| `{{BOOKING_LINK}}` | Environment / Config | Owner's Calendly / Cal.com kickoff scheduling link |
| `{{PASSWORD_MANAGER_LINK}}` | Environment / Config | Link to secure cred drop / 1Password Psst / Bitwarden Send |
| `{{OWNER_NAME}}` | Environment / Config | Owner's full name |
| `{{OWNER_TITLE}}` | Environment / Config | Owner's professional title |
| `{{OWNER_COMPANY}}` | Environment / Config | Owner's agency or consultancy name |
