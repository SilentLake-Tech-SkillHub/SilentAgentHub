#!/usr/bin/env python3
"""Render Xiaohongshu/RedNote note and comment evidence JSON as Markdown."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path
from typing import Any


COUNT_UNITS = {
    "w": 10000,
    "W": 10000,
    "万": 10000,
    "k": 1000,
    "K": 1000,
    "千": 1000,
}


def parse_count(value: Any) -> int:
    if value is None:
        return 0
    if isinstance(value, (int, float)):
        return int(value)
    text = str(value).strip().replace(",", "")
    if not text:
        return 0
    text = text.replace("+", "")
    match = re.match(r"^(\d+(?:\.\d+)?)([wWkK万千]?)", text)
    if not match:
        return 0
    number = float(match.group(1))
    unit = match.group(2)
    return int(number * COUNT_UNITS.get(unit, 1))


def value_count(item: dict[str, Any]) -> int:
    return parse_count(item.get("like_count", item.get("like_count_raw")))


def as_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def clean_text(value: Any) -> str:
    text = "" if value is None else str(value)
    return re.sub(r"\s+", " ", text).strip()


def md_escape(value: Any) -> str:
    text = clean_text(value)
    return text.replace("|", "\\|")


def validate(data: dict[str, Any], strict: bool) -> list[str]:
    warnings: list[str] = []
    keywords = as_list(data.get("keywords"))
    notes = as_list(data.get("notes"))

    if not clean_text(data.get("topic")):
        warnings.append("top-level topic is missing")
    if not (3 <= len(keywords) <= 5):
        warnings.append(f"keywords should contain 3-5 entries; got {len(keywords)}")
    if not notes:
        warnings.append("notes is empty")

    for index, note in enumerate(notes, start=1):
        prefix = f"note {index}"
        if not clean_text(note.get("url")):
            warnings.append(f"{prefix}: url is missing")
        if not (clean_text(note.get("published_at")) or clean_text(note.get("published_at_raw"))):
            warnings.append(f"{prefix}: publish date is missing")
        if not (note.get("like_count") is not None or clean_text(note.get("like_count_raw"))):
            warnings.append(f"{prefix}: like count is missing")
        if not clean_text(note.get("content_summary")):
            warnings.append(f"{prefix}: content_summary is missing")
        comments = as_list(note.get("comments"))
        for comment_index, comment in enumerate(comments, start=1):
            if not (clean_text(comment.get("summary")) or clean_text(comment.get("quote"))):
                warnings.append(f"{prefix} comment {comment_index}: summary or quote is missing")

    if strict and warnings:
        raise SystemExit("Strict validation failed:\n- " + "\n- ".join(warnings))
    return warnings


def sort_notes(notes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(notes, key=lambda note: value_count(note), reverse=True)


def sort_comments(comments: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(comments, key=lambda comment: value_count(comment), reverse=True)


def render_markdown(data: dict[str, Any], warnings: list[str]) -> str:
    topic = clean_text(data.get("topic")) or "小红书评论搜索"
    generated_at = clean_text(data.get("generated_at")) or dt.datetime.now().isoformat(timespec="seconds")
    collection_date = clean_text(data.get("collection_date")) or generated_at[:10]
    keywords = [clean_text(item) for item in as_list(data.get("keywords")) if clean_text(item)]
    limits = [clean_text(item) for item in as_list(data.get("collection_limits")) if clean_text(item)]
    notes = sort_notes([note for note in as_list(data.get("notes")) if isinstance(note, dict)])[:20]

    lines: list[str] = [
        f"# 小红书评论搜索：{topic}",
        "",
        f"- 生成时间：{generated_at}",
        f"- 采集日期：{collection_date}",
        f"- 搜索关键词：{', '.join(keywords) if keywords else '未记录'}",
        f"- 入选帖子数：{len(notes)}",
        "",
    ]

    if limits or warnings:
        lines.extend(["## 采集限制与注意事项", ""])
        for item in limits:
            lines.append(f"- {item}")
        for warning in warnings:
            lines.append(f"- 数据校验提示：{warning}")
        lines.append("")

    lines.extend([
        "## TOP帖子总览",
        "",
        "| 排名 | 点赞 | 发布时间 | 关键词 | 标题/摘要 | 链接 |",
        "|---:|---:|---|---|---|---|",
    ])

    for rank, note in enumerate(notes, start=1):
        title = clean_text(note.get("title")) or clean_text(note.get("content_summary"))[:40] or "未命名帖子"
        date_text = clean_text(note.get("published_at")) or clean_text(note.get("published_at_raw")) or "未知"
        keyword = clean_text(note.get("keyword")) or "未记录"
        url = clean_text(note.get("url"))
        link = f"[打开]({url})" if url else "未记录"
        lines.append(
            f"| {rank} | {value_count(note)} | {md_escape(date_text)} | {md_escape(keyword)} | {md_escape(title)} | {link} |"
        )

    lines.append("")
    lines.append("## 帖子与评论详情")
    lines.append("")

    for rank, note in enumerate(notes, start=1):
        title = clean_text(note.get("title")) or f"帖子 {rank}"
        url = clean_text(note.get("url"))
        author = clean_text(note.get("author")) or "未记录"
        date_text = clean_text(note.get("published_at")) or clean_text(note.get("published_at_raw")) or "未知"
        relevance = clean_text(note.get("relevance")) or "未记录"
        summary = clean_text(note.get("content_summary")) or "未记录"
        evidence_notes = [clean_text(item) for item in as_list(note.get("evidence_notes")) if clean_text(item)]
        comments = sort_comments([item for item in as_list(note.get("comments")) if isinstance(item, dict)])[:20]

        lines.extend([
            f"### {rank}. {title}",
            "",
            f"- 链接：{url or '未记录'}",
            f"- 作者：{author}",
            f"- 发布时间：{date_text}",
            f"- 帖子点赞：{value_count(note)}",
            f"- 相关性：{relevance}",
            f"- 内容摘要：{summary}",
        ])
        for note_text in evidence_notes:
            lines.append(f"- 采集备注：{note_text}")
        lines.extend([
            "",
            "| 评论排名 | 点赞 | 情绪 | 评论者 | 时间 | 评论观点 |",
            "|---:|---:|---|---|---|---|",
        ])
        if comments:
            for comment_rank, comment in enumerate(comments, start=1):
                comment_text = clean_text(comment.get("summary")) or clean_text(comment.get("quote")) or "未记录"
                quote = clean_text(comment.get("quote"))
                if quote and quote not in comment_text:
                    comment_text = f"{comment_text}；短引文：{quote}"
                lines.append(
                    "| "
                    f"{comment_rank} | "
                    f"{value_count(comment)} | "
                    f"{md_escape(comment.get('sentiment') or 'unknown')} | "
                    f"{md_escape(comment.get('author') or '未记录')} | "
                    f"{md_escape(comment.get('published_at') or comment.get('published_at_raw') or '未知')} | "
                    f"{md_escape(comment_text)} |"
                )
        else:
            lines.append("| - | - | - | - | - | 未采集到可见评论 |")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="Evidence JSON path")
    parser.add_argument("--output", required=True, type=Path, help="Markdown report path")
    parser.add_argument("--strict", action="store_true", help="Fail when required evidence is missing")
    args = parser.parse_args()

    data = json.loads(args.input.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit("Input JSON must be an object")
    warnings = validate(data, args.strict)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render_markdown(data, warnings), encoding="utf-8")
    print(f"Wrote {args.output}")
    if warnings and not args.strict:
        print("Warnings:", file=sys.stderr)
        for warning in warnings:
            print(f"- {warning}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
