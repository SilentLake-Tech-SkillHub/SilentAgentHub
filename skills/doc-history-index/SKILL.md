---
name: doc-history-index
description: Control 流程管理/历史记录库/INDEX.md. Use during initialization, every successful history migration, and explicit archive audits.
---

# History Index Controller

Maintain the cold-history catalog by period, source ledger, stable ID range, count, hash, and archive path. Normal session loading may read only routing metadata, never history bodies.
