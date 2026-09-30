# Approval, files, and versions

Read this before creating a workspace, naming a candidate, exporting a file, or claiming delivery.

## Workspace

For a new user without a layout standard, propose five shallow zones: source materials, requirement clarification, working drafts, accepted deliverables, and governance records. Translate the labels to the user's language. If a workspace exists, ask whether to retain it before moving or creating files. Keep process notes and scripts apart from accepted files; avoid nested “final/final2” shells. Name scripts for their action, not `utils` or `final`.

## Review states

1. `facts_open`: target and sources known; claims are being checked.
2. `modules_in_review`: each required module has its own approved/revise/defer status. No Word candidate until all required modules are approved.
3. `word_candidate`: editable, versioned file built from the approved modules; render and inspect every page.
4. `word_approved_pdf_pending`: the person approves the exact Word candidate. Assign a new formal **content version** and record which candidate produced it; do not yet call the pair delivered.
5. `pdf_candidate`: export from that approved Word. Verify text, page count, visuals, fonts/icons, and ability to find/open the file.
6. `delivered`: the person approves the exact PDF and the requested Word/PDF pair. Preserve predecessor files and the candidate-to-formal mapping.

Changing facts or an approved module reopens that module and affected Word/PDF approvals **for the new revision**. Changing the Word or re-exporting it invalidates PDF acceptance for that new revision. A previously delivered pair remains historically accepted and preserved; never retroactively mark its files unapproved or overwrite them. Create new candidates and a new formal content version for the change. A pause or tool check does not advance a review state. For a one-format request, record the changed delivery contract and use only its relevant acceptance gate.

## Version and naming contract

Keep candidate and formal content versions distinguishable. One possible pattern is `v1.2.0-candidate.3` for a working copy and `v1.2.0` for the approved content version; use an existing project convention when present. The candidate-to-formal promotion records source file, date, approving user, scope/language, and checks. The PDF inherits the content version but retains its own pending/approved status. Never overwrite an older accepted version to make a new one appear current.

Filenames should identify the person, language, purpose, content version, and date in the **person's private workspace**. Do not carry filenames or identity data into reusable Skill resources. Keep each language's approval independent and identify an accepted bilingual pair explicitly when needed.

## File review checklist

- Word: editable content, full text and factual comparison to approved modules, every-page render, usable fonts/icons, page count and balance, visible file in the user's file manager, and actual-user approval of the exact candidate.
- PDF: exported from that approved Word, searchable/copyable text, every-page visual review, expected page count, stable fonts/icons and pagination, visible/openable file, and separate actual-user approval.
- Delivery report: list the exact approved files, versions and source candidate, what was validated, what remains unverified in the user's native viewer, and what was not authorized (such as submission or publication).
