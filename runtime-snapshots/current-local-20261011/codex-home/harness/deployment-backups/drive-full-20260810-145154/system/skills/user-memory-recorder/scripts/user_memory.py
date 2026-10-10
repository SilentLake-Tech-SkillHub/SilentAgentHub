#!/usr/bin/env python3
"""Manage per-session verbatim user request memory for Codex projects."""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


STATUS_OPEN = "未完成"
STATUS_DONE = "已完成"
VALID_STATUSES = {STATUS_OPEN, STATUS_DONE}
HEAD_NAME = "MEMORY_HEAD"
DETAIL_NAME = "MEMORY_DETAIL"
HISTORY_NAME = "HISTORY_MEMORY"
ACTIVE_LIMIT = 50

HEAD_HEADER = (
    "# MEMORY_HEAD\n\n"
    "| 编号 | 状态 | 记录时间 | 完成时间 |\n"
    "|---|---|---|---|\n"
)
DETAIL_HEADER = "# MEMORY_DETAIL\n\n"
HISTORY_HEADER = "# HISTORY_MEMORY\n\n"

HEAD_ROW_RE = re.compile(
    r"^\|\s*(?P<entry_id>\d{3,})\s*\|\s*(?P<status>未完成|已完成)\s*\|"
    r"\s*(?P<created_at>[^|]*)\|\s*(?P<completed_at>[^|]*)\|",
    re.MULTILINE,
)
DETAIL_ID_RE = re.compile(r"^##\s+(\d{3,})\s*$", re.MULTILINE)
MESSAGE_MARKER_ID_RE = re.compile(r"<<<USER_MESSAGE_(\d{3,})_BEGIN>>>")


@dataclass
class HeadEntry:
    entry_id: str
    status: str
    created_at: str
    completed_at: str = ""


def now_iso() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


def safe_session_id(raw: str | None) -> str:
    if not raw:
        raw = datetime.now().astimezone().strftime("%Y%m%dT%H%M%S")
    value = re.sub(r"[^A-Za-z0-9_.-]+", "_", raw.strip())
    value = value.strip("._-")
    return value[:120] or datetime.now().astimezone().strftime("%Y%m%dT%H%M%S")


