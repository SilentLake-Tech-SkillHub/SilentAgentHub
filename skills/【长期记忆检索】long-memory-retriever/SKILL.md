---
name: long-memory-retriever
description: Search project LONG_MEMORY.md only after the current requirement cannot be resolved from SHORT_MEMORY.md, or when the user explicitly requests historical recovery, audit, or a closed conversation. Use stable IDs, workspace scope, tags, and time windows to load the smallest matching fragment.
---

# Long Memory Retriever

1. Confirm the relevant requirement is absent from the current conversation block in `SHORT_MEMORY.md`.
2. Read `.codex/harness/memory-index.json` first when present; otherwise search `LONG_MEMORY.md` with exact IDs and narrow keywords.
3. Load only the matching record block and adjacent evidence links. Never inject the entire long-memory file by default.
4. Report the matched conversation ID, final status, time, project version, evidence paths, and whether the record may be stale.
5. If no match exists, continue without long memory and record the miss in the current SHORT_MEMORY turn.

Do not modify LONG_MEMORY during lookup. Do not retrieve secrets, raw credentials, or unrelated project conversations.
