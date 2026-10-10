#!/usr/bin/env python3
"""Codex lifecycle hook bridge for user_memory recording."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any


SKILL_DIR = Path(__file__).resolve().parents[1]
USER_MEMORY_SCRIPT = SKILL_DIR / "scripts" / "user_memory.py"
LOG_DIR = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))) / "logs"
LOG_PATH = LOG_DIR / "user_memory_hook.log"


def log(message: str) -> None:
    try:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now().astimezone().isoformat(timespec="seconds")
        with LOG_PATH.open("a", encoding="utf-8") as handle:
            handle.write(f"{stamp} {message}\n")
    except Exception:
        pass


def load_payload() -> dict[str, Any]:
    raw = sys.stdin.read()
    if not raw.strip():
        return {}
    try:
        payload = json.loads(raw)
        if isinstance(payload, dict):
            return payload
        return {"payload": payload}
    except Exception as exc:
        log(f"non_json_stdin error={exc!r} bytes={len(raw.encode('utf-8'))}")
        return {"raw_stdin": raw}


def find_value(data: Any, keys: set[str]) -> Any:
    if isinstance(data, dict):
        for key, value in data.items():
            if key in keys and value not in (None, ""):
                return value
        for value in data.values():
            found = find_value(value, keys)
            if found not in (None, ""):
                return found
    elif isinstance(data, list):
        for item in data:
            found = find_value(item, keys)
            if found not in (None, ""):
                return found
    return None


def extract_text(payload: dict[str, Any]) -> str | None:
    value = find_value(
        payload,
        {
            "prompt",
            "user_prompt",
            "userPrompt",
            "text",
            "message",
            "content",
            "input",
            "query",
            "raw_stdin",
        },
    )
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        chunks: list[str] = []
        for item in value:
            if isinstance(item, str):
                chunks.append(item)
            elif isinstance(item, dict):
                nested = find_value(item, {"text", "content", "message"})
                if isinstance(nested, str):
                    chunks.append(nested)
        if chunks:
            return "\n".join(chunks)
    return None


def extract_cwd(payload: dict[str, Any]) -> str | None:
    value = find_value(payload, {"cwd", "working_directory", "workingDirectory", "project_root", "projectRoot"})
    if isinstance(value, str) and value:
        return value
    return os.getcwd()


def extract_session_id(payload: dict[str, Any]) -> str | None:
    value = find_value(
        payload,
        {
            "session_id",
            "sessionId",
            "thread_id",
            "threadId",
            "conversation_id",
            "conversationId",
        },
    )
    if isinstance(value, str) and value:
        return value
    for key in ("CODEX_SESSION_ID", "CODEX_THREAD_ID", "OPENAI_SESSION_ID", "OPENAI_THREAD_ID"):
        env_value = os.environ.get(key)
        if env_value:
            return env_value
    return None


def run_user_memory(args: list[str], cwd: str | None) -> int:
    command = [sys.executable, str(USER_MEMORY_SCRIPT), *args]
    result = subprocess.run(
        command,
        cwd=cwd or os.getcwd(),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.stdout:
        log(f"stdout command={' '.join(args)} output={result.stdout.strip()}")
    if result.stderr:
        log(f"stderr command={' '.join(args)} output={result.stderr.strip()}")
    return result.returncode


def handle_session_start(payload: dict[str, Any]) -> int:
    cwd = extract_cwd(payload)
    session_id = extract_session_id(payload)
    args = ["init"]
    if session_id:
        args.extend(["--session-id", session_id])
    code = run_user_memory(args, cwd)
    log(f"SessionStart cwd={cwd} session_id={session_id or ''} code={code}")
    return 0


def handle_user_prompt_submit(payload: dict[str, Any]) -> int:
    cwd = extract_cwd(payload)
    session_id = extract_session_id(payload)
    text = extract_text(payload)
    if text is None:
        log(f"UserPromptSubmit missing_text cwd={cwd} keys={sorted(payload.keys())}")
        return 0

    with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False, prefix="codex-user-prompt-", suffix=".txt") as handle:
        handle.write(text)
        message_path = handle.name

    try:
        args = ["record", "--message-file", message_path]
        if session_id:
            args.extend(["--session-id", session_id])
        code = run_user_memory(args, cwd)
        log(f"UserPromptSubmit cwd={cwd} session_id={session_id or ''} bytes={len(text.encode('utf-8'))} code={code}")
    finally:
        try:
            Path(message_path).unlink()
        except FileNotFoundError:
            pass
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run user_memory actions from Codex hook payloads.")
    parser.add_argument("event", choices=["SessionStart", "UserPromptSubmit"])
    args = parser.parse_args(argv)
    payload = load_payload()
    if args.event == "SessionStart":
        return handle_session_start(payload)
    if args.event == "UserPromptSubmit":
        return handle_user_prompt_submit(payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