def resolve_project_root(raw_root: str | None) -> Path:
    if raw_root:
        return Path(raw_root).expanduser().resolve()

    cwd = Path.cwd().resolve()
    try:
        result = subprocess.run(
            ["git", "-C", str(cwd), "rev-parse", "--show-toplevel"],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        git_root = result.stdout.strip()
        if git_root:
            return Path(git_root).resolve()
    except Exception:
        pass

    return cwd


def memory_root(project_root: Path) -> Path:
    return project_root / "user_memory"


def env_session_id() -> str | None:
    for key in (
        "CODEX_SESSION_ID",
        "CODEX_THREAD_ID",
        "OPENAI_SESSION_ID",
        "OPENAI_THREAD_ID",
        "THREAD_ID",
        "SESSION_ID",
    ):
        value = os.environ.get(key)
        if value:
            return value
    return None


def latest_session_id(project_root: Path) -> str | None:
    root = memory_root(project_root)
    if not root.exists():
        return None
    folders = [p for p in root.glob("MEMORY_*") if p.is_dir()]
    if not folders:
        return None
    latest = max(folders, key=lambda p: p.stat().st_mtime)
    return latest.name.removeprefix("MEMORY_")


def resolve_session_id(project_root: Path, raw: str | None, create_new: bool) -> str:
    if raw:
        return safe_session_id(raw)
    env_id = env_session_id()
    if env_id:
        return safe_session_id(env_id)
    if not create_new:
        latest = latest_session_id(project_root)
        if latest:
            return safe_session_id(latest)
    return safe_session_id(None)


def session_dir(project_root: Path, session_id: str) -> Path:
    return memory_root(project_root) / f"MEMORY_{session_id}"


def ensure_files(project_root: Path, session_id: str) -> Path:
    root = memory_root(project_root)
    sdir = session_dir(project_root, session_id)
    root.mkdir(parents=True, exist_ok=True)
    sdir.mkdir(parents=True, exist_ok=True)
    head = sdir / HEAD_NAME
    detail = sdir / DETAIL_NAME
    if not head.exists():
        head.write_text(HEAD_HEADER, encoding="utf-8")
    if not detail.exists():
        detail.write_text(DETAIL_HEADER, encoding="utf-8")
    return sdir


def read_head_entries(path: Path) -> list[HeadEntry]:
    if not path.exists():
        return []
    text = path.read_text(encoding="utf-8")
    entries: list[HeadEntry] = []
    for match in HEAD_ROW_RE.finditer(text):
        entries.append(
            HeadEntry(
                entry_id=match.group("entry_id").strip(),
                status=match.group("status").strip(),
                created_at=match.group("created_at").strip(),
                completed_at=match.group("completed_at").strip(),
            )
        )
    return entries


def write_head_entries(path: Path, entries: list[HeadEntry]) -> None:
    lines = [HEAD_HEADER.rstrip("\n")]
    for entry in entries:
        lines.append(
            f"| {entry.entry_id} | {entry.status} | {entry.created_at} | {entry.completed_at} |"
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def all_known_numbers(sdir: Path) -> list[int]:
    numbers: list[int] = []
    head_path = sdir / HEAD_NAME
    for entry in read_head_entries(head_path):
        numbers.append(int(entry.entry_id))

    for name in (DETAIL_NAME, HISTORY_NAME):
        path = sdir / name
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        for pattern in (DETAIL_ID_RE, MESSAGE_MARKER_ID_RE):
            for value in pattern.findall(text):
                numbers.append(int(value))
    return numbers


def next_entry_id(sdir: Path) -> str:
    numbers = all_known_numbers(sdir)
    return f"{(max(numbers) + 1) if numbers else 1:03d}"


def read_message(message_file: str | None) -> str:
    if not message_file or message_file == "-":
        return sys.stdin.read()
    return Path(message_file).expanduser().read_text(encoding="utf-8")


def unique_target(base: Path, name: str) -> Path:
    candidate = base / name
    if not candidate.exists():
        return candidate
    stem = candidate.stem
    suffix = candidate.suffix
    for index in range(2, 10_000):
        numbered = base / f"{stem}_{index}{suffix}"
        if not numbered.exists():
            return numbered
    raise RuntimeError(f"Cannot allocate unique attachment name for {name}")


def store_attachments(sdir: Path, entry_id: str, attachments: list[str]) -> list[str]:
    if not attachments:
        return []

    target_dir = sdir / "MULTIMODAL" / entry_id
    target_dir.mkdir(parents=True, exist_ok=True)
    records: list[str] = []

    for raw in attachments:
        source = Path(raw).expanduser()
        if not source.exists():
            records.append(f"未复制，源路径不存在: {source}")
            continue
        target = unique_target(target_dir, source.name)
        if source.is_dir():
            shutil.copytree(source, target)
        else:
            shutil.copy2(source, target)
        records.append(f"{source} -> {target}")
    return records


def detail_block(entry_id: str, created_at: str, message: str, attachment_records: list[str]) -> str:
    attachment_lines = "\n".join(f"- {item}" for item in attachment_records) if attachment_records else "- 无"
    byte_len = len(message.encode("utf-8"))
    begin = f"<<<USER_MESSAGE_{entry_id}_BEGIN>>>"
    end = f"<<<USER_MESSAGE_{entry_id}_END>>>"
    return (
        f"## {entry_id}\n"
        f"记录时间: {created_at}\n"
        f"用户原文字节数: {byte_len}\n"
        f"多模态附件:\n{attachment_lines}\n\n"
        f"{begin}\n"
        f"{message}{end}\n\n"
    )


def append_detail(path: Path, block: str) -> None:
    existing = path.read_text(encoding="utf-8") if path.exists() else DETAIL_HEADER
    if not existing.endswith("\n"):
        existing += "\n"
    path.write_text(existing + block, encoding="utf-8")


def archive_if_needed(sdir: Path) -> bool:
    head_path = sdir / HEAD_NAME
    detail_path = sdir / DETAIL_NAME
    entries = read_head_entries(head_path)
    if len(entries) < ACTIVE_LIMIT:
        return False

    history_path = sdir / HISTORY_NAME
    history = history_path.read_text(encoding="utf-8") if history_path.exists() else HISTORY_HEADER
    if not history.endswith("\n"):
        history += "\n"
    batch_time = now_iso()
    history += (
        f"\n## Archive batch {batch_time}\n\n"
        f"### MEMORY_HEAD\n\n"
        f"{head_path.read_text(encoding='utf-8')}\n"
        f"### MEMORY_DETAIL\n\n"
        f"{detail_path.read_text(encoding='utf-8')}\n"
    )
    history_path.write_text(history, encoding="utf-8")
    write_head_entries(head_path, [])
    detail_path.write_text(DETAIL_HEADER, encoding="utf-8")
    return True


def replace_status_in_text(text: str, entry_id: str, new_status: str, completed_at: str) -> tuple[str, bool]:
    changed = False

    def repl(match: re.Match[str]) -> str:
        nonlocal changed
        if match.group("entry_id") != entry_id:
            return match.group(0)
        changed = True
        created_at = match.group("created_at").strip()
        old_completed_at = match.group("completed_at").strip()
        done_time = completed_at if new_status == STATUS_DONE else old_completed_at
        return f"| {entry_id} | {new_status} | {created_at} | {done_time} |"

    return HEAD_ROW_RE.sub(repl, text), changed


def update_status(sdir: Path, entry_id: str, new_status: str) -> bool:
    if new_status not in VALID_STATUSES:
        raise ValueError(f"Invalid status: {new_status}")
    completed_at = now_iso() if new_status == STATUS_DONE else ""
    changed_any = False
    for name in (HEAD_NAME, HISTORY_NAME):
        path = sdir / name
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        new_text, changed = replace_status_in_text(text, entry_id, new_status, completed_at)
        if changed:
            path.write_text(new_text, encoding="utf-8")
            changed_any = True
    return changed_any


def extract_detail(text: str, entry_id: str) -> str | None:
    begin = f"<<<USER_MESSAGE_{entry_id}_BEGIN>>>\n"
    end = f"<<<USER_MESSAGE_{entry_id}_END>>>"
    start = text.find(begin)
    if start == -1:
        return None
    start += len(begin)
    stop = text.find(end, start)
    if stop == -1:
        return None
    return text[start:stop]


def combined_detail_text(sdir: Path) -> str:
    chunks = []
    for name in (DETAIL_NAME, HISTORY_NAME):
        path = sdir / name
        if path.exists():
            chunks.append(path.read_text(encoding="utf-8"))
    return "\n".join(chunks)


def collect_all_head_entries(sdir: Path) -> list[HeadEntry]:
    entries: dict[str, HeadEntry] = {}
    for name in (HISTORY_NAME, HEAD_NAME):
        path = sdir / name
        if not path.exists():
            continue
        for entry in read_head_entries(path):
            entries[entry.entry_id] = entry
    return sorted(entries.values(), key=lambda item: int(item.entry_id))


def command_init(args: argparse.Namespace) -> int:
    project_root = resolve_project_root(args.project_root)
    session_id = resolve_session_id(project_root, args.session_id, create_new=True)
    sdir = ensure_files(project_root, session_id)
    print(f"project_root={project_root}")
    print(f"session_id={session_id}")
    print(f"memory_dir={sdir}")
    print(f"head={sdir / HEAD_NAME}")
    print(f"detail={sdir / DETAIL_NAME}")
    return 0


def command_record(args: argparse.Namespace) -> int:
    project_root = resolve_project_root(args.project_root)
    session_id = resolve_session_id(project_root, args.session_id, create_new=False)
    sdir = ensure_files(project_root, session_id)
    message = read_message(args.message_file)
    created_at = now_iso()
    entry_id = next_entry_id(sdir)
    attachment_records = store_attachments(sdir, entry_id, args.attachment or [])

    head_path = sdir / HEAD_NAME
    entries = read_head_entries(head_path)
    entries.append(HeadEntry(entry_id=entry_id, status=STATUS_OPEN, created_at=created_at))
    write_head_entries(head_path, entries)
    append_detail(sdir / DETAIL_NAME, detail_block(entry_id, created_at, message, attachment_records))
    archived = archive_if_needed(sdir)

    print(f"project_root={project_root}")
    print(f"session_id={session_id}")
    print(f"memory_dir={sdir}")
    print(f"entry_id={entry_id}")
    print(f"status={STATUS_OPEN}")
    if attachment_records:
        print("attachments=")
        for item in attachment_records:
            print(f"- {item}")
    print(f"archived_active_batch={str(archived).lower()}")
    return 0


def command_complete(args: argparse.Namespace) -> int:
    project_root = resolve_project_root(args.project_root)
    session_id = resolve_session_id(project_root, args.session_id, create_new=False)
    sdir = ensure_files(project_root, session_id)
    entry_ids = args.entry_id or []
    if args.all_open:
        entry_ids.extend(entry.entry_id for entry in collect_all_head_entries(sdir) if entry.status == STATUS_OPEN)
    if not entry_ids:
        print("No entry id supplied. Use --entry-id or --all-open.", file=sys.stderr)
        return 2
    missing: list[str] = []
    for entry_id in entry_ids:
        if not update_status(sdir, entry_id, STATUS_DONE):
            missing.append(entry_id)
    if missing:
        print(f"Missing entry id(s): {', '.join(missing)}", file=sys.stderr)
        return 1
    print(f"completed={', '.join(entry_ids)}")
    print(f"memory_dir={sdir}")
    return 0


def command_unfinished(args: argparse.Namespace) -> int:
    project_root = resolve_project_root(args.project_root)
    session_id = resolve_session_id(project_root, args.session_id, create_new=False)
    sdir = ensure_files(project_root, session_id)
    entries = [entry for entry in collect_all_head_entries(sdir) if entry.status == STATUS_OPEN]
    detail_text = combined_detail_text(sdir)
    print(f"project_root={project_root}")
    print(f"session_id={session_id}")
    print(f"memory_dir={sdir}")
    print(f"unfinished_count={len(entries)}")
    for entry in entries:
        print(f"\n## {entry.entry_id} | {entry.status} | {entry.created_at}")
        detail = extract_detail(detail_text, entry.entry_id)
        if detail is None:
            print("[DETAIL NOT FOUND]")
        else:
            print(detail, end="" if detail.endswith("\n") else "\n")
    return 0


def build_parser() -> argparse.ArgumentParser:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--project-root", help="Project root. Defaults to git root when available, otherwise cwd.")
    common.add_argument("--session-id", help="Conversation/session id. Defaults to Codex/thread env, latest session, or timestamp.")

    parser = argparse.ArgumentParser(description="Record verbatim user requests into project user_memory.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser(
        "init",
        parents=[common],
        help="Create the user_memory/MEMORY_<session_id> folder and active files.",
    )

    record = subparsers.add_parser("record", parents=[common], help="Record a new user request as 未完成.")
    record.add_argument("--message-file", help="Path to UTF-8 request text, or -/omitted for stdin.")
    record.add_argument("--attachment", action="append", help="Local path to multimodal content to copy and register.")

    complete = subparsers.add_parser("complete", parents=[common], help="Mark one or more entries 已完成.")
    complete.add_argument("--entry-id", action="append", help="Entry id such as 001. Can be repeated.")
    complete.add_argument("--all-open", action="store_true", help="Mark all currently open entries complete.")

    subparsers.add_parser(
        "unfinished",
        parents=[common],
        help="Print all 未完成 entries with full recorded request text.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.command == "init":
        return command_init(args)
    if args.command == "record":
        return command_record(args)
    if args.command == "complete":
        return command_complete(args)
    if args.command == "unfinished":
        return command_unfinished(args)
    parser.error(f"Unknown command: {args.command}")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
