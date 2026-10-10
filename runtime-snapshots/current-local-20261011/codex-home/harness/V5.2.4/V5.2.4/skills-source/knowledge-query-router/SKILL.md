---
name: knowledge-query-router
description: Route a knowledge question across current project knowledge, the configured R&D knowledge hub, and local LLM Wiki without loading every source. Use when project facts may exist in multiple knowledge layers or when provenance and freshness must be reconciled.
---

# Knowledge Query Router

1. Read `知识管理/KnowledgeRouter.md` and resolve live mounts, permissions, status, and last validation.
2. Search current project knowledge first.
3. If insufficient, read the R&D hub `router.md` and `index.md`, then load only matching governed assets.
4. If still insufficient or graph/hybrid retrieval is useful, call `llm-wiki-maintenance`: verify health/version/project, search, and read cited wiki pages.
5. Reconcile conflicting results through `knowledge-sync-reconciler`; distinguish project, hub, wiki, and raw-source evidence.
6. Return source paths, versions, timestamps, and uncertainty. Record the query route in `知识管理/同步记录.md`.

Do not query LONG_MEMORY through this Skill. Use `long-memory-retriever` for closed conversation history.
