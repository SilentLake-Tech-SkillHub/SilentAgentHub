---
name: history-record-query
description: Locate and read cold records under 流程管理/历史记录库 only for explicit historical requests, audit, rollback, incident review, or an active record that references a historical ID. Do not use during normal active-ledger loading.
---

# History Record Query

1. Confirm an allowed trigger: explicit user request, historical ID reference, audit, rollback, or incident review.
2. Read `流程管理/历史记录库/INDEX.md` first.
3. Resolve year, month, source ledger, stable ID, hash, and archive path.
4. Load only the minimum matching rows or record blocks.
5. Return provenance, closure status, archived time, source version, and integrity result.
6. Do not copy historical terminal records back to active ledgers unless the user approves a reopen operation.
