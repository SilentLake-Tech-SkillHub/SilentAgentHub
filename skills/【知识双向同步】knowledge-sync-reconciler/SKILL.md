---
name: knowledge-sync-reconciler
description: Reconcile bidirectional project and knowledge-hub changes using hashes, timestamps, lineage, version windows, permissions, and conflict records. Use when project knowledge is published to the hub, hub updates are pulled into a project, or two copies may have diverged.
---

# Knowledge Sync Reconciler

## Rules

1. Read `知识管理/KnowledgeRouter.md`; resolve project source, R&D hub source, LLM Wiki compiled page, artifact ID, lineage, last common hash, current hashes, versions, modification times, permissions, and sync window.
2. “Newest wins” applies only when both files share lineage, the newest version is within the configured time or version window, and no manual-protection or permission rule applies.
3. If one side changed since the common base, propagate that side and preserve source metadata.
4. If both sides changed, do not overwrite. Create a conflict item containing both paths, hashes, differences, proposed merge, and recommended winner; archive the losing revision after approval.
5. If the hub or mount is unavailable, queue a pending sync in `知识管理/同步记录.md`; do not report success.
6. Project-to-hub publishing requires the knowledge-deposition review gate. Hub-to-project updates must not overwrite project-specific adaptations without a compatibility review.
7. Treat the R&D hub as the managed asset source and LLM Wiki as the compiled search/graph layer. Validate all three sides with post-copy hashes, Router/index/log, wiki backlinks and Reviews, permissions, and destination readback.

Use `scripts/version_window.py` to compare two metadata records. Never use timestamps alone when clocks, copies, or generated files may be unreliable.
