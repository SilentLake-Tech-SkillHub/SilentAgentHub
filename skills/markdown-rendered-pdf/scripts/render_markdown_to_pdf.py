#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path
from typing import List

import markdown
from PIL import Image, ImageDraw, ImageFont


@dataclass
class Block:
    kind: str
    text: str = ""
    level: int = 0
    rows: List[List[str]] | None = None


class MDHTMLParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.blocks: List[Block] = []
        self.stack: List[str] = []
        self.list_stack: List[dict] = []
        self.buffer: List[str] = []

        self.in_table = False
        self.table_rows: List[List[str]] = []
        self.current_row: List[str] = []
        self.in_cell = False
        self.cell_buf: List[str] = []

        self.in_pre = False

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        self.stack.append(tag)

        if tag in ("ul", "ol"):
            self.list_stack.append({"type": tag, "index": 0})
        elif tag == "br":
            self._push_text("\n")
        elif tag == "pre":
            self.in_pre = True
            self.buffer = []
        elif tag == "table":
            self.in_table = True
            self.table_rows = []
        elif tag == "tr" and self.in_table:
            self.current_row = []
        elif tag in ("th", "td") and self.in_table:
            self.in_cell = True
            self.cell_buf = []

    def handle_endtag(self, tag):
        tag = tag.lower()

        if tag in ("h1", "h2", "h3", "h4", "h5", "h6"):
            txt = self._flush_inline()
            if txt:
                self.blocks.append(Block(kind="heading", text=txt, level=int(tag[1])))
        elif tag == "p":
            txt = self._flush_inline()
            if txt:
                self.blocks.append(Block(kind="paragraph", text=txt))
        elif tag == "li":
            txt = self._flush_inline()
            if txt:
                depth = len(self.list_stack)
                prefix = "- "
                if self.list_stack:
                    top = self.list_stack[-1]
                    if top["type"] == "ol":
                        top["index"] += 1
                        prefix = f"{top['index']}. "
                indent = "  " * max(0, depth - 1)
                self.blocks.append(Block(kind="list", text=f"{indent}{prefix}{txt}"))
        elif tag in ("ul", "ol"):
            if self.list_stack:
                self.list_stack.pop()
        elif tag == "pre":
            txt = "".join(self.buffer).rstrip("\n")
            self.in_pre = False
            self.buffer = []
            if txt:
                self.blocks.append(Block(kind="code", text=txt))
        elif tag in ("th", "td") and self.in_table:
            self.in_cell = False
            cell = self._normalize("".join(self.cell_buf))
            self.current_row.append(cell)
            self.cell_buf = []
        elif tag == "tr" and self.in_table:
            if self.current_row:
                self.table_rows.append(self.current_row)
            self.current_row = []
        elif tag == "table":
            self.in_table = False
            if self.table_rows:
                self.blocks.append(Block(kind="table", rows=self.table_rows))
            self.table_rows = []
        elif tag == "hr":
            self.blocks.append(Block(kind="hr"))

        if self.stack and self.stack[-1] == tag:
            self.stack.pop()

    def handle_data(self, data):
        if not data:
            return
        if self.in_cell:
            self.cell_buf.append(data)
            return
        self._push_text(data)

    def _push_text(self, data: str):
        if self.in_pre:
            self.buffer.append(data)
            return
        self.buffer.append(data)

    def _flush_inline(self) -> str:
        text = self._normalize("".join(self.buffer))
        self.buffer = []
        return text

    @staticmethod
    def _normalize(text: str) -> str:
        text = text.replace("\xa0", " ")
        text = re.sub(r"[ \t\r\f\v]+", " ", text)
        text = re.sub(r"\n\s*", "\n", text)
        return text.strip()


def load_font(candidates: List[str], size: int):
    for p in candidates:
        if Path(p).exists():
            try:
                return ImageFont.truetype(p, size=size)
            except Exception:
                pass
    return ImageFont.load_default()


def text_width(draw: ImageDraw.ImageDraw, text: str, font) -> int:
    if not text:
        return 0
    x0, y0, x1, y1 = draw.textbbox((0, 0), text, font=font)
    return x1 - x0


def wrap_text(draw: ImageDraw.ImageDraw, text: str, font, max_width: int) -> List[str]:
    if not text:
        return [""]
    out: List[str] = []
    for para in text.split("\n"):
        para = para.strip()
        if not para:
            out.append("")
            continue
        cur = ""
        for ch in para:
            trial = cur + ch
            if text_width(draw, trial, font) <= max_width:
                cur = trial
            else:
                if cur:
                    out.append(cur)
                cur = ch
        if cur:
            out.append(cur)
    return out or [""]


