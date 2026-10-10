---
name: resume-authoring
description: Create or revise a resume/CV (简历) from a person's own evidence through section-by-section approval, editable Word review, separate PDF acceptance, and versioned delivery. Use for resume production, not ordinary document edits.
---

# Resume authoring

Help one person produce a credible, readable resume without transferring another person's facts or layout by default. Treat source fidelity, section approvals, Word approval, and PDF approval as separate gates. A generated file or passing check is not user acceptance.

## Start from the current person

1. Identify the target role, audience/region, language, target page count (exact, maximum, or no fixed limit), deliverables, source materials, factual constraints, and the person's preferred workspace layout. Explicitly ask whether an accepted prior resume and existing workspace convention exist when the request does not say; do not silently treat their absence from the prompt as “none.” Before drafting the first module, identify the intended module order and the accepted baseline, if any. Inspect that baseline in the person's private workspace. Do not infer approval from a filename such as “final.”
2. If the person supplies a style reference, inspect its actual pages, company rows, icons, hierarchy, density, language, and sentence construction. Separate useful methods from flaws. A reference is not a source of the person's facts, metrics, links, branding rights, or approved page count.
3. Do not create or migrate folders when the person already has a workspace convention until the difference and intended change are confirmed. For a new workspace, offer the shallow five-zone structure in [approval and versions](references/approval-and-versions.md).

Read [intake and evidence](references/intake-and-evidence.md) before drafting claims. Read [writing and layout](references/writing-and-layout.md) when choosing structure or revising prose. Before shortening or selection, identify and inspect the exact format baseline separately from the content source; preserve its actual paragraph/run formatting except for specifically authorized changes. Read [approval and versions](references/approval-and-versions.md) before creating files, advancing a review state, or delivering. Start the first accepted formal resume content release at `V1.0.0` or higher; keep the Skill package version independent. Record an explicitly approved version correction as a byte-preserving promotion with source identity, approval and hashes.

## Resolve the format separately from content

Read [default-format.json](assets/default-format.json) when selecting or auditing formatting. It is a standalone fallback format, not authority to replace a user template. Resolve precedence per property: current explicit user requirements → user-provided template or selected accepted format → defaults. Inspect a supplied Word/PDF visually and in its actual paragraph/run properties, record the resolved role styles privately, and apply only authorized changes. Keep all user materials outside this package.

A request to restore or fix formatting refers to the selected format system: paragraph roles, lists and hanging indents, heading hierarchy/colors/rules, spacing, run emphasis, date rows and page furniture. Inspect representative matching sections of the actual accepted source and current file before deciding scope. Address individual reported defects within that broader explicit request; a name/date preflight does not establish template fidelity. The result must reach the actual in-use deliverables, backed up and read back, as well as any review copy. Preserve the selected reference’s category/priority distinctions as separate roles; a generic project-heading style must not flatten different groups into one color and size. Confirm an ambiguous reference with a legible original-section image before editing.

For reported weak or missing Chinese bold, read [Chinese document quality](skills/resume-project-review/references/chinese-quality.md) and verify the visible CJK font weight as well as native bold flags; compare a heading/label with adjacent regular text.

For reported clipping or date alignment, read [Chinese document quality](skills/resume-project-review/references/chinese-quality.md) and run its layout checker before and after repair; inherited styles can override an apparently empty paragraph setting. Keep larger headings clear of fixed body line heights and use a shared effective right edge for date rows.

## Long resume, compressed resume, and target-length short resume

Within each requested language, default to **long resume → content-preserving compressed resume → target-length short resume when needed**, unless the person explicitly chooses another order. Review the complete long source first and record its accepted version. Read [resume-compression](skills/resume-compression/SKILL.md) for sentence-level shortening, keyword preservation, compression stages, or a request to fit a page target.

A compressed resume shortens wording while retaining the substantive projects, facts, design decisions and outcomes. It can be the final deliverable when it meets the person's initial length requirement, or when no fixed page limit is required and that scope is agreed. If its rendered page count exceeds the target, perform a separate role-based selection/deletion stage to make the target-length short resume. Record the complete omitted or merged passages and their rationale in the private deletion ledger, and use [resume-project-review](skills/resume-project-review/SKILL.md) for the required full original/proposed review. Do not report compression as achievement of a page target that has not been reached.

Record language, stage/purpose, target pages, actual rendered pages, source content version, format baseline and approvals independently. Keep the long source and compressed source intact. Honor explicit review waivers for their stated scope and round; record the authority and continue the authorized work with text and visual checks. A previous waiver does not silently carry into the next deletion round. Do not infer approval of one stage or format from another.

After long Word approval, short-content review may begin while the long PDF awaits its separate review; export each PDF only from its corresponding approved Word. Honor the person's language order independently of length order.

## Detailed project review and feedback

For project-by-project revision, preserve-and-compress requests, complete original/proposed comparisons, or repeated feedback, load the independent child Skill [resume-project-review](skills/resume-project-review/SKILL.md). Its review unit is one whole project; honor a user-requested batch for school projects or a requested consolidation of one role. Apply accepted feedback across the affected resume and current candidate.

For Chinese Word/PDF creation or reports of garbled Chinese, load [Chinese document quality](skills/resume-project-review/references/chinese-quality.md) before showing screenshots or delivering files. Run the child Skill's text checker alongside full-page rendering; passing a text check does not establish visual quality.

## Work through the review gates

- Build a private fact ledger. Mark the source and certainty of each claim, the person's contribution, dates, metric definitions, and whether work is launched, in progress, or planned. Ask about conflicts that would change the resume; never fill them with plausible-sounding facts.
- Draft one whole project at a time when the user requests project review; otherwise use the agreed module order, such as education, work, projects, or skills. Follow any explicit waiver of that review step within its stated scope and round; Show the facts used, key inclusion/exclusion decisions, and proposed wording. Incorporate feedback and obtain the required module approval before proceeding, or record the user’s explicit waiver. A request for a whole resume does not silently waive module review.
- After all required modules are approved or covered by explicit review waiver, produce a separate editable Word candidate. Render every page, inspect text and visual layout, and follow the agreed review contract for that exact file, including an explicit in-scope review waiver. Revisions retain candidate identity and invalidate affected approvals.
- Only after Word approval, export the corresponding PDF. Check its full text and every page, including fonts, icons, pagination, and file visibility; ask for separate PDF approval. Delivery is complete only after both requested formats pass their user gates. If the person explicitly changes the deliverable to one format, record that scope change rather than pretending both were accepted.
- Keep languages distinct: verify shared facts across versions, but do not assume two languages are paragraph-for-paragraph translations or approved as a pair unless the person names the exact pair.

## Boundaries

Use the person's own current materials only at runtime in their private workspace. Do not embed or cache those materials, excerpts, images, icons, personal paths, hashes, or identifying metadata in this Skill or in reusable examples and fixtures. Do not publish, submit a job application, modify a public profile, or promote a resume on the person's behalf without the separate authority those actions require. Reuse document/PDF capabilities available in the environment for file work; do not treat this Skill as a fixed template or a universal document generator.
