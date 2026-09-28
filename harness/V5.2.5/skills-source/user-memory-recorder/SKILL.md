---
name: user-memory-recorder
description: Own the project-level SHORT_MEMORY.md and LONG_MEMORY.md lifecycle through one deterministic runtime, including UTF-8 prompt capture, internal-prompt quarantine, active-state repair, evidence-linked closeout, rolling summaries, and verified two-phase migration. Use at prompt submission, session start, compaction, stop, history recovery, or when the user asks to remember project context.
---

# User Memory Recorder

## Workflow

1. Read project-root `MEMORY.md`. `MEMORY.md` is the rules source controlled by `doc-memory-rules`; this Skill owns the runtime state in `SHORT_MEMORY.md` and `LONG_MEMORY.md`. All three files are project assets registered in Router and committed to Git.
2. Route every lifecycle action through `.codex/hooks/memory-runtime.ps1` (`Capture`, `Read`, `Compact`, `Repair`, `Closeout`, `Validate`). Do not let individual Hooks invent separate SHORT/LONG write logic.
3. On UserPromptSubmit, invoke `-Event Capture`; decode Desktop stdin as strict UTF-8, redact secrets, preserve the original prompt Hash, timestamp, workspace/session/conversation/turn IDs, and Task/Plan links. High-confidence Codex internal, system, recommendation, or harness prompts go to the quarantine log and never enter SHORT or LONG.
4. At SessionStart, invoke `-Event Repair`, then `-Event Read`. Quarantine legacy internal prompts; convert stale orphan `received` records to `needs_user` rather than silently deleting or falsely completing them.
5. Read only the current conversation from SHORT_MEMORY. Keep at most five detailed turns per open conversation and convert older turns to a rolling summary.
6. Before every final response, use `memory-turn-closeout` through `-Event Closeout` to compare the sanitized prompt with Task, Plan, issue/risk, Validation, and Acceptance evidence. Stop is a fallback integrity check, not the normal trigger. It may request exactly one continuation with `decision: block`; it must not use legacy `continue: false` as a reinjection mechanism.
7. Keep `needs_user` and `blocked` in SHORT_MEMORY. A nonterminal closeout is not successful until the detailed record, active summary, and `memory-index.json` state/location/conversation Hash all agree. Migrate `completed`, `cancelled`, `superseded`, or user-approved `closed_unresolved` through the two-phase script; destination verification must precede removal of the detailed record, rollup, and active summary from SHORT.
8. If SHORT_MEMORY has no relevant match, call `long-memory-retriever`; never load LONG_MEMORY in full.
9. On PreCompact, update both the SHORT_MEMORY rolling summary and Handoff with the same IDs, without duplicating formal ledger bodies.

Never write secrets, raw credentials, or unnecessary personal data. Concurrent changes use project locks, stable IDs, per-conversation hashes, and transaction manifests. `Validate` must reject a missing/orphan index entry or any SHORT/index state, location, or Hash mismatch. Quarantine stores only metadata, hashes, and a short redacted preview when capture occurs; repaired historical records may omit the preview.
