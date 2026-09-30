---
name: knowledge-deposition
description: Convert verified project findings, reusable procedures, components, decisions, or failure lessons into a reviewable knowledge candidate. Use after acceptance, repeated problem closure, research synthesis, or when an insight may benefit multiple projects.
---

# Knowledge Deposition

1. Confirm the knowledge is verified, reusable, non-secret, and separable from temporary project state.
2. Create a candidate in `知识管理/沉淀候选.md` with title, summary, source paths, evidence, scope, prerequisites, expiry or freshness rule, conflicts, and proposed destination.
3. Classify it as research, SOP, reusable asset, Skill, rule candidate, architecture pattern, troubleshooting, or decision precedent.
4. Ask for user review when publication changes shared or system-level knowledge. Do not directly overwrite the hub.
5. After approval, route through `知识管理/KnowledgeRouter.md`: publish the managed asset to `<RND_HUB_ROOT>`, verify Router/index/log and Hash, then place the approved source in the configured LLM Wiki `raw/sources/`, rescan, and verify wiki index/log, summaries, links, and Reviews.
6. Keep project-specific facts in the project; publish only the reusable abstraction and a traceable source reference.

Reject candidates containing credentials, personal data, unlicensed content, unverifiable claims, or obsolete instructions.
