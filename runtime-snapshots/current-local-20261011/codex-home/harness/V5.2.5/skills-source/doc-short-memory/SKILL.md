---
name: doc-short-memory
description: Control the project-root SHORT_MEMORY.md active-conversation ledger. Use at project initialization, every UserPromptSubmit, every Stop closeout, and when active conversation state changes.
---

# Short Memory Controller

Validate `SHORT_MEMORY.md` as the human-readable source for open conversations. Keep the latest five turns per open conversation plus a rolling summary and preserve stable IDs and Git history. Runtime writes belong to `user-memory-recorder`; this controller must not create a competing write path. Do not move blocked or needs-user work to long memory.
