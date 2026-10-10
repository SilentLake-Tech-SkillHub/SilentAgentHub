# Writing and layout decisions

Read this when selecting an information hierarchy, drafting bullets, revising tone, or comparing with an accepted prior resume. This is a decision guide, not a mandated visual template.

## Start with the reader's scan

Place role-relevant, evidenced strengths where the intended reader can find them quickly. Use institution/company rows, dates, project titles, and restrained emphasis to separate contexts. A logo or icon may help identify an organization only when its source and use are supportable; if not, omit it. Color and font size can reinforce a true priority, but must not fabricate one or make other experience unreadable. Capture whether the requested page count is exact, a maximum, or unconstrained at intake. Use content-preserving compression first and role-based selection when still needed, following [resume-compression](../skills/resume-compression/SKILL.md). Keep type readable and follow the agreed deletion/review authority to reach the actual page target.

If the person has an accepted version, inspect its actual Word and PDF, note page size/count, hierarchy, visual weight, language, content selection, and fonts on the target viewing system. Preserve recognizable continuity unless the new role, facts, or user feedback justify change. Explain meaningful deviations; do not demand identical wording or assume different language versions are aligned line by line.

## Write the contribution, not a component inventory

A strong experience sentence usually communicates the problem or goal, the person's action and decision, a necessary mechanism, and a substantiated result. It need not force all four into every bullet. Prefer specific verbs and readable sentences. Keep technical terms when they explain a decision or achievement; remove stack lists that add no evidence. Distinguish project status and contribution from results.

Use short labels, selective bold, or a single process chain only when they improve scanning. Do not prefix every bullet with `Label:` or replace explanations with repeated arrow chains or equations. Also avoid overcorrecting into conversational first-person narration. In Chinese, a concise omitted subject often reads naturally; in English, lead with an action verb where appropriate. Read each bullet aloud: can it stand as a professional sentence without its label?

Make AI-related work visible only if its actual work, responsibility, and outcome justify it. Keep data product, operations, analytics, or other non-AI work in truthful categories. Compress long employers by selecting the most role-relevant, evidence-rich projects, not by removing all context or enlarging AI claims.

## Visual QA

Inspect every page of the actual Word render and exported PDF. Check company rows, date alignment, title hierarchy, icon scale/source, line breaks, font substitution, page balance, clipping, and text searchability. A near-empty final page or tiny body text is a reason to revise the layout rather than imitate a supplied reference. Automated rendering cannot replace the person's view in their Word/WPS and PDF reader.

## Preserve the actual format baseline

Identify the exact accepted or explicitly chosen style reference separately from the content source. Record page size/margins, font families, body/date/title sizes, line-spacing rule and value, before/after paragraph spacing, indents, tabs/alignment, heading colors/shading, bold hierarchy, icons/photo anchors and header/footer behavior. Wording compression changes text; it does not authorize a redesign. A request to unify one font size permits that change, not a replacement of line spacing, paragraph spacing, title styles or emphasis across the document.

Compare the actual paragraph and run properties for mapped source/output paragraphs, including properties stored inside `word/document.xml`. Checking only `styles.xml`, package assets and page margins misses substantial visual changes. Preserve meaningful native emphasis through text replacement and review its positions in the rewritten text; do not rebuild bold indiscriminately from keyword lists. Read back the formatting changes against the authorized list and inspect representative matching sections in the same renderer/viewer, then inspect every final page. Pagination caused by shorter content is expected, but it does not justify unrelated formatting drift.

## Default format and user overrides

The independent [default format](../assets/default-format.json) defines page geometry, typography roles, spacing, emphasis and date alignment. It is a fallback. Explicit user changes take precedence over the selected user template; unspecified properties come from that template before defaults. For existing files, preserve the selected format and patch the reported property only. Record conflicting sources and effective resolved properties in the caller workspace. An offered template or user page limit does not grant unrelated redesign or smaller type.

Resolve effective paragraph/run properties through style inheritance. A name may inherit a fixed body line height even without `w:line` in its paragraph XML. Use automatic or adequate minimum height for large text, preserving its chosen size. For date rows, use a right-aligned tab at the page text edge adjusted for section margins and paragraph indents; strip trailing alignment padding, preserve the left label and check long labels for overlap/wrapping.


## Full format restoration

Distill the selected accepted format by semantic role before editing: font/color/size, line and paragraph spacing, numbering and hanging indent, borders/shading, alignment/tabs, emphasis, image placement and recurring page elements. Map each current-content paragraph to a source role, preserving the approved content and explicit overrides. Reuse the source numbering and role properties rather than flattening project bullets into plain paragraphs. Capture meaningful before/after examples from the same section and inspect every final page. List markers, section rules and heading colors are material source components when the selected template uses them.

A narrow clipping/date checker is only one preflight. Record full-template fidelity evidence separately and verify the exact files in the actual deliverable folder; a corrected candidate does not repair another copy. Keep recovery copies before an authorized in-place format correction.


## Category and priority hierarchy

When the selected reference distinguishes priority work through category headings, color and font size, record and reproduce each distinct role. Map both a priority and an ordinary project as a fidelity pair; do not map all project titles to a single generic heading. Preserve category labels as structural headings while retaining the approved project text. For an AI-focused reference, keep AI work separate from ordinary data, operations or research work according to the actual project substance. Apply this focus only when selected for the current person. A later explicit choice of that differentiated hierarchy governs the affected title roles; retain prior body-size and date-alignment requirements.

Before calling restoration complete, inspect the selected original PDF as well as its corresponding Word. A similar filename, a newer version or a passing color check does not identify the intended reference. If its identity is ambiguous, show the actual relevant section for a minimal reference confirmation and keep application/upload identity separate from template selection.
