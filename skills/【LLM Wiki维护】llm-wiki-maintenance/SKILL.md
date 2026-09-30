---
name: llm-wiki-maintenance
description: Operate and validate a local nashsu LLM Wiki through its documented HTTP API and desktop workflows. Use only when the user explicitly names LLM Wiki, the research knowledge hub, or the configured 知识库 and asks to ingest, rescan, query, read, inspect, review, or lint it.
---

# LLM Wiki Maintenance

Read `references/api-operations.md` before calling the API. The desktop app must be running; the API is local at `127.0.0.1:19828` and normally requires `LLM_WIKI_API_TOKEN`.

Also read `知识管理/KnowledgeRouter.md` and `知识管理/LLM-Wiki使用与运维.md`. Use the routed project ID and Secret reference; never guess identity from the first project returned.

## Workflow

1. Call health, check API major version, authentication, and current project identity.
2. For ingest, place approved sources under the project's immutable `raw/sources/` through the desktop import or configured sync, then call source rescan. Do not invent a write endpoint.
3. Poll files, Review items, or the desktop activity queue until ingestion settles. Confirm `wiki/index.md`, `wiki/log.md`, source summaries, backlinks, and source traceability changed as expected.
4. For query, run hybrid search, read cited pages, and distinguish wiki evidence from raw-source evidence.
5. For lint, use the desktop Lint operation and additionally inspect contradictions, stale claims, orphan pages, missing cross-links, unresolved review items, and index/log consistency.
6. Record operation, project, source hash, time, result, cited pages, unresolved reviews, and API version in `知识管理/同步记录.md`.
7. If health, auth, project identity, permissions, queue, or version compatibility fails, fall back to project knowledge and write a pending-sync item. Do not claim Wiki storage or freshness.

The API is read-only except `sources/rescan`, which triggers a queue diff. Never expose the token in records or command output.
