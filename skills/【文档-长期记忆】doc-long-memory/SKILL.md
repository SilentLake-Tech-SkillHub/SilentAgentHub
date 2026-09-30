---
name: doc-long-memory
description: Control the project-root LONG_MEMORY.md closed-conversation archive. Use when a conversation reaches an approved terminal status or when long-memory integrity is audited.
---

# Long Memory Controller

Validate `LONG_MEMORY.md` as a cold, append-oriented project history. It enters Git but is never loaded by default. Runtime writes and two-phase migration belong to `user-memory-recorder`; this controller must not create a competing write path. Preserve IDs, hashes, final outcomes, evidence links, and archive time.
