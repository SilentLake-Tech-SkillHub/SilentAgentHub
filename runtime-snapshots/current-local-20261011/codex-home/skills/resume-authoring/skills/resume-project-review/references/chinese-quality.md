# Chinese document quality

Use this for Chinese Word/PDF generation and when the user reports garbled text or a defective screenshot.

## Establish the actual defect

Locate the reported file, version, page and viewing surface. Inspect the source text, Word XML and rendered screenshot. A garbled early screenshot and a later fixed candidate are separate evidence. Check the current result; do not call the defect fixed solely because the DOCX text reads correctly.

Distinguish corrupted characters from missing glyphs, unsupported/substituted fonts, layout overlap and literal Markdown. Read text files as strict UTF-8; never repair damaged text by decoding with ignored/replacement errors. Inspect replacement characters, accidental control characters and suspicious private-use glyphs in context. Preserve legitimate symbols only with evidence that the requested font renders them.

## Preflight before presenting screenshots

1. Resolve the document runtime and renderer from the document Skill. Check which Chinese font is available to that renderer and the target viewer. Set Chinese run/style font explicitly or use a verified renderer mapping. Western font settings alone do not establish CJK coverage.
2. For macOS rendering of documents using SimSun, a verified Fontconfig alias to an installed Chinese font such as Songti SC can fix a renderer/font mismatch. Reuse a configured mapping if available; record it in the private run. Do not hard-code one person's absolute font configuration path in this Skill or assume the alias proves native Word/WPS compatibility.
3. Generate the versioned candidate with native bold and hyperlinks. Check that neither `**` nor `[label](url)` appears as document text. Display the intended domain, preserve the hyperlink target, and check paragraph separation.
4. Run `scripts/check_resume_text.py --docx <candidate>`. Supply `--approved-text <private plain-text snapshot>` for approval readback when that snapshot represents the exact intended document. Use an output path inside the private workspace.
5. Render the candidate to all page images using the document Skill. Inspect all pages for Chinese glyphs, screenshots with tofu/blank glyphs, line clipping, photo overlaps, title/date alignment, sparse final pages and unreadable density. Fix the underlying cause and rerender before showing a defective screenshot as a result. Diagnostic screenshots may be identified as such when needed to explain the real issue.
6. Extract rendered PDF text and rerun with `--rendered-text <extracted text>`. Every Word paragraph, including hyperlink display text, must survive extraction. Inspect reported misses rather than silently ignoring them. Page counters or line-break variants can require a documented comparison adjustment.
7. If the defect occurs in native Word/WPS or an in-app preview, verify the corrected exact file in that reported surface. Inspect screenshot evidence after opening it. If the report concerns an early renderer screenshot and the final render already resolves it, record that distinction and recheck the final render. Do not rewrite approved content to fix a font failure.

## User-requested Chinese spacing

Honor the person's explicit Chinese/Latin/numeric spacing preference. When the person requests no extra spaces, remove actual spaces at those boundaries across the whole paragraph, including boundaries between runs and hyperlink display text; preserve native emphasis, English phrase word boundaries, identifiers and hyperlink targets. Do not assign whole-paragraph text and destroy its runs.

Also disable Word's automatic Chinese–Latin and Chinese–numeric spacing: set `w:autoSpaceDE` and `w:autoSpaceDN` to `w:val="0"` on affected paragraph properties and inherited style defaults. Removing literal spaces alone does not remove the viewer's generated visual spacing. Do not mistake glyph side bearings for literal spaces or alter the approved font to hide them.

Use `scripts/normalize_cjk_spacing.py --input <source.docx> --output <new-candidate.docx>` from the document runtime when this preference is active. It preserves run formatting and URLs, edits boundaries across runs, disables paragraph/style automatic spacing, and refuses to overwrite an existing file. Run the checker with `--no-cjk-latin-spaces` when this preference is active; this checks both actual boundary spaces and explicit disabled automatic spacing. Compare every paragraph before/after with whitespace ignored, verify unchanged links/formatting, and rerender all pages. Keep the person's spacing preference in private run configuration; the reusable option supports other people's choices without imposing this preference universally.

Specification references: [Chinese–Latin spacing](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.wordprocessing.autospacede?view=openxml-3.0.1), [Chinese–numeric spacing](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.wordprocessing.autospacedn?view=openxml-3.0.1).

## Consistent typography by role

When the person reports different sizes for education and work, inspect effective run/style sizes in both instead of diagnosing from apparent screenshot scale. Use the person's selected section as the private baseline and align equivalent body, institution/company and date roles; preserve name and section-heading hierarchy. Inspect project headings with the same hierarchy. Record actual before/after sizes privately and verify that text, bold, links, images and non-size formatting survive. Do not impose a particular person's point sizes on other resumes. Produce a separate repair candidate and review all rendered pages.

## Recovery and shipping

Keep earlier files as recovery baselines and create a new candidate for an actual document change. Compare approved claims and numeric values after any repair. Internal rendering PDFs/images stay QA evidence; only the requested deliverable is returned. Word approval precedes delivery PDF export, and PDF approval remains separate. User-reported defects reopen the affected file gate; a checker pass never substitutes for user acceptance.

## Clipping and date alignment

Run `scripts/check_resume_layout.py --docx <file> --output <private-report.json>` from this child Skill for a reported clipped name/title or inconsistent date alignment. It checks inherited fixed paragraph line height against effective run size and date tabs against the section text edge and paragraph right indent. It is a preflight, not proof of visible glyph bounds; inspect all rendered pages and the reported Word/WPS surface when available. If that viewer is unavailable, record the failure and keep file acceptance pending.

Fix large text by overriding its paragraph with automatic or adequate minimum line height; do not shrink the name or replace the whole document style. Unify date-row right tabs using effective width, preserve date run formatting, remove only trailing alignment spaces and check each long institution/company label. Read back the unchanged wording and unaffected properties. The default values live in the parent `assets/default-format.json`; user templates and explicit changes override them per property.


## Full template fidelity and real copies

For overall format feedback, inspect the selected accepted template and the current file together. Check the same work/project section for native list markers, hanging indents, section borders, heading colors, paragraph spacing and typography. Compare semantic role properties, not only shared text or an education/header screenshot. Preserve the current approved facts. Name/date checks do not cover the full format system. Before claiming repair, verify that every authorized actual deliverable copy equals the reviewed repair and provide a legible relevant-section result when the user reports a visual defect.


For a selected format with differentiated priority groups, check category labels plus the actual sizes/colors of one priority and one ordinary project together. Do not pass a restoration that colors every project alike or removes the grouping. Inspect the original PDF to identify its visible hierarchy, then use matching Word properties; reference identity approval is not an application attachment receipt.


## Visible Chinese bold

For weak or missing heading/label emphasis, inspect native `w:b` and `w:bCs`, style inheritance, `w:rFonts` East Asian font/theme, and the actual font selected in the render. An existing bold flag or a bold Latin span does not prove a visibly bold Chinese span. Compare the same heading and an approved colon-label with adjacent regular text at readable scale. Preserve the user's selected family, sizes and colors; when feedback requests stronger emphasis, choose an available heavier face in that family and record it privately. Verify the requested face exists and the rendered CJK spans use it rather than silently falling back to another family. If a renderer needs a face-name mapping, validate that mapping separately and retain native viewer review as a distinct check.

Apply native bold to all relevant heading/category/project roles and only the approved label prefix before the colon. Preserve dates, remaining body text and existing keyword emphasis. Do not make the whole bullet bold or insert Markdown stars. Read back both actual deliverables and inspect every page; stronger weight can change wrapping. Keep machine-specific font paths and private examples outside the Skill.
