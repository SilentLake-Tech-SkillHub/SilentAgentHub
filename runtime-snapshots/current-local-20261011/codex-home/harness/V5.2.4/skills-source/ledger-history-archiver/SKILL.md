---
name: ledger-history-archiver
description: Move terminal records out of active project ledgers into the cold history library using configured statuses, stable IDs, hashes, and two-phase transactions. Use at every Stop after management-record-sync and whenever closed items accumulate.
---

# Ledger History Archiver

1. Read `.codex/harness/ledger-retention.json` and validate it against its schema.
2. Run `.codex/hooks/ledger-history-archiver.ps1`.
3. Archive only registered ledger rows whose status is terminal.
4. Write and verify the history copy before removing the active row.
5. Update `流程管理/历史记录库/INDEX.md`, transaction state, and runtime event.
6. Run `ledger-history-integrity.ps1`; block closeout on duplicate IDs, missing hashes, unfinished transactions, or terminal rows left active.
7. Treat a repeated run with the same stable ID and content hash as no-op.

Do not archive specifications or non-terminal work. Never delete the active record when archive verification fails.