def render_blocks_to_pages(blocks: List[Block], out_pdf: Path, title: str = "") -> None:
    page_w, page_h = 1240, 1754
    margin = 80
    content_w = page_w - 2 * margin

    font_regular = load_font([
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
        "/System/Library/Fonts/Songti.ttc",
    ], 28)
    font_small = load_font([
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    ], 24)
    font_h1 = load_font([
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
    ], 44)
    font_h2 = load_font([
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
    ], 36)
    font_h3 = load_font([
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
    ], 32)
    font_code = load_font([
        "/System/Library/Fonts/SFNSMono.ttf",
        "/System/Library/Fonts/SFNSMonoItalic.ttf",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
    ], 24)

    pages: List[Image.Image] = []
    img = Image.new("RGB", (page_w, page_h), "white")
    draw = ImageDraw.Draw(img)
    y = margin

    def new_page():
        nonlocal img, draw, y
        pages.append(img)
        img = Image.new("RGB", (page_w, page_h), "white")
        draw = ImageDraw.Draw(img)
        y = margin

    def ensure_space(h: int):
        nonlocal y
        if y + h > page_h - margin:
            new_page()

    if title:
        for ln in wrap_text(draw, title, font_h1, content_w):
            ensure_space(64)
            draw.text((margin, y), ln, fill="#111", font=font_h1)
            y += 58
        y += 12

    for b in blocks:
        if b.kind == "heading":
            font = font_h1 if b.level <= 1 else (font_h2 if b.level == 2 else font_h3)
            line_h = 64 if b.level <= 1 else (52 if b.level == 2 else 46)
            lines = wrap_text(draw, b.text, font, content_w)
            ensure_space(len(lines) * line_h + 14)
            for ln in lines:
                draw.text((margin, y), ln, fill="#111", font=font)
                y += line_h
            y += 8

        elif b.kind in ("paragraph", "list"):
            lines = wrap_text(draw, b.text, font_regular, content_w)
            ensure_space(len(lines) * 42 + 8)
            for ln in lines:
                draw.text((margin, y), ln, fill="#111", font=font_regular)
                y += 42
            y += 4

        elif b.kind == "code":
            code_lines: List[str] = []
            for ln in b.text.split("\n"):
                code_lines.extend(wrap_text(draw, ln, font_code, content_w - 24))
            box_h = max(50, len(code_lines) * 34 + 20)
            ensure_space(box_h + 8)
            draw.rectangle([margin, y, margin + content_w, y + box_h], outline="#d0d7de", fill="#f6f8fa", width=1)
            cy = y + 10
            for ln in code_lines:
                draw.text((margin + 12, cy), ln, fill="#222", font=font_code)
                cy += 34
            y += box_h + 8

        elif b.kind == "table" and b.rows:
            rows = b.rows
            ncols = max((len(r) for r in rows), default=1)
            ncols = max(ncols, 1)
            col_w = content_w / ncols
            pad = 6
            for ridx, row in enumerate(rows):
                cells = row + [""] * (ncols - len(row))
                wrapped = [wrap_text(draw, c, font_small, int(col_w - 2 * pad)) for c in cells]
                row_h = max(len(w) for w in wrapped) * 32 + 2 * pad
                ensure_space(int(row_h) + 2)
                for cidx in range(ncols):
                    x0 = int(margin + cidx * col_w)
                    x1 = int(margin + (cidx + 1) * col_w)
                    draw.rectangle([x0, y, x1, int(y + row_h)], outline="#9ca3af", fill="#f3f4f6" if ridx == 0 else "white", width=1)
                    ty = y + pad
                    for ln in wrapped[cidx]:
                        draw.text((x0 + pad, ty), ln, fill="#111", font=font_small)
                        ty += 32
                y += int(row_h)
            y += 8

        elif b.kind == "hr":
            ensure_space(20)
            draw.line([margin, y + 8, margin + content_w, y + 8], fill="#d1d5db", width=2)
            y += 20

    pages.append(img)
    rgb_pages = [p.convert("RGB") for p in pages]
    rgb_pages[0].save(out_pdf, save_all=True, append_images=rgb_pages[1:], resolution=160)


def md_to_blocks(md_text: str) -> List[Block]:
    html = markdown.markdown(md_text, extensions=["extra", "tables", "fenced_code", "sane_lists"])
    parser = MDHTMLParser()
    parser.feed(html)
    return parser.blocks


def convert_file(md_path: Path, pdf_path: Path) -> None:
    blocks = md_to_blocks(md_path.read_text(encoding="utf-8"))
    render_blocks_to_pages(blocks, pdf_path, title=md_path.stem)


def main() -> int:
    ap = argparse.ArgumentParser(description="Render markdown to styled PDF with Chinese-safe fonts")
    ap.add_argument("--input", required=True, help="Input markdown file or directory")
    ap.add_argument("--glob", default="*.md", help="Glob for directory mode")
    ap.add_argument("--replace", action="store_true", help="Delete existing PDFs in directory before regenerating")
    args = ap.parse_args()

    src = Path(args.input)
    if not src.exists():
        raise SystemExit(f"Input not found: {src}")

    if src.is_file():
        if src.suffix.lower() != ".md":
            raise SystemExit("Input file must be .md")
        out = src.with_suffix(".pdf")
        convert_file(src, out)
        print(f"OK: {out}")
        return 0

    if args.replace:
        for old in src.glob("*.pdf"):
            old.unlink()

    mds = sorted(src.glob(args.glob))
    for md in mds:
        out = md.with_suffix(".pdf")
        convert_file(md, out)
        print(f"OK: {out.name}")

    print(f"TOTAL={len(mds)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
