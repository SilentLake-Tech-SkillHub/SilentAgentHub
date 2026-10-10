---
name: markdown-rendered-pdf
description: Render one or many Markdown (.md) files into styled PDF files with Chinese-safe fonts, preserving headings/lists/code/table layout instead of raw markdown symbols. Use when the user asks to batch convert markdown to PDF, replace existing PDFs, or avoid Chinese garbled text.
---

# Markdown Rendered PDF

Use the bundled script to render markdown content into visually formatted PDF files.

## Workflow

1. Run the script on a single file or a directory.
2. Use `--replace` when the user requests deleting old PDFs first.
3. Keep output PDFs alongside source `.md` files (same basename).

## Commands

Single file:

```bash
python3 scripts/render_markdown_to_pdf.py --input /path/to/file.md
```

Batch folder:

```bash
python3 scripts/render_markdown_to_pdf.py --input /path/to/folder --glob '*.md'
```

Replace old PDFs then regenerate:

```bash
python3 scripts/render_markdown_to_pdf.py --input /path/to/folder --glob '*.md' --replace
```

## Notes

- Prefer this skill when `pandoc/wkhtmltopdf` are unavailable.
- Rendering is deterministic and does not require network.
- Chinese text is rendered with system CJK fonts to avoid garbled output.
